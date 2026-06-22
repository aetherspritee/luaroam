if vim.g.loaded_luaroam then
  return
end
vim.g.loaded_luaroam = 1

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

vim.api.nvim_create_user_command("LuaRoamAddArxiv", function(opts)
  require("luaroam").add_arxiv(opts.args)
end, { nargs = "?" })
