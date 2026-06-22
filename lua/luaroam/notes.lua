local M = {}
local config = require("luaroam.config")

function M.get_note_path(entry)
  local notes_dir = config.get("notes_dir")
  if not notes_dir then
    error("notes_dir is not configured. Run require('luaroam').setup() with notes_dir.")
  end
  local filename = config.options.note_name(entry)
  return notes_dir .. "/" .. filename
end

function M.open_note(entry)
  local success, note_path = pcall(M.get_note_path, entry)
  if not success then
    vim.notify("[luaroam] Error: " .. tostring(note_path), vim.log.levels.ERROR)
    return
  end

  local file_exists = vim.fn.filereadable(note_path) == 1

  if not file_exists then
    -- Create the directory if it doesn't exist
    local parent_dir = vim.fn.fnamemodify(note_path, ":h")
    if vim.fn.isdirectory(parent_dir) == 0 then
      vim.fn.mkdir(parent_dir, "p")
    end

    -- Generate template
    local template = config.options.note_template(entry)
    local f = io.open(note_path, "w")
    if f then
      for _, line in ipairs(template) do
        f:write(line .. "\n")
      end
      f:close()
    else
      vim.notify("[luaroam] Failed to create note file: " .. note_path, vim.log.levels.ERROR)
      return
    end
  end

  -- Open the file in Neovim
  vim.cmd("edit " .. vim.fn.fnameescape(note_path))
end

return M
