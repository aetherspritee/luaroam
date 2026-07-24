local M = {}
local config = require("luaroam.config")
local parser = require("luaroam.parser")
local notes = require("luaroam.notes")
local arxiv = require("luaroam.arxiv")
local pdf = require("luaroam.pdf")

M.setup = config.setup

-- Expose modules
M.parser = parser
M.notes = notes
M.arxiv = arxiv
M.pdf = pdf

local function clean_braces(str)
    if not str then return "" end
    return str:gsub("[{}]", "")
end

local function format_entry_display(entry)
    local title = clean_braces(entry.title or "")
    local year = entry.year or ""

    local display = string.format("[%s] %s", entry.citekey, title)
    if year ~= "" then
        display = display .. " (" .. year .. ")"
    end
    return display
end

local function insert_reference(entry)
    local ref = config.options.format_reference(entry)
    vim.api.nvim_put({ ref }, "c", true, true)
end

local function open_url(entry)
    local url = entry.url or entry.fields.url or entry.fields.eprint
    if not url then
        vim.notify("[luaroam] No URL found for entry: " .. entry.citekey, vim.log.levels.WARN)
        return
    end

    if not url:match("^http") and entry.fields.archiveprefix == "arXiv" then
        url = "https://arxiv.org/abs/" .. url
    end

    if vim.ui.open then
        vim.ui.open(url)
    else
        local cmd
        if vim.fn.has("mac") == 1 then
            cmd = { "open", url }
        elseif vim.fn.has("win32") == 1 then
            cmd = { "cmd.exe", "/c", "start", url }
        else
            cmd = { "xdg-open", url }
        end
        vim.fn.jobstart(cmd, { detach = true })
    end
end

local function go_to_bib(entry)
    local bib_path = config.get("bib_path")
    if not bib_path then
        vim.notify("[luaroam] bib_path is not configured.", vim.log.levels.ERROR)
        return
    end
    vim.cmd("edit " .. vim.fn.fnameescape(bib_path))
    if entry.lnum then
        vim.api.nvim_win_set_cursor(0, { entry.lnum, 0 })
    end
end

local function actions_menu(entry)
    local options = {
        "1. Open/Create Note",
        "2. Insert Reference",
        "3. Open URL",
        "4. Go to BibTeX Entry",
        "5. Open PDF (Local)",
        "6. Download PDF",
    }

    vim.ui.select(options, {
        prompt = "Action for [" .. entry.citekey .. "]:",
    }, function(choice)
        if not choice then return end
        if choice:match("^1") then
            notes.open_note(entry)
        elseif choice:match("^2") then
            insert_reference(entry)
        elseif choice:match("^3") then
            open_url(entry)
        elseif choice:match("^4") then
            go_to_bib(entry)
        elseif choice:match("^5") then
            pdf.open_pdf(entry)
        elseif choice:match("^6") then
            pdf.download_pdf(entry)
        end
    end)
end

function M.select_paper(prompt, callback)
    local bib_path = config.get("bib_path")
    if not bib_path then
        vim.notify("[luaroam] bib_path is not configured. Setup the plugin first.", vim.log.levels.ERROR)
        return
    end

    if vim.fn.filereadable(bib_path) == 0 then
        vim.notify("[luaroam] BibTeX file not found at: " .. bib_path, vim.log.levels.ERROR)
        return
    end

    local entries = parser.parse_file(bib_path)
    if #entries == 0 then
        vim.notify("[luaroam] No entries found in BibTeX file: " .. bib_path, vim.log.levels.WARN)
        return
    end

    table.sort(entries, function(a, b)
        return a.citekey:lower() < b.citekey:lower()
    end)

    local display_items = {}
    local entry_map = {}
    for _, entry in ipairs(entries) do
        local disp = format_entry_display(entry)
        table.insert(display_items, disp)
        entry_map[disp] = entry
    end

    vim.ui.select(display_items, {
        prompt = prompt or "Select a paper:",
    }, function(choice)
        if choice then
            local selected_entry = entry_map[choice]
            callback(selected_entry)
        end
    end)
end

-- Interactive entry actions
function M.open_papers_menu()
    M.select_paper("Actions for paper:", actions_menu)
end

-- Direct action functions
function M.insert_reference()
    M.select_paper("Insert reference for:", insert_reference)
end

function M.open_note()
    M.select_paper("Open note for:", function(entry)
        notes.open_note(entry)
    end)
end

function M.open_url()
    M.select_paper("Open URL for:", open_url)
end

function M.go_to_bib()
    M.select_paper("Go to BibTeX entry:", go_to_bib)
end

-- PDF Action functions
function M.open_pdf()
    M.select_paper("Open PDF for:", function(entry)
        pdf.open_pdf(entry)
    end)
end

function M.download_pdf()
    M.select_paper("Download PDF for:", function(entry)
        pdf.download_pdf(entry)
    end)
end

function M.snacks_list_pdfs()
    pdf.snacks_list_pdfs()
end

-- Add arXiv entry utility (handles nil input for direct keymap calls)
function M.add_arxiv(link_or_id, callback)
    if link_or_id and link_or_id ~= "" then
        arxiv.add_arxiv_entry(link_or_id, callback)
    else
        local cword = vim.fn.expand("<cWORD>")
        cword = cword:gsub("^['\"%(%[%<]+", ""):gsub("['\"%)%]%>%.,;]+$", "")

        local is_arxiv = false
        if cword:match("arxiv%.org") or cword:match("^arxiv:") or cword:match("^%d+%.%d+$") then
            is_arxiv = true
        end

        if is_arxiv then
            arxiv.add_arxiv_entry(cword, callback)
        else
            vim.ui.input({
                prompt = "Enter arXiv Link or ID: ",
            }, function(input)
                if input and input ~= "" then
                    arxiv.add_arxiv_entry(input, callback)
                end
            end)
        end
    end
end

-- Link actions
function M.follow_link()
    notes.follow_link()
end

function M.insert_link()
    M.select_paper("Insert link for:", function(entry)
        notes.insert_link(entry)
    end)
end

function M.show_backlinks()
    notes.show_backlinks()
end

return M
