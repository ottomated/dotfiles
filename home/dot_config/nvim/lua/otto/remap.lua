vim.g.mapleader = ","
vim.keymap.set("n", "<leader>pv", vim.cmd.Oil)
vim.keymap.set("n", "<C-p>", require("telescope.builtin").git_files, {})

vim.keymap.set("n", "<C-/>", "gcc", { desc = "Toggle comments", remap = true })
vim.keymap.set("i", "<C-/>", "<Esc>gcci", { desc = "Toggle comments", remap = true })
vim.keymap.set("v", "<C-/>", "gc", { desc = "Toggle comments", remap = true })

vim.keymap.set({ "n", "i" }, "<C-s>", "<cmd>w<CR>", { desc = "Save" })
local flash = require("flash")
vim.keymap.set("n", "s", function() flash.jump() end, { desc = "Flash" })
