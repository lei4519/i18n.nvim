-- local virt_text = require("i18n.virt_text")

local i18n = {}

i18n.client = nil

i18n.setup = function(opts)
	local hl = vim.api.nvim_set_hl

	hl(0, "@i18n.translation", { link = "Comment" })

	local group = vim.api.nvim_create_augroup("js-i18n", {})

	vim.api.nvim_create_autocmd({
		"BufEnter",
		"TextChanged",
		"TextChangedI",
		"TextChangedP",
	}, {
		pattern = "*.{ts,js,tsx,jsx}",
		group = group,
		callback = function(ev)
			-- if ev.event == "TextChangedI" then
			-- vim.notify("i18n event triggered: " .. ev.event, vim.log.levels.DEBUG)
			-- return
			-- end
			-- local bufnr = ev.buf
			-- virt_text.set_extmark(bufnr, )
			-- i18n.client:update_js_file_handler(bufnr)

			-- local workspace_dir = utils.get_workspace_root(bufnr)
		end,
	})
end

return i18n
