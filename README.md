# luaroam.nvim

A lightweight, dependency-free Neovim plugin written in Lua to keep track of academic papers you've read. It interfaces with a configurable BibTeX file to list papers, create and open associated Markdown notes, insert citations, and fetch references directly from arXiv links.

## Features

- **No external dependencies**: Pure Lua implementation leveraging Neovim's built-in `vim.ui.select` and `vim.system`.
- **List & Search Papers**: Select and search through your BibTeX entries.
- **Note Management**: Create and open Markdown notes associated with each paper.
- **Reference Insertion**: Insert formatted citations (defaults to `@citekey`) directly at the cursor.
- **arXiv Integration**: Paste/type an arXiv link (or ID) to fetch its BibTeX entry, append it to your file, and optionally create notes instantly.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "dusc/luaroam",
  config = function()
    require("luaroam").setup({
      bib_path = "~/notes/references.bib", -- Path to your central BibTeX file
      notes_dir = "~/notes/papers",       -- Directory where markdown notes will be saved
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
| `:LuaRoamSelect` | Search papers and select an action (Open note, Insert reference, Open URL, Go to BibTeX). |
| `:LuaRoamInsert` | Search papers and insert a reference at the cursor. |
| `:LuaRoamNote` | Search papers and open or create its associated markdown note. |
| `:LuaRoamOpenUrl` | Search papers and open its URL (or arXiv link) in your browser. |
| `:LuaRoamGoToBib` | Search papers and open the BibTeX file on the line of the entry. |
| `:LuaRoamAddArxiv` | Prompts for an arXiv link/ID or fetches the link under the cursor, fetches the BibTeX, and appends it to your BibTeX file. |

### Lua API

You can map keys directly to the Lua API functions:

```lua
-- Select from paper menu
vim.keymap.set("n", "<leader>rp", require("luaroam").open_papers_menu, { desc = "LuaRoam Papers Menu" })

-- Direct actions
vim.keymap.set("n", "<leader>rn", require("luaroam").open_note, { desc = "LuaRoam Open Note" })
vim.keymap.set("n", "<leader>ri", require("luaroam").insert_reference, { desc = "LuaRoam Insert Citation" })
vim.keymap.set("n", "<leader>ru", require("luaroam").open_url, { desc = "LuaRoam Open URL" })
vim.keymap.set("n", "<leader>rb", require("luaroam").go_to_bib, { desc = "LuaRoam Go to BibTeX Entry" })

-- Add arXiv paper (prompts for input if no argument is passed)
vim.keymap.set("n", "<leader>ra", require("luaroam").add_arxiv, { desc = "LuaRoam Add arXiv entry" })
```
