require("mason").setup()
require("mason-tool-installer").setup({
	ensure_installed = {
		"lua-language-server",
		"vim-language-server",
		"rust-analyzer",
		"vtsls",
		"svelte-language-server",
		"oxfmt",
		"prettier",
		"prettierd",
		"stylua",
	},
})

local installer = require("tree-sitter-manager.installer")
local install_func = installer.install
installer.install = function(lang, callback)
	if lang ~= "svelte5" then
		return install_func(lang, callback)
	end
	callback = callback or function() end
	return install_func(lang, function(ok)
		if not ok then
			callback(false)
			return
		end
		local util = require("tree-sitter-manager.util")
		local tmpdir = vim.fn.tempname()
		vim.notify("Downloading svelte treesitter queries")
		util.run_async(
			{ "git", "clone", "--depth=1", "https://github.com/themixednuts/nvim-treesitter-svelte", tmpdir },
			function(dl_ok)
				if dl_ok then
					local source = vim.fs.joinpath(tmpdir, "queries/svelte5")
					util.copy_dir(source, util.qpath("svelte5"))
				end
				vim.fn.delete(tmpdir, "rf")
				callback(dl_ok)
			end
		)
	end)
end

require("tree-sitter-manager").setup({
	ensure_installed = { "svelte5", "typescript", "css", "rust", "html", "javascript", "json", "json5" },
	languages = {
		svelte5 = {
			install_info = {
				url = "https://github.com/themixednuts/tree-sitter-htmlx",
				location = "crates/tree-sitter-svelte",
			},
		},
	},
})

vim.treesitter.language.add("svelte5", { symbol_name = "svelte" })
vim.treesitter.language.register("svelte5", { "svelte" })
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "svelte" },
	callback = function()
		vim.treesitter.start()
	end,
	desc = "Auto-enable svelte treesitter",
})

local blink = require("blink.cmp")
blink.build():pwait()
blink.setup()

vim.lsp.config("lua_ls", {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = {
		{
			".emmyrc.json",
			".luarc.json",
			".luarc.jsonc",
		},
		{
			".luacheckrc",
			".stylua.toml",
			"stylua.toml",
			"selene.toml",
			"selene.yml",
		},
		{ ".git" },
	},
	settings = {
		Lua = {
			codeLens = { enable = true },
			hint = { enable = true, semicolon = "Disable" },
			workspace = {
				checkThirdParty = false,
				library = {
					vim.env.VIMRUNTIME,
					vim.api.nvim_get_runtime_file("lua/lspconfig", false)[1],
				},
			},
		},
	},
})
vim.lsp.enable("lua_ls")

local js_root_markers = {
	{ "pnpm-lock.yaml", "package-lock.json", "bun.lock", "bun.lockb", "yarn.lock" },
	{ ".git" },
}

vim.lsp.config("vtsls", {
	cmd = { "vtsls", "--stdio" },
	init_options = { hostInfo = "neovim" },
	filetypes = {
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
	},
	root_markers = js_root_markers,
})
vim.lsp.enable("vtsls")

vim.lsp.config("svelte", {
	cmd = { "svelteserver", "--stdio" },
	filetypes = { "svelte" },
	root_markers = js_root_markers,
	on_attach = function(client)
		vim.api.nvim_create_autocmd("BufWritePost", {
			pattern = { "*.js", "*.ts", "*.mjs", "*.mts", "*.cjs", "*.cts" },
			group = vim.api.nvim_create_augroup("lspconfig.svelte", {}),
			callback = function(ctx)
				client:notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
			end,
		})
	end,
})
vim.lsp.enable("svelte")
