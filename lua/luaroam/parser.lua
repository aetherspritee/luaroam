local M = {}

-- Helper to count braces and find matching closing brace
local function find_matching_brace(str, start_pos)
  local brace_count = 1
  local len = #str
  local pos = start_pos
  local escaped = false
  while pos <= len do
    local char = str:sub(pos, pos)
    if char == "\\" then
      escaped = not escaped
    else
      if not escaped then
        if char == "{" then
          brace_count = brace_count + 1
        elseif char == "}" then
          brace_count = brace_count - 1
          if brace_count == 0 then
            return pos
          end
        end
      end
      escaped = false
    end
    pos = pos + 1
  end
  return nil
end

-- Parse fields from entry inner content
local function parse_fields(fields_str)
  local fields = {}
  local pos = 1
  local len = #fields_str

  while pos <= len do
    local next_non_ws = fields_str:find("%S", pos)
    if not next_non_ws then break end
    pos = next_non_ws

    local sub = fields_str:sub(pos)
    local key_start, key_end, key = sub:find("^([%a_%-]+)%s*=%s*")
    if not key_start then
      pos = pos + 1
    else
      pos = pos + key_end
      
      local val_start = fields_str:find("%S", pos)
      if not val_start then break end
      pos = val_start

      local char = fields_str:sub(pos, pos)
      local value = ""
      if char == "{" then
        local match_end = find_matching_brace(fields_str, pos + 1)
        if match_end then
          value = fields_str:sub(pos + 1, match_end - 1)
          pos = match_end + 1
        else
          value = fields_str:sub(pos + 1)
          pos = len + 1
        end
      elseif char == '"' then
        local match_end = nil
        local p = pos + 1
        local escaped = false
        while p <= len do
          local c = fields_str:sub(p, p)
          if c == "\\" then
            escaped = not escaped
          else
            if c == '"' and not escaped then
              match_end = p
              break
            end
            escaped = false
          end
          p = p + 1
        end
        if match_end then
          value = fields_str:sub(pos + 1, match_end - 1)
          pos = match_end + 1
        else
          value = fields_str:sub(pos + 1)
          pos = len + 1
        end
      else
        local next_comma = fields_str:find(",", pos)
        if next_comma then
          value = fields_str:sub(pos, next_comma - 1)
          pos = next_comma + 1
        else
          value = fields_str:sub(pos)
          pos = len + 1
        end
      end

      key = key:lower()
      value = value:gsub("^%s+", ""):gsub("%s+$", "")
      fields[key] = value
    end
  end
  return fields
end

-- Parse entire BibTeX file
function M.parse_file(path)
  local file = io.open(path, "r")
  if not file then
    return {}
  end
  local content = file:read("*a")
  file:close()

  local entries = {}
  local pos = 1
  local len = #content

  -- Compute line starts for fast line number resolution
  local line_starts = { 1 }
  for i = 1, len do
    if content:sub(i, i) == "\n" then
      table.insert(line_starts, i + 1)
    end
  end

  local function get_line_num(char_pos)
    for line, start in ipairs(line_starts) do
      if start > char_pos then
        return line - 1
      end
    end
    return #line_starts
  end

  while pos <= len do
    local entry_start, entry_end, entry_type, citekey = content:find("@(%a+)%s*%{%s*([^,%s]+)%s*,", pos)
    if not entry_start then
      break
    end

    local lower_type = entry_type:lower()
    if lower_type ~= "comment" and lower_type ~= "preamble" and lower_type ~= "string" then
      local brace_start = content:find("{", entry_start)
      if brace_start then
        local closing_brace = find_matching_brace(content, brace_start + 1)
        if closing_brace then
          local fields_str = content:sub(entry_end + 1, closing_brace - 1)
          local fields = parse_fields(fields_str)

          local entry = {
            type = lower_type,
            citekey = citekey,
            title = fields.title,
            author = fields.author,
            year = fields.year,
            url = fields.url,
            fields = fields,
            lnum = get_line_num(entry_start),
          }
          table.insert(entries, entry)
          pos = closing_brace + 1
        else
          pos = entry_end + 1
        end
      else
        pos = entry_end + 1
      end
    else
      pos = entry_end + 1
    end
  end

  return entries
end

-- Update a specific field in a BibTeX entry
function M.update_entry_field(path, citekey, field_name, value)
  local entries = M.parse_file(path)
  local entry = nil
  for _, e in ipairs(entries) do
    if e.citekey == citekey then
      entry = e
      break
    end
  end

  if not entry then
    return false, "Entry not found"
  end

  local lines = {}
  local f = io.open(path, "r")
  if not f then return false, "Cannot read file" end
  for line in f:lines() do
    table.insert(lines, line)
  end
  f:close()

  local field_lower = field_name:lower()
  local updated = false
  if entry.fields[field_lower] then
    local search_end = #lines
    for _, e in ipairs(entries) do
      if e.lnum > entry.lnum then
        search_end = e.lnum - 1
        break
      end
    end

    for i = entry.lnum, search_end do
      local line = lines[i]
      if line:lower():match("^%s*" .. field_lower .. "%s*=") then
        lines[i] = string.format("  %s = {%s},", field_name, value)
        updated = true
        break
      end
    end
  end

  if not updated then
    table.insert(lines, entry.lnum + 1, string.format("  %s = {%s},", field_name, value))
  end

  f = io.open(path, "w")
  if not f then return false, "Cannot write file" end
  for _, line in ipairs(lines) do
    f:write(line .. "\n")
  end
  f:close()

  return true
end

-- Parse a single BibTeX entry from a string
function M.parse_entry_string(content)
  local entry_type, citekey = content:match("@(%a+)%s*%{%s*([^,%s]+)%s*,")
  if not entry_type then return nil end
  
  local brace_start = content:find("{")
  if not brace_start then return nil end
  
  local closing_brace = find_matching_brace(content, brace_start + 1)
  if not closing_brace then return nil end
  
  local comma_pos = content:find(",", brace_start)
  if not comma_pos then return nil end
  
  local fields_str = content:sub(comma_pos + 1, closing_brace - 1)
  local fields = parse_fields(fields_str)
  
  return {
    type = entry_type:lower(),
    citekey = citekey,
    title = fields.title,
    author = fields.author,
    year = fields.year,
    url = fields.url,
    fields = fields,
  }
end

return M
