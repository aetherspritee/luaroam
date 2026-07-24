local M = {}
local config = require("luaroam.config")
local parser = require("luaroam.parser")
local arxiv = require("luaroam.arxiv")

local function extract_paths(file_field)
    local paths = {}
    if not file_field or file_field == "" then
        return paths
    end

    for part in file_field:gmatch("[^;]+") do
        local clean_part = part:gsub(":[Pp][Dd][Ff]$", "")
        local path = clean_part
        if clean_part:match("^:") then
            path = clean_part:sub(2)
        else
            local is_windows_drive = clean_part:match("^%a:[/\\]")
            if not is_windows_drive then
                local desc_match = clean_part:match("^[^:]+:(.+)")
                if desc_match then
                    path = desc_match
                end
            end
        end

        path = path:gsub("^%s+", ""):gsub("%s+$", "")
        table.insert(paths, path)
    end
    return paths
end

local function resolve_path(path, bib_dir)
    local expanded = vim.fn.expand(path)

    local is_abs = false
    if expanded:match("^/") or expanded:match("^%a:[/\\]") then
        is_abs = true
    end

    if not is_abs and bib_dir then
        expanded = bib_dir .. "/" .. path
    end

    return vim.fn.expand(expanded)
end

-- Helper to get the local PDF path for an entry
function M.get_local_pdf_path(entry)
    local bib_path = config.get("bib_path")
    local bib_dir = bib_path and vim.fn.fnamemodify(bib_path, ":h") or nil
    local pdf_dir = config.get("pdf_dir")

    local keys = { entry.citekey, entry.citekey:lower(), entry.citekey:upper() }

    -- 1. Check pdf_dir/citekey.pdf (try exact, lower, and upper case)
    if pdf_dir then
        for _, key in ipairs(keys) do
            local path = pdf_dir .. "/" .. key .. ".pdf"
            local resolved = resolve_path(path, bib_dir)
            if vim.fn.filereadable(resolved) == 1 then
                return resolved
            end
        end
    end

    -- 2. Check bib_dir/citekey.pdf (same directory as bibtex file)
    if bib_dir then
        for _, key in ipairs(keys) do
            local path = bib_dir .. "/" .. key .. ".pdf"
            if vim.fn.filereadable(path) == 1 then
                return path
            end
        end
    end

    -- 3. Check file field (as fallback)
    local file_field = entry.fields.file
    if file_field and file_field ~= "" then
        local extracted = extract_paths(file_field)
        for _, path in ipairs(extracted) do
            local resolved = resolve_path(path, bib_dir)
            if vim.fn.filereadable(resolved) == 1 then
                return resolved
            end
        end
    end

    return nil
end

-- Helper to check if entry has a local PDF
function M.has_local_pdf(entry)
    return M.get_local_pdf_path(entry) ~= nil
end

-- Helper to get the remote PDF URL
function M.get_pdf_url(entry)
    if entry.fields.eprint and (not entry.fields.archiveprefix or entry.fields.archiveprefix:lower() == "arxiv") then
        return "https://arxiv.org/pdf/" .. entry.fields.eprint .. ".pdf"
    end

    local arxiv_id = arxiv.extract_id(entry.url or entry.fields.url or "")
    if arxiv_id then
        return "https://arxiv.org/pdf/" .. arxiv_id .. ".pdf"
    end

    local url = entry.url or entry.fields.url
    if url and url:match("%.pdf$") then
        return url
    end

    return nil
end

-- Function to download PDF from arxiv/url
function M.download_pdf(entry, callback)
    local pdf_url = M.get_pdf_url(entry)
    if not pdf_url then
        vim.notify("[luaroam] Could not resolve a PDF URL for entry: " .. entry.citekey, vim.log.levels.ERROR)
        return
    end

    local pdf_dir = config.get("pdf_dir")
    if not pdf_dir then
        vim.notify("[luaroam] pdf_dir is not configured.", vim.log.levels.ERROR)
        return
    end

    if vim.fn.isdirectory(pdf_dir) == 0 then
        vim.fn.mkdir(pdf_dir, "p")
    end

    local dest = pdf_dir .. "/" .. entry.citekey .. ".pdf"
    vim.notify("[luaroam] Downloading PDF for " .. entry.citekey .. "...", vim.log.levels.INFO)

    vim.system({ "curl", "-s", "-L", "-o", dest, pdf_url }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code ~= 0 then
                vim.notify("[luaroam] Failed to download PDF from: " .. pdf_url, vim.log.levels.ERROR)
                return
            end

            vim.notify("[luaroam] PDF downloaded successfully: " .. dest, vim.log.levels.INFO)

            -- Link the PDF to the BibTeX entry
            local bib_path = config.get("bib_path")
            if bib_path then
                local ok, err = parser.update_entry_field(bib_path, entry.citekey, "file", dest)
                if ok then
                    vim.notify("[luaroam] Linked PDF to BibTeX entry for " .. entry.citekey, vim.log.levels.INFO)
                else
                    vim.notify("[luaroam] Failed to update BibTeX file: " .. tostring(err), vim.log.levels.ERROR)
                end
            end

            if callback then
                callback(dest)
            end
        end)
    end)
end

-- Open the PDF for an entry
function M.open_pdf(entry)
    local pdf_path = M.get_local_pdf_path(entry)

    local function open_file(path)
        local viewer = config.options.pdf_viewer
        if viewer and viewer ~= "" then
            local cmd
            if type(viewer) == "table" then
                cmd = vim.list_slice(viewer)
                table.insert(cmd, path)
            else
                cmd = { viewer, path }
            end
            vim.fn.jobstart(cmd, { detach = true })
        else
            if vim.ui.open then
                vim.ui.open(path)
            else
                local cmd
                if vim.fn.has("mac") == 1 then
                    cmd = { "open", path }
                elseif vim.fn.has("win32") == 1 then
                    cmd = { "cmd.exe", "/c", "start", path }
                else
                    cmd = { "xdg-open", path }
                end
                vim.fn.jobstart(cmd, { detach = true })
            end
        end
        vim.notify("[luaroam] Opening PDF: " .. path, vim.log.levels.INFO)
    end

    if pdf_path then
        open_file(pdf_path)
    else
        local has_url = M.get_pdf_url(entry) ~= nil
        if has_url then
            vim.ui.select({ "Yes", "No" }, {
                prompt = "No local PDF found. Download PDF from arXiv?",
            }, function(choice)
                if choice == "Yes" then
                    M.download_pdf(entry, function(downloaded_path)
                        open_file(downloaded_path)
                    end)
                end
            end)
        else
            vim.notify("[luaroam] No PDF found or resolvable URL for entry: " .. entry.citekey, vim.log.levels.WARN)
        end
    end
end

-- Helper to format entry display (matching the one in init.lua)
local function clean_braces(str)
    if not str then return "" end
    return str:gsub("[{}]", "")
end

local function format_entry_display(entry)
    local author = clean_braces(entry.author or "")
    if author:find(" and ") then
        author = author:sub(1, author:find(" and ") - 1) .. " et al."
    end
    local title = clean_braces(entry.title or "")
    local year = entry.year or ""

    local display = string.format("[%s] %s - %s", entry.citekey, author, title)
    if year ~= "" then
        display = display .. " (" .. year .. ")"
    end
    return display
end

-- Snacks picker listing of all PDF files
function M.snacks_list_pdfs()
    local has_snacks, Snacks = pcall(require, "snacks")
    if not has_snacks or not Snacks.picker then
        vim.notify("[luaroam] snacks.nvim picker is not available", vim.log.levels.ERROR)
        return
    end

    local bib_path = config.get("bib_path")
    if not bib_path or vim.fn.filereadable(bib_path) == 0 then
        vim.notify("[luaroam] BibTeX file not found", vim.log.levels.ERROR)
        return
    end

    local entries = parser.parse_file(bib_path)
    local pdf_entries = {}
    for _, entry in ipairs(entries) do
        if M.has_local_pdf(entry) then
            table.insert(pdf_entries, entry)
        end
    end

    if #pdf_entries == 0 then
        vim.notify("[luaroam] No papers with local PDFs found", vim.log.levels.WARN)
        return
    end

    table.sort(pdf_entries, function(a, b)
        return a.citekey:lower() < b.citekey:lower()
    end)

    local items = {}
    for _, entry in ipairs(pdf_entries) do
        table.insert(items, {
            text = format_entry_display(entry),
            value = entry,
        })
    end

    Snacks.picker.pick({
        source = "luaroam-pdfs",
        title = "LuaRoam PDFs",
        items = items,
        confirm = function(picker, item)
            picker:close()
            if item and item.value then
                M.open_pdf(item.value)
            end
        end,
    })
end

return M
