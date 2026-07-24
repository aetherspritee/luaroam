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

local function find_entry_by_citekey(citekey)
    local bib_path = config.get("bib_path")
    if bib_path and vim.fn.filereadable(bib_path) == 1 then
        local parser = require("luaroam.parser")
        local entries = parser.parse_file(bib_path)
        for _, e in ipairs(entries) do
            if e.citekey == citekey then
                return e
            end
        end
    end
    return { citekey = citekey }
end

local function get_current_note_citekey()
    -- Read first 15 lines of current buffer to look for citekey in frontmatter
    local lines = vim.api.nvim_buf_get_lines(0, 0, 15, false)
    for _, line in ipairs(lines) do
        local citekey = line:match("^citekey:%s*(.-)%s*$")
        if citekey and citekey ~= "" then
            return citekey
        end
    end

    -- Fallback: filename
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == "" then return nil end
    local filename = vim.fn.fnamemodify(bufname, ":t")
    return filename:gsub("%.md$", "")
end

local function search_backlinks_rg(notes_dir, citekey)
    local cmd = { "rg", "--vimgrep", "--word-regexp", citekey, notes_dir }
    local obj = vim.system(cmd, { text = true }):wait()
    if obj.code ~= 0 or not obj.stdout or obj.stdout == "" then
        return {}
    end

    local qf_list = {}
    for line in string.gmatch(obj.stdout, "[^\r\n]+") do
        local file, lnum, col, text = line:match("^([^:]+):(%d+):(%d+):(.*)$")
        if file and lnum then
            table.insert(qf_list, {
                filename = file,
                lnum = tonumber(lnum),
                col = tonumber(col),
                text = text,
            })
        end
    end
    return qf_list
end

local function search_backlinks_lua(notes_dir, citekey)
    local qf_list = {}
    local handle = vim.loop.fs_scandir(notes_dir)
    if not handle then return qf_list end

    while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        if type == "file" and name:match("%.md$") then
            local filepath = notes_dir .. "/" .. name
            local f = io.open(filepath, "r")
            if f then
                local lnum = 1
                for line in f:lines() do
                    if line:find(citekey, 1, true) then
                        table.insert(qf_list, {
                            filename = filepath,
                            lnum = lnum,
                            col = 1,
                            text = line,
                        })
                    end
                    lnum = lnum + 1
                end
                f:close()
            end
        end
    end
    return qf_list
end

-- Helper to extract citekey under the cursor
function M.get_link_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    -- 1. Try Wiki-link: [[citekey]] or [[citekey|text]]
    local s_start = 1
    while true do
        local start_idx, end_idx, citekey = line:find("%[%[([^%]]+)%]%]", s_start)
        if not start_idx then break end
        if col >= start_idx and col <= end_idx then
            local pipe = citekey:find("|")
            if pipe then
                citekey = citekey:sub(1, pipe - 1)
            end
            return citekey
        end
        s_start = end_idx + 1
    end

    -- 2. Try Markdown link: [text](citekey.md) or [text](citekey)
    s_start = 1
    while true do
        local start_idx, end_idx, _, path = line:find("%[(.-)%]%((.-)%)", s_start)
        if not start_idx then break end
        if col >= start_idx and col <= end_idx then
            local filename = vim.fn.fnamemodify(path, ":t")
            local citekey = filename:gsub("%.md$", "")
            return citekey
        end
        s_start = end_idx + 1
    end

    -- 3. Try @citekey pattern
    s_start = 1
    while true do
        local start_idx, end_idx, citekey = line:find("@([%w%-_]+)", s_start)
        if not start_idx then break end
        if col >= start_idx and col <= end_idx then
            return citekey
        end
        s_start = end_idx + 1
    end

    return nil
end

function M.follow_link()
    local citekey = M.get_link_under_cursor()
    if not citekey then
        vim.notify("[luaroam] No link or citekey found under cursor.", vim.log.levels.WARN)
        return
    end

    local entry = find_entry_by_citekey(citekey)
    M.open_note(entry)
end

function M.insert_link(entry)
    local format = config.get("link_format") or "markdown"
    local citekey = entry.citekey
    local title = entry.title or (entry.fields and entry.fields.title) or citekey
    title = title:gsub("[{}]", "")

    local link_str
    if format == "wiki" then
        link_str = string.format("[[%s|%s]]", citekey, title)
    elseif format == "citekey" then
        link_str = "@" .. citekey
    else -- "markdown"
        local filename = config.options.note_name(entry)
        link_str = string.format("[%s](%s)", title, filename)
    end

    vim.api.nvim_put({ link_str }, "c", true, true)
end

function M.show_backlinks()
    local citekey = get_current_note_citekey()
    if not citekey then
        vim.notify("[luaroam] Could not determine citekey for current note.", vim.log.levels.WARN)
        return
    end

    local notes_dir = config.get("notes_dir")
    if not notes_dir or vim.fn.isdirectory(notes_dir) == 0 then
        vim.notify("[luaroam] notes_dir is not configured or does not exist.", vim.log.levels.ERROR)
        return
    end

    local qf_list = {}
    if vim.fn.executable("rg") == 1 and vim.system then
        qf_list = search_backlinks_rg(notes_dir, citekey)
    else
        qf_list = search_backlinks_lua(notes_dir, citekey)
    end

    -- Filter out matches from the current note file itself
    local current_buf_path = vim.api.nvim_buf_get_name(0)
    local filtered_qf = {}
    for _, item in ipairs(qf_list) do
        if vim.fn.fnamemodify(item.filename, ":p") ~= vim.fn.fnamemodify(current_buf_path, ":p") then
            table.insert(filtered_qf, item)
        end
    end

    if #filtered_qf == 0 then
        vim.notify("[luaroam] No backlinks found for " .. citekey, vim.log.levels.INFO)
        return
    end

    vim.fn.setqflist(filtered_qf, "r")
    vim.cmd("copen")
    vim.notify(string.format("[luaroam] Found %d backlinks for %s", #filtered_qf, citekey), vim.log.levels.INFO)
end

return M
