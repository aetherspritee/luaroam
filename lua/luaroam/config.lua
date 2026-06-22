local M = {}

M.defaults = {
  bib_path = "~/references.bib",
  notes_dir = "~/notes/papers",
  pdf_dir = "~/notes/pdfs",
  pdf_viewer = nil, -- Uses default system opener if nil
  format_citekey = function(entry)
    local author = entry.author or (entry.fields and entry.fields.author) or ""
    local year = entry.year or (entry.fields and entry.fields.year) or ""
    
    local lastname = "Unknown"
    if author ~= "" then
      local first = author
      local and_pos = author:find("%s+and%s+")
      if and_pos then
        first = author:sub(1, and_pos - 1)
      end
      first = first:gsub("^%s+", ""):gsub("%s+$", "")
      
      local comma_pos = first:find(",")
      if comma_pos then
        lastname = first:sub(1, comma_pos - 1)
      else
        local last_word = first:match("%s+([^%s]+)$")
        lastname = last_word or first
      end
    end
    
    lastname = lastname:gsub("[{}]", ""):gsub("%s+", ""):gsub("[^%w%-_]", "")
    local clean_year = year:gsub("[{}]", ""):gsub("%D", "")
    if clean_year == "" then clean_year = "unknown" end
    
    return lastname .. "_" .. clean_year
  end,
  format_reference = function(entry)
    return "@" .. entry.citekey
  end,
  note_name = function(entry)
    return entry.citekey .. ".md"
  end,
  note_template = function(entry)
    return {
      "---",
      "title: " .. (entry.title or ""),
      "citekey: " .. entry.citekey,
      "author: " .. (entry.author or ""),
      "year: " .. (entry.year or ""),
      "url: " .. (entry.url or ""),
      "tags: [paper]",
      "---",
      "",
      "# " .. (entry.title or entry.citekey),
      "",
      "## Abstract",
      "",
      "## Key Takeaways",
      "",
      "## Notes",
      "",
    }
  end,
}

M.options = vim.tbl_deep_extend("force", {}, M.defaults, {})

function M.get(key)
  local val = M.options[key]
  if type(val) == "string" and (key == "bib_path" or key == "notes_dir" or key == "pdf_dir") then
    return vim.fn.expand(val)
  end
  return val
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
