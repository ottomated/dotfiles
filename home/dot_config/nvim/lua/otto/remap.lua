vim.g.mapleader = ","
vim.keymap.set("n", "<leader>p", function()
	MiniFiles.open()
end)

vim.keymap.set("n", "<C-p>", function()
	MiniFiles.close()
	local git_path = vim.fs.joinpath(vim.uv.cwd(), ".git")
	local is_git = vim.uv.fs_stat(git_path)
	local pickers = is_git and "git_files" or "files"
	require("fzf-lua").combine({ pickers = pickers })
end, {})
vim.keymap.set("n", "<C-f>", function()
	MiniFiles.close()
	require("fzf-lua").live_grep()
end, {})

vim.cmd("ca qq qa")
vim.cmd("ca wqq wqa")

vim.keymap.set("n", "<C-/>", "gcc", { desc = "Toggle comments", remap = true })
vim.keymap.set("i", "<C-/>", "<Esc>gcci", { desc = "Toggle comments", remap = true })
vim.keymap.set("v", "<C-/>", "gc", { desc = "Toggle comments", remap = true })

vim.keymap.set({ "n", "i" }, "<C-s>", "<cmd>w<CR>", { desc = "Save" })
local flash = require("flash")
vim.keymap.set("n", "s", function()
	flash.jump()
end, { desc = "Flash" })
