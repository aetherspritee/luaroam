local M = {}

M.defaults = {
  bib_path = "~/references.bib",
  notes_dir = "~/notes/papers",
  pdf_dir = "~/notes/pdfs",
  pdf_viewer = nil, -- Uses default system opener if nil
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
