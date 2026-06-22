# luaroam.nvim

A lightweight, dependency-free Neovim plugin written in Lua to keep track of academic papers you've read. It interfaces with a configurable BibTeX file to list papers, create and open associated Markdown notes, insert citations, and fetch references directly from arXiv links.

## Features

- **No external dependencies**: Pure Lua implementation leveraging Neovim's built-in `vim.ui.select` and `vim.system`.
- **List & Search Papers**: Select and search through your BibTeX entries.
- **Note Management**: Create and open Markdown notes associated with each paper.
- **Reference Insertion**: Insert formatted citations (defaults to `@citekey`) directly at the cursor.
- **arXiv Integration**: Paste/type an arXiv link (or ID) to fetch its BibTeX entry, append it to your file, and optionally create notes instantly.
- **PDF Management**: Download arXiv PDFs automatically, link them directly via the `file` field in your BibTeX entry, and open them in a configurable viewer.
- **snacks.nvim Picker**: Search and select from your downloaded PDFs using a native Snacks.nvim picker window, which opens the selected paper's PDF automatically.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "dusc/luaroam",
  dependencies = { "folke/snacks.nvim" }, -- Optional, for LuaRoamPdfs picker
  config = function()
    require("luaroam").setup({
      bib_path = "~/notes/references.bib", -- Path to your central BibTeX file
      notes_dir = "~/notes/papers",       -- Directory where markdown notes will be saved
      pdf_dir = "~/notes/pdfs",           -- Directory where downloaded PDFs will be saved
      pdf_viewer = nil,                   -- Custom PDF opener command (nil uses default system opener)
    })
  end
}
```

## Configuration

You can customize the formats, templates, and filenames using the setup function options:

```lua
require("luaroam").setup({
  -- Paths (automatically expanded)
  bib_path = "~/references.bib",
  notes_dir = "~/notes/papers",
  pdf_dir = "~/notes/pdfs",

  -- Custom viewer (e.g., {"zathura"}, {"open", "-a", "Preview"}, or nil)
  pdf_viewer = nil,

  -- How references are formatted for insertion (default: "@citekey")
  format_reference = function(entry)
    return "@" .. entry.citekey
  end,

  -- How note filenames are generated (default: "citekey.md")
  note_name = function(entry)
    return entry.citekey .. ".md"
  end,

  -- Markdown template for new paper notes
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
      "## Notes",
    }
  end,
})
```

## Usage

### User Commands

| Command | Action |
| --- | --- |
| `:LuaRoamSelect` | Search papers and select an action (Open note, Insert reference, Open URL, Go to BibTeX, Open PDF, Download PDF). |
| `:LuaRoamInsert` | Search papers and insert a reference at the cursor. |
| `:LuaRoamNote` | Search papers and open or create its associated markdown note. |
| `:LuaRoamOpenUrl` | Search papers and open its URL (or arXiv link) in your browser. |
| `:LuaRoamGoToBib` | Search papers and open the BibTeX file on the line of the entry. |
| `:LuaRoamOpenPdf` | Select a paper and open its associated local PDF (prompts to download if not found). |
| `:LuaRoamDownloadPdf` | Select a paper and download its PDF from arXiv/URL, then write the `file` field in your BibTeX. |
| `:LuaRoamPdfs` | Opens a `snacks.nvim` picker listing all papers with local PDFs. Selecting a paper immediately opens its PDF. |
| `:LuaRoamAddArxiv` | Prompts for an arXiv link/ID or fetches the link under the cursor, fetches the BibTeX, and appends it to your BibTeX file. |

### Lua API

You can map keys directly to the Lua API functions:

```lua
-- Select from paper menu
vim.keymap.set("n", "<leader>rp", function() require("luaroam").open_papers_menu() end, { desc = "LuaRoam Papers Menu" })

-- Direct actions
vim.keymap.set("n", "<leader>rn", function() require("luaroam").open_note() end, { desc = "LuaRoam Open Note" })
vim.keymap.set("n", "<leader>ri", function() require("luaroam").insert_reference() end, { desc = "LuaRoam Insert Citation" })
vim.keymap.set("n", "<leader>ru", function() require("luaroam").open_url() end, { desc = "LuaRoam Open URL" })
vim.keymap.set("n", "<leader>rb", function() require("luaroam").go_to_bib() end, { desc = "LuaRoam Go to BibTeX Entry" })

-- PDF actions
vim.keymap.set("n", "<leader>rf", function() require("luaroam").open_pdf() end, { desc = "LuaRoam Open PDF" })
vim.keymap.set("n", "<leader>rd", function() require("luaroam").download_pdf() end, { desc = "LuaRoam Download PDF" })
vim.keymap.set("n", "<leader>rs", function() require("luaroam").snacks_list_pdfs() end, { desc = "LuaRoam List PDFs (Snacks)" })

-- Add arXiv paper (prompts for input if no argument is passed)
vim.keymap.set("n", "<leader>ra", function() require("luaroam").add_arxiv() end, { desc = "LuaRoam Add arXiv entry" })
```
