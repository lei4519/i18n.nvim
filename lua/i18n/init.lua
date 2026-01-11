--- i18n 插件主入口
local config = require("i18n.config")
local parser = require("i18n.parser")
local translator = require("i18n.translator")
local virt_text = require("i18n.virt_text")
local editor = require("i18n.editor")
local completion = require("i18n.completion")
local checker = require("i18n.checker")

local M = {}

-- 导出模块供外部使用
M.completion = completion
M.checker = checker

-- 内部状态
local state = {
	timer = nil,
	augroup = nil,
	initialized = false,
}

--- 更新缓冲区的虚拟文本（完整更新）
--- @param bufnr number 缓冲区号
local function update_buffer_full(bufnr)
	if not config.config.enabled or not config.config.virt_text.enabled then
		return
	end

	local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
	if not config.is_supported_filetype(filetype) then
		return
	end

	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		return
	end

	local i18n_dir = config.get_i18n_dir(bufnr)
	if not i18n_dir or vim.fn.isdirectory(i18n_dir) == 0 then
		return
	end

	-- 清除旧的虚拟文本
	virt_text.clear_buffer_virt_text(bufnr)

	-- 获取当前语言的 JSON 文件
	local languages = translator.get_available_languages(i18n_dir)
	local current_lang = config.get_current_language()
	local json_file = languages[current_lang]

	if not json_file then
		return
	end

	-- 解析文件中的 t() 调用
	parser.parse_file_async(filepath, function(results)
		-- 收集所有翻译结果，等待全部完成后再按顺序设置（避免 inline 虚拟文本改变后面的位置）
		local translations = {}
		local pending_count = #results

		if pending_count == 0 then
			return
		end

		for i, result in ipairs(results) do
			translator.get_translation_async(json_file, result.key, function(translation, _)
				translations[i] = {
					result = result,
					translation = translation,
				}

				pending_count = pending_count - 1

				-- 所有翻译都完成后，按从后往前的顺序设置虚拟文本
				if pending_count == 0 then
					-- 按行号和列号排序，从后往前处理
					table.sort(translations, function(a, b)
						if a.result.line == b.result.line then
							return a.result.col > b.result.col
						end
						return a.result.line > b.result.line
					end)

					-- 设置虚拟文本
					for _, item in ipairs(translations) do
						if item.translation then
							virt_text.set_virt_text(bufnr, item.result.line, item.result.col, item.translation)
						end
					end
				end
			end)
		end
	end)
end

--- 更新缓冲区的虚拟文本（增量更新）
--- @param bufnr number 缓冲区号
--- @param line_start number 起始行号 (1-based)
--- @param line_end number 结束行号 (1-based)
local function update_buffer_incremental(bufnr, line_start, line_end)
	if not config.config.enabled or not config.config.virt_text.enabled then
		return
	end

	local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
	if not config.is_supported_filetype(filetype) then
		return
	end

	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		return
	end

	local i18n_dir = config.get_i18n_dir(bufnr)
	if not i18n_dir or vim.fn.isdirectory(i18n_dir) == 0 then
		return
	end

	local languages = translator.get_available_languages(i18n_dir)
	local current_lang = config.get_current_language()
	local json_file = languages[current_lang]

	if not json_file then
		return
	end

	-- 更新变化的行
	for line = line_start, line_end do
		-- 清除该行的虚拟文本
		virt_text.clear_line_virt_text(bufnr, line)

		-- 解析该行（传入 bufnr 以读取未保存的缓冲区内容）
		parser.parse_line_async(bufnr, line, function(results)
			-- 收集所有翻译结果，等待全部完成后再按顺序设置
			local translations = {}
			local pending_count = #results

			if pending_count == 0 then
				return
			end

			for i, result in ipairs(results) do
				translator.get_translation_async(json_file, result.key, function(translation, _)
					translations[i] = {
						result = result,
						translation = translation,
					}

					pending_count = pending_count - 1

					-- 所有翻译都完成后，按从后往前的顺序设置虚拟文本
					if pending_count == 0 then
						-- 按列号排序，从后往前处理（同一行）
						table.sort(translations, function(a, b)
							return a.result.col > b.result.col
						end)

						-- 设置虚拟文本
						for _, item in ipairs(translations) do
							if item.translation then
								virt_text.set_virt_text(bufnr, item.result.line, item.result.col, item.translation)
							end
						end
					end
				end)
			end
		end)
	end
end

--- 停止插件并清理资源
function M.disable()
	-- 停止 timer
	if state.timer then
		state.timer:stop()
		state.timer:close()
		state.timer = nil
	end

	-- 清除自动命令组
	if state.augroup then
		vim.api.nvim_del_augroup_by_id(state.augroup)
		state.augroup = nil
	end

	-- 清除所有虚拟文本
	virt_text.clear_all_virt_text()

	-- 清除缓存
	config.clear_all_cache()
	translator.clear_cache()

	state.initialized = false
end

--- 插件设置
--- @param opts table|nil 用户配置
function M.setup(opts)
	-- 如果已经初始化，先清理
	if state.initialized then
		M.disable()
	end

	-- 配置初始化
	config.setup(opts)

	-- 设置高亮组
	vim.api.nvim_set_hl(0, "@i18n.translation", { link = config.config.virt_text.highlight })

	-- 创建自动命令组
	local group = vim.api.nvim_create_augroup("i18n", { clear = true })
	state.augroup = group

	-- 跟踪已初始化的缓冲区
	local initialized_buffers = {}

	-- 增量更新: 使用 buf_attach 监听文本变化
	-- 使用 debounce 避免频繁更新
	local timer = vim.uv.new_timer()
	state.timer = timer
	local pending_updates = {}

	local function process_pending_updates()
		for bufnr, lines in pairs(pending_updates) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				local line_start = math.min(unpack(lines))
				local line_end = math.max(unpack(lines))
				update_buffer_incremental(bufnr, line_start, line_end)
			end
		end
		pending_updates = {}
	end

	local function schedule_update(bufnr, line_start, line_end)
		-- 添加到待更新列表
		if not pending_updates[bufnr] then
			pending_updates[bufnr] = {}
		end

		-- 添加变化的行范围
		for line = line_start, line_end do
			table.insert(pending_updates[bufnr], line)
		end

		-- 重启定时器（debounce）
		timer:stop()
		timer:start(
			config.config.debounce_delay, -- 使用配置的延迟时间
			0,
			vim.schedule_wrap(process_pending_updates)
		)
	end

	-- 根据配置的文件类型生成 pattern
	local function get_file_patterns()
		local patterns = {}
		local filetype_to_ext = {
			typescript = "*.ts",
			javascript = "*.js",
			typescriptreact = "*.tsx",
			javascriptreact = "*.jsx",
			vue = "*.vue",
			svelte = "*.svelte",
		}
		for _, ft in ipairs(config.config.filetypes) do
			if filetype_to_ext[ft] then
				table.insert(patterns, filetype_to_ext[ft])
			end
		end
		return patterns
	end

	-- BufEnter: 首次打开时完整更新，并附加监听器
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = get_file_patterns(),
		callback = function(ev)
			local bufnr = ev.buf

			-- 只在首次进入缓冲区时进行完整更新
			if not initialized_buffers[bufnr] then
				initialized_buffers[bufnr] = true
				update_buffer_full(bufnr)
			end

			-- 为缓冲区附加监听器（避免重复附加）
			if not vim.b[bufnr].i18n_attached then
				vim.b[bufnr].i18n_attached = true

				-- 附加到缓冲区以监听变化
				vim.api.nvim_buf_attach(bufnr, false, {
					on_lines = function(_, buf, _, first_line, old_last_line, new_last_line)
						if not vim.api.nvim_buf_is_valid(buf) then
							return false
						end

						-- 将 0-based 转为 1-based
						local line_start = first_line + 1

						-- 检测是否有行被删除
						if new_last_line < old_last_line then
							-- 有行被删除
							-- extmarks 会自动随行删除而移除，但需要清理我们的跟踪表
							-- 清理被删除行的虚拟文本（使用 namespace API 更可靠）
							pcall(
								vim.api.nvim_buf_clear_namespace,
								buf,
								virt_text.get_namespace(),
								first_line,
								old_last_line
							)
						end

						-- 计算需要更新的行范围（使用变化后的行号）
						local line_end = new_last_line -- new_last_line 是变化后的最后一行的下一行 (0-based)

						-- 确保至少更新一行
						if line_end <= first_line then
							line_end = first_line + 1
						end

						-- 调度更新（转为 1-based）
						schedule_update(buf, line_start, line_end)

						return false -- 不detach
					end,
				})
			end
		end,
	})

	-- BufDelete: 清理缓冲区初始化标记
	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(ev)
			initialized_buffers[ev.buf] = nil
			-- 清理虚拟文本跟踪数据
			virt_text.clear_buffer_virt_text(ev.buf)
		end,
	})

	-- 用户命令
	-- 切换虚拟文本显示
	vim.api.nvim_create_user_command("I18nToggle", function()
		local enabled = virt_text.toggle_virt_text()
		if enabled then
			vim.notify("I18n virtual text enabled", vim.log.levels.INFO)
			-- 刷新当前缓冲区
			update_buffer_full(vim.api.nvim_get_current_buf())
		else
			vim.notify("I18n virtual text disabled", vim.log.levels.INFO)
		end
	end, {})

	-- 设置当前语言
	vim.api.nvim_create_user_command("I18nSetLang", function(opts)
		local lang = opts.args
		if lang == "" then
			-- 显示可用语言列表
			local i18n_dir = config.get_i18n_dir()
			if not i18n_dir then
				vim.notify("Cannot find i18n directory", vim.log.levels.ERROR)
				return
			end

			local languages = translator.get_available_languages(i18n_dir)
			local lang_list = vim.tbl_keys(languages)

			if #lang_list == 0 then
				vim.notify("No translation files found", vim.log.levels.ERROR)
				return
			end

			vim.ui.select(lang_list, {
				prompt = "Select language:",
			}, function(selected)
				if selected then
					config.set_current_language(selected)
					vim.notify("Language set to: " .. selected, vim.log.levels.INFO)

					-- 刷新所有缓冲区
					for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
						if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
							local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
							if config.is_supported_filetype(filetype) then
								update_buffer_full(bufnr)
							end
						end
					end
				end
			end)
		else
			config.set_current_language(lang)
			vim.notify("Language set to: " .. lang, vim.log.levels.INFO)

			-- 刷新所有缓冲区
			for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
					local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
					if config.is_supported_filetype(filetype) then
						update_buffer_full(bufnr)
					end
				end
			end
		end
	end, {
		nargs = "?",
		desc = "Set current language for i18n display",
	})

	-- 打开多语言编辑器
	vim.api.nvim_create_user_command("I18nEdit", function(opts)
		local key = opts.args

		if key == "" then
			-- 尝试从光标位置获取 key
			key = editor.get_key_under_cursor()
		end

		if not key or key == "" then
			vim.notify("No i18n key found. Usage: :I18nEdit <key>", vim.log.levels.ERROR)
			return
		end

		editor.open_editor(key)
	end, {
		nargs = "?",
		desc = "Open i18n editor for a key",
	})

	-- 刷新当前缓冲区
	vim.api.nvim_create_user_command("I18nRefresh", function()
		translator.clear_cache()
		update_buffer_full(vim.api.nvim_get_current_buf())
		vim.notify("I18n virtual text refreshed", vim.log.levels.INFO)
	end, {
		desc = "Refresh i18n virtual text for current buffer",
	})

	-- 检查翻译缺失
	vim.api.nvim_create_user_command("I18nCheck", function()
		local bufnr = vim.api.nvim_get_current_buf()
		local filepath = vim.api.nvim_buf_get_name(bufnr)

		if filepath == "" then
			vim.notify("No file in buffer", vim.log.levels.ERROR)
			return
		end

		checker.generate_report_async(filepath, function(report)
			-- 在新缓冲区中显示报告（底部水平分屏）
			local buf = vim.api.nvim_create_buf(false, true)
			vim.cmd("botright split")

			local win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(win, buf)
			vim.api.nvim_win_set_height(win, math.min(15, math.floor(vim.o.lines * 0.3)))

			vim.wo[win].statusline = "%#Title# 📋 I18n Translation Check Report %*"
			vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
			vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(report, "\n"))
			vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

			-- 添加关闭快捷键
			vim.keymap.set("n", "q", function()
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end, { buffer = buf, nowait = true })
		end)
	end, {
		desc = "Check for missing translations",
	})

	-- 清空所有缓存
	vim.api.nvim_create_user_command("I18nClearCache", function()
		-- 清空配置缓存（项目根目录和 i18n 目录缓存）
		config.clear_all_cache()
		-- 清空翻译缓存和语言列表缓存
		translator.clear_cache()
		vim.notify("All i18n caches cleared", vim.log.levels.INFO)
	end, {
		desc = "Clear all i18n caches (project root, i18n dir, translations, languages)",
	})

	-- VimLeavePre: 退出 Vim 前清理资源
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			if state.timer then
				state.timer:stop()
				state.timer:close()
				state.timer = nil
			end
		end,
	})

	state.initialized = true
end

return M
