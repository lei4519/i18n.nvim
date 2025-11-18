local i18n = {}

i18n.setup = function(opts)
	local hl = vim.api.nvim_set_hl

	hl(0, "@i18n.translation", { link = "Comment" })

	local group = vim.api.nvim_create_augroup("i18n", {})

	vim.api.nvim_create_autocmd({
		"BufEnter",
		"TextChanged",
		"TextChangedI",
		"TextChangedP",
	}, {
		pattern = "*.{ts,js,tsx,jsx}",
		group = group,
		callback = function(ev)
			end
	})
end

return i18n
