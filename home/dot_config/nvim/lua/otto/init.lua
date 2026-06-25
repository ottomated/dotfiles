require("otto.pack")
require("otto.remap")
require("otto.lsp")

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"

require("dracula").setup({})
vim.cmd.colorscheme("dracula")

require("conform").setup({
	formatters_by_ft = {
		rust = { "rustfmt" },
		javascript = { "oxfmt", "prettierd", "prettier", stop_after_first = true },
		svelte = { "prettierd", "prettier", stop_after_first = true },
		lua = { "stylua" },
	},
	format_on_save = {
		lsp_format = "fallback",
		timeout_ms = 500,
	},
})

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		if #vim.v.argf ~= 1 then
			return
		end
		local dir = vim.v.argf[1]
		local stat = vim.uv.fs_stat(dir)
		if stat == nil or stat.type ~= "directory" then
			return
		end
		dir = dir:gsub("/$", "")
		local name = vim.fs.basename(dir) .. " (" .. vim.fs.basename(vim.fs.dirname(dir)) .. ")"
		if MiniSessions.detected[name] then
			vim.schedule(function()
				MiniSessions.read(name)
			end)
		else
			MiniSessions.write(name)
		end
		vim.api.nvim_set_current_dir(dir)
	end,
	desc = "Create mini.session",
})
require("mini.icons").setup()
require("mini.files").setup({
	mappings = {
		go_in_plus = "<CR>",
	},
})
require("mini.sessions").setup()
require("mini.starter").setup({
	footer = "",
})
require("ibl").setup()
require("supermaven-nvim").setup({})
-- require("mini.indentscope").setup({
--     draw = {
--
--     }
-- })
--require("oil").setup()
-- require("neo-tree").setup({
--     close_if_last_window = true,
--     window = {
--             mappings = {
--                     ["q"] = "close_window",
--             },
--     },
--     filesystem = {
--             hijack_netrw_behavior = "open_current",
--     },
--     event_handlers = {
--             {
--                     event = "file-opened",
--                     handler = function()
--                             print("opened")
--                     end,
--             },
--             {
--                     event = "after_render",
--                     handler = function()
--                             vim.defer_fn(function()
--                                     local state = require("neo-tree.sources.manager").get_state("filesystem")
--                                     if not require("neo-tree.sources.common.preview").is_active() then
--                                             state.config = { use_float = false } -- or whatever your config is
--                                             state.commands.toggle_preview(state)
--                                     end
--                             end, 10)
--                     end,
--             },
--     },
-- })
