if vim.g.loaded_luaroam then
  return
end
vim.g.loaded_luaroam = 1

local function add_arxiv_cmd(opts)
  local arg = opts.args
  if arg and arg ~= "" then
    require("luaroam").add_arxiv(arg)
  else
    local cword = vim.fn.expand("<cWORD>")
    cword = cword:gsub("^['\"%(%[%<]+", ""):gsub("['\"%)%]%>%.,;]+$", "")
    
    local is_arxiv = false
    if cword:match("arxiv%.org") or cword:match("^arxiv:") or cword:match("^%d+%.%d+$") then
      is_arxiv = true
    end

    if is_arxiv then
      require("luaroam").add_arxiv(cword)
    else
      vim.ui.input({
        prompt = "Enter arXiv Link or ID: ",
      }, function(input)
        if input and input ~= "" then
          require("luaroam").add_arxiv(input)
        end
      end)
    end
  end
end

vim.api.nvim_create_user_command("LuaRoamSelect", function()
  require("luaroam").open_papers_menu()
end, {})

vim.api.nvim_create_user_command("LuaRoamInsert", function()
  require("luaroam").insert_reference()
end, {})

vim.api.nvim_create_user_command("LuaRoamNote", function()
  require("luaroam").open_note()
end, {})

vim.api.nvim_create_user_command("LuaRoamOpenUrl", function()
  require("luaroam").open_url()
end, {})

vim.api.nvim_create_user_command("LuaRoamGoToBib", function()
  require("luaroam").go_to_bib()
end, {})

vim.api.nvim_create_user_command("LuaRoamOpenPdf", function()
  require("luaroam").open_pdf()
end, {})

vim.api.nvim_create_user_command("LuaRoamDownloadPdf", function()
  require("luaroam").download_pdf()
end, {})

vim.api.nvim_create_user_command("LuaRoamPdfs", function()
  require("luaroam").snacks_list_pdfs()
end, {})

vim.api.nvim_create_user_command("LuaRoamAddArxiv", add_arxiv_cmd, { nargs = "?" })
