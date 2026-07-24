local M = {}
local config = require("luaroam.config")
local parser = require("luaroam.parser")

function M.extract_id(input)
    input = input:gsub("^%s+", ""):gsub("%s+$", "")

    -- Match arxiv.org URLs (both abs and pdf formats)
    local match = input:match("arxiv%.org/abs/([^%s%?]+)") or input:match("arxiv%.org/pdf/([^%s%?]+)")
    if match then
        match = match:gsub("%.pdf$", "")
        return match
    end

    -- Match arxiv:ID format
    local prefix_match = input:match("^arxiv:(.+)")
    if prefix_match then
        return prefix_match
    end

    -- Check if it looks like an ID (new style: 2301.00001, old style: hep-th/9711200)
    if input:match("^%d+%.%d+$") or input:match("^%a+-%a+/%d+$") or input:match("^%a+/%d+$") then
        return input
    end

    -- Fallback: return input if it contains at least digits
    if input:match("%d") then
        return input
    end

    return nil
end

function M.add_arxiv_entry(input, callback)
    local id = M.extract_id(input)
    if not id then
        vim.notify("[luaroam] Could not parse arXiv ID from: " .. input, vim.log.levels.ERROR)
        return
    end

    local bib_path = config.get("bib_path")
    if not bib_path then
        vim.notify("[luaroam] bib_path is not configured. Setup the plugin first.", vim.log.levels.ERROR)
        return
    end

    vim.notify("[luaroam] Fetching BibTeX for arXiv ID: " .. id, vim.log.levels.INFO)

    local url = "https://arxiv.org/bibtex/" .. id
    vim.system({ "curl", "-s", "-L", url }, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code ~= 0 or not obj.stdout or obj.stdout == "" then
                vim.notify("[luaroam] Failed to fetch BibTeX from: " .. url, vim.log.levels.ERROR)
                return
            end

            local fetched_bib = obj.stdout

            -- Validate and parse the entry
            local parsed_entry = parser.parse_entry_string(fetched_bib)
            if not parsed_entry then
                vim.notify("[luaroam] Failed to parse fetched BibTeX entry", vim.log.levels.ERROR)
                return
            end

            -- Format the new citekey based on configuration
            local new_citekey = parsed_entry.citekey
            if config.options.format_citekey then
                new_citekey = config.options.format_citekey(parsed_entry)
            end

            -- Build a set of existing citekeys for fast lookup
            local current_entries = parser.parse_file(bib_path)
            local existing_keys = {}
            for _, entry in ipairs(current_entries) do
                existing_keys[entry.citekey] = true
            end

            -- If the citekey already exists, append 'a', 'b', ... until unique
            if existing_keys[new_citekey] then
                local base_citekey = new_citekey
                local found = false
                for i = 0, 25 do
                    local candidate = base_citekey .. string.char(string.byte("a") + i)
                    if not existing_keys[candidate] then
                        new_citekey = candidate
                        found = true
                        break
                    end
                end
                if not found then
                    vim.notify("[luaroam] Could not find a unique citekey for: " .. base_citekey, vim.log.levels.ERROR)
                    return
                end
                vim.notify("[luaroam] Citekey conflict — using adjusted citekey: " .. new_citekey, vim.log.levels.INFO)
            end

            -- Replace citekey in the raw string
            local modified_bib = fetched_bib:gsub("(@%a+%s*%{%s*)[^,%s]+", "%1" .. new_citekey, 1)

            -- Check if file exists and create parent directories if not
            local parent_dir = vim.fn.fnamemodify(bib_path, ":h")
            if vim.fn.isdirectory(parent_dir) == 0 then
                vim.fn.mkdir(parent_dir, "p")
            end

            -- Read last character of the file to see if we need a leading newline
            local needs_leading_newline = true
            local read_f = io.open(bib_path, "r")
            if read_f then
                local size = read_f:seek("end")
                if size > 0 then
                    read_f:seek("set", size - 1)
                    local last_char = read_f:read(1)
                    if last_char == "\n" then
                        needs_leading_newline = false
                    end
                else
                    needs_leading_newline = false
                end
                read_f:close()
            end

            local write_f = io.open(bib_path, "a")
            if not write_f then
                vim.notify("[luaroam] Failed to open " .. bib_path .. " for writing", vim.log.levels.ERROR)
                return
            end

            local prefix = needs_leading_newline and "\n" or ""
            if not modified_bib:match("\n$") then
                modified_bib = modified_bib .. "\n"
            end

            write_f:write(prefix .. modified_bib)
            write_f:close()

            vim.notify("[luaroam] Successfully added " .. new_citekey .. " to " .. bib_path, vim.log.levels.INFO)

            -- Find the newly added entry in the file
            local new_entries = parser.parse_file(bib_path)
            local new_entry = nil
            for _, entry in ipairs(new_entries) do
                if entry.citekey == new_citekey then
                    new_entry = entry
                    break
                end
            end

            if new_entry then
                -- Automatically download PDF and name it after the citekey
                local pdf = require("luaroam.pdf")
                pdf.download_pdf(new_entry, function(pdf_path)
                    if callback then
                        -- Reparse to ensure file field changes are loaded
                        local updated_entries = parser.parse_file(bib_path)
                        for _, entry in ipairs(updated_entries) do
                            if entry.citekey == new_citekey then
                                callback(entry)
                                return
                            end
                        end
                        callback(new_entry)
                    end
                end)
            end
        end)
    end)
end

return M
