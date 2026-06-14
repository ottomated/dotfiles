require("otto.pack")
require("otto.remap")
require("otto.lsp")

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.number = true
vim.opt.relativenumber = true

require("dracula").setup({})
vim.cmd.colorscheme("dracula")

require("conform").setup({
	formatters_by_ft = {
		rust = { "rustfmt" },
		javascript = { "oxfmt", "prettierd", "prettier", stop_after_first = true },
		svelte = { "prettierd", "prettier", stop_after_first = true },
	},
	format_on_save = {
		lsp_format = "fallback",
		timeout_ms = 500
	}
})

require("mini.icons").setup()
require("oil").setup()
