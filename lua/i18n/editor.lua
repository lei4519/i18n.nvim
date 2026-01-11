--- 多语言编辑面板
local config = require("i18n.config")
local translator = require("i18n.translator")
local openai = require("i18n.openai")

local M = {}

--- 打开多语言编辑面板
--- @param key string i18n key
function M.open_editor(key)
  if not key or key == "" then
    vim.notify("No i18n key provided", vim.log.levels.ERROR)
    return
  end

  local i18n_dir = config.get_i18n_dir()
  if not i18n_dir then
    vim.notify("Cannot find i18n directory", vim.log.levels.ERROR)
    return
  end

  -- 获取所有可用语言
  local languages = translator.get_available_languages(i18n_dir)

  if vim.tbl_isempty(languages) then
    vim.notify("No translation files found in " .. i18n_dir, vim.log.levels.ERROR)
    return
  end

  -- 对语言进行排序：默认语言在前，其他按字母排序
  local default_lang = config.config.default_language
  local sorted_langs = {}

  -- 先添加默认语言（如果存在）
  if languages[default_lang] then
    table.insert(sorted_langs, default_lang)
  end

  -- 收集其他语言并排序
  local other_langs = {}
  for lang, _ in pairs(languages) do
    if lang ~= default_lang then
      table.insert(other_langs, lang)
    end
  end
  table.sort(other_langs)

  -- 添加其他语言
  for _, lang in ipairs(other_langs) do
    table.insert(sorted_langs, lang)
  end

  -- 创建缓冲区
  local buf = vim.api.nvim_create_buf(false, true)

  -- 创建右侧垂直分屏窗口
  vim.cmd("botright vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- 设置窗口宽度，默认为屏幕宽度的40%，最小60列
  local window_width = math.max(60, math.floor(vim.o.columns * 0.4))
  vim.api.nvim_win_set_width(win, window_width)

  -- 设置窗口标题（使用状态栏）
  vim.wo[win].statusline = string.format("%%#Title# 🌐 I18n Editor: %s %%*", key)

  -- 设置缓冲区选项
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  -- 准备显示内容
  local lines = {}
  local lang_list = {}

  -- 头部信息（无边框）
  table.insert(lines, string.format("Key: %s", key))
  table.insert(lines, "")
  table.insert(lines, "Shortcuts: [e]dit • [d]elete • [t]ranslate • [r]efresh • [q]uit")
  table.insert(lines, string.rep("─", 60))
  table.insert(lines, "")

  -- 按排序后的顺序异步获取所有语言的翻译
  local pending_count = #sorted_langs
  local header_lines = 5  -- 头部占用的行数

  for _, lang in ipairs(sorted_langs) do
    local json_file = languages[lang]
    table.insert(lang_list, { lang = lang, json_file = json_file, translation = nil, has_translation = false })

    translator.get_translation_async(json_file, key, function(translation, err)
      -- 找到该语言在 lang_list 中的索引
      local lang_idx = nil
      for i, item in ipairs(lang_list) do
        if item.lang == lang then
          lang_idx = i
          break
        end
      end

      if lang_idx then
        -- 更新 lang_list 中的翻译状态
        lang_list[lang_idx].translation = translation
        lang_list[lang_idx].has_translation = (translation ~= nil)

        -- 更新对应位置的行
        local line_idx = header_lines + lang_idx
        local display_text
        local is_error = false

        if translation then
          display_text = translation
          is_error = false
        elseif err and err:find("not found") then
          display_text = "[Not found]"
          is_error = true
        else
          display_text = "[Error]"
          is_error = true
        end

        -- 格式化语言代码，固定宽度
        local lang_code = string.format("%-6s", lang)
        -- 默认语言添加星号标记
        local is_default = (lang == default_lang) and "★ " or "  "

        lines[line_idx] = string.format("%s%s  %s", is_default, lang_code, display_text)

        -- 更新显示
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

          -- 添加语法高亮
          local ns_id = vim.api.nvim_create_namespace("i18n-editor-hl")
          -- 如果是默认语言，高亮星号
          if lang == default_lang then
            pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Special", line_idx - 1, 0, 2)
          end
          -- 高亮语言代码
          pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Identifier", line_idx - 1, 2, 8)
          -- 高亮翻译文本：错误时使用 Error，正常时使用默认（不高亮）
          if is_error then
            pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Error", line_idx - 1, 10, -1)
          end
        end
      end

      pending_count = pending_count - 1
    end)
  end

  -- 预先创建占位行
  for i, lang in ipairs(sorted_langs) do
    local lang_code = string.format("%-6s", lang)
    local is_default = (lang == default_lang) and "★ " or "  "
    table.insert(lines, string.format("%s%s  Loading...", is_default, lang_code))
  end

  -- 设置键盘映射
  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- 退出
  vim.keymap.set("n", "q", close_window, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close_window, { buffer = buf, nowait = true })

  -- 刷新
  vim.keymap.set("n", "r", function()
    -- 清除缓存
    translator.clear_cache()
    -- 关闭当前窗口
    close_window()
    -- 重新打开编辑器
    vim.schedule(function()
      M.open_editor(key)
    end)
  end, { buffer = buf, nowait = true })

  -- 编辑
  vim.keymap.set("n", "e", function()
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]

    -- 查找对应的语言（跳过头部的5行）
    local lang_idx = cursor_line - 5
    if lang_idx < 1 or lang_idx > #lang_list then
      vim.notify("Please select a language line to edit", vim.log.levels.WARN)
      return
    end

    local selected = lang_list[lang_idx]

    -- 获取当前翻译
    translator.get_translation_async(selected.json_file, key, function(current_translation, _)
      vim.ui.input({
        prompt = string.format("Edit translation [%s]: ", selected.lang),
        default = current_translation or "",
      }, function(input)
        if input and input ~= "" then
          -- 更新翻译
          translator.update_translation_async(selected.json_file, key, input, function(success, err)
            if success then
              vim.notify("Translation updated successfully", vim.log.levels.INFO)
              -- 刷新显示
              close_window()
              vim.schedule(function()
                M.open_editor(key)
              end)
            else
              vim.notify("Failed to update translation: " .. (err or "unknown"), vim.log.levels.ERROR)
            end
          end)
        end
      end)
    end)
  end, { buffer = buf, nowait = true })

  -- 删除（支持 normal 和 visual 模式）
  local function delete_translations()
    -- 获取选中的行范围
    local mode = vim.api.nvim_get_mode().mode
    local start_line, end_line

    if mode == "v" or mode == "V" then
      -- Visual mode：获取选中的行范围
      local start_pos = vim.fn.getpos("v")
      local end_pos = vim.fn.getpos(".")
      start_line = math.min(start_pos[2], end_pos[2])
      end_line = math.max(start_pos[2], end_pos[2])
    else
      -- Normal mode：只删除当前行
      start_line = vim.api.nvim_win_get_cursor(win)[1]
      end_line = start_line
    end

    -- 收集要删除的语言（跳过头部的5行）
    local to_delete = {}
    for line = start_line, end_line do
      local lang_idx = line - 5
      if lang_idx >= 1 and lang_idx <= #lang_list then
        table.insert(to_delete, lang_list[lang_idx])
      end
    end

    if #to_delete == 0 then
      vim.notify("Please select valid language line(s) to delete", vim.log.levels.WARN)
      return
    end

    -- 确认删除
    local lang_names = {}
    for _, item in ipairs(to_delete) do
      table.insert(lang_names, item.lang)
    end

    local prompt = string.format("Delete translation for [%s]?", table.concat(lang_names, ", "))
    vim.ui.select({ "Yes", "No" }, {
      prompt = prompt,
    }, function(choice)
      if choice == "Yes" then
        local pending_count = #to_delete
        local success_count = 0
        local error_count = 0

        for _, item in ipairs(to_delete) do
          translator.delete_translation_async(item.json_file, key, function(success, err)
            if success then
              success_count = success_count + 1
            else
              error_count = error_count + 1
              vim.notify(string.format("Failed to delete [%s]: %s", item.lang, err or "unknown"), vim.log.levels.ERROR)
            end

            pending_count = pending_count - 1
            if pending_count == 0 then
              vim.notify(string.format("Deletion complete: %d success, %d failed", success_count, error_count), vim.log.levels.INFO)
              -- 刷新显示
              close_window()
              vim.schedule(function()
                M.open_editor(key)
              end)
            end
          end)
        end
      end
    end)
  end

  vim.keymap.set("n", "d", delete_translations, { buffer = buf, nowait = true })
  vim.keymap.set("v", "d", delete_translations, { buffer = buf, nowait = true })

  -- 翻译（使用 OpenAI，支持 normal 和 visual 模式）
  local function translate_translations()
    -- 检查 OpenAI 配置
    local ok, err = openai.check_config()
    if not ok then
      vim.notify("OpenAI translation not available: " .. err, vim.log.levels.ERROR)
      return
    end

    -- 获取默认语言的翻译
    local default_lang = config.config.default_language
    local default_file = nil

    for _, item in ipairs(lang_list) do
      if item.lang == default_lang then
        default_file = item.json_file
        break
      end
    end

    if not default_file then
      vim.notify("Default language not found", vim.log.levels.ERROR)
      return
    end

    -- 获取选中的行范围
    local mode = vim.api.nvim_get_mode().mode
    local start_line, end_line

    if mode == "v" or mode == "V" then
      -- Visual mode：获取选中的行范围
      local start_pos = vim.fn.getpos("v")
      local end_pos = vim.fn.getpos(".")
      start_line = math.min(start_pos[2], end_pos[2])
      end_line = math.max(start_pos[2], end_pos[2])

      -- 计算选中的语言数量（用于提示，排除默认语言）
      local selected_count = 0
      for line = start_line, end_line do
        local lang_idx = line - 5
        if lang_idx >= 1 and lang_idx <= #lang_list then
          local item = lang_list[lang_idx]
          if item.lang ~= default_lang then
            selected_count = selected_count + 1
          end
        end
      end

      if selected_count == 0 then
        vim.notify("No target languages selected (default language excluded)", vim.log.levels.WARN)
        return
      end

      vim.notify(string.format("Translating %d selected language(s)...", selected_count), vim.log.levels.INFO)
    else
      -- Normal mode：只翻译缺失的语言（排除默认语言）
      start_line = nil
      end_line = nil

      -- 计算缺失翻译的语言数量（排除默认语言）
      local missing_count = 0
      local total_non_default = 0
      for _, item in ipairs(lang_list) do
        if item.lang ~= default_lang then
          total_non_default = total_non_default + 1
          if not item.has_translation then
            missing_count = missing_count + 1
          end
        end
      end

      if total_non_default == 0 then
        vim.notify("No target languages to translate", vim.log.levels.WARN)
        return
      end

      -- 如果所有翻译都存在，提示用户
      if missing_count == 0 then
        vim.notify("All translations are complete. Please select specific languages to re-translate.", vim.log.levels.INFO)
        return
      end

      vim.notify(string.format("Translating %d missing language(s)...", missing_count), vim.log.levels.INFO)
    end

    -- 获取默认语言的翻译文本
    translator.get_translation_async(default_file, key, function(source_text, _)
      if not source_text then
        vim.notify("Source translation not found for key: " .. key, vim.log.levels.ERROR)
        return
      end

      -- 获取需要翻译的语言
      local target_langs = {}

      if start_line and end_line then
        -- Visual mode：只翻译选中的行（跳过头部的5行）
        for line = start_line, end_line do
          local lang_idx = line - 5
          if lang_idx >= 1 and lang_idx <= #lang_list then
            local item = lang_list[lang_idx]
            if item.lang ~= default_lang then
              table.insert(target_langs, item.lang)
            end
          end
        end
      else
        -- Normal mode：只翻译缺失的语言
        for _, item in ipairs(lang_list) do
          if item.lang ~= default_lang and not item.has_translation then
            table.insert(target_langs, item.lang)
          end
        end
      end

      if #target_langs == 0 then
        vim.notify("No target languages to translate", vim.log.levels.WARN)
        return
      end

      -- 批量翻译
      local texts = { [default_lang] = source_text }
      openai.translate_batch_async(texts, default_lang, target_langs, function(results, errors)
        local success_count = 0
        local error_count = 0

        -- 更新所有翻译
        local pending_updates = #target_langs

        for _, target_lang in ipairs(target_langs) do
          local translation = results[target_lang]
          local error = errors[target_lang]

          if translation then
            -- 找到对应的 JSON 文件
            local json_file = nil
            for _, item in ipairs(lang_list) do
              if item.lang == target_lang then
                json_file = item.json_file
                break
              end
            end

            if json_file then
              translator.update_translation_async(json_file, key, translation, function(update_success, update_err)
                if update_success then
                  success_count = success_count + 1
                else
                  error_count = error_count + 1
                  vim.notify(string.format("Failed to update [%s]: %s", target_lang, update_err or "unknown"), vim.log.levels.ERROR)
                end

                pending_updates = pending_updates - 1

                if pending_updates == 0 then
                  vim.notify(string.format("Translation complete: %d success, %d failed", success_count, error_count), vim.log.levels.INFO)
                  -- 刷新显示
                  close_window()
                  vim.schedule(function()
                    M.open_editor(key)
                  end)
                end
              end)
            else
              pending_updates = pending_updates - 1
            end
          else
            error_count = error_count + 1
            vim.notify(string.format("Failed to translate [%s]: %s", target_lang, error or "unknown"), vim.log.levels.ERROR)
            pending_updates = pending_updates - 1

            if pending_updates == 0 then
              vim.notify(string.format("Translation complete: %d success, %d failed", success_count, error_count), vim.log.levels.INFO)
            end
          end
        end
      end)
    end)
  end

  vim.keymap.set("n", "t", translate_translations, { buffer = buf, nowait = true })
  vim.keymap.set("v", "t", translate_translations, { buffer = buf, nowait = true })

  -- 初始显示
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- 添加初始高亮
  local ns_id = vim.api.nvim_create_namespace("i18n-editor-hl")

  -- 高亮 Key 标签
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Title", 0, 0, 4)  -- "Key:"
  -- 高亮 Key 值
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "String", 0, 5, -1)

  -- 高亮 Shortcuts 标签
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Title", 2, 0, 10)  -- "Shortcuts:"
  -- 高亮快捷键
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Special", 2, 11, 14) -- "[e]"
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Special", 2, 19, 22) -- "[d]"
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Special", 2, 31, 34) -- "[t]"
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Special", 2, 47, 50) -- "[r]"
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Special", 2, 60, 63) -- "[q]"

  -- 高亮分隔线
  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Comment", 3, 0, -1)

  -- 高亮初始的 Loading 状态
  for i = 1, #sorted_langs do
    local line_idx = header_lines + i - 1
    -- 如果是默认语言，高亮星号
    if sorted_langs[i] == default_lang then
      pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Special", line_idx, 0, 2)
    end
    -- 高亮语言代码
    pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Identifier", line_idx, 2, 8)
    -- 高亮 Loading 文本
    pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, "Comment", line_idx, 10, -1)
  end
end

--- 转义特殊字符用于 Lua 模式匹配
--- @param str string 要转义的字符串
--- @return string 转义后的字符串
local function escape_pattern(str)
  return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

--- 从光标位置获取 i18n key
--- @return string|nil
function M.get_key_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local method_names = config.config.translation_method_names or { "t" }

  -- 遍历所有配置的翻译函数名
  for _, method_name in ipairs(method_names) do
    local escaped_name = escape_pattern(method_name)
    -- 尝试匹配 functionName("key") 或 functionName('key')
    local double_quote_pattern = escaped_name .. '%("([^"]+)"%)'
    local single_quote_pattern = escaped_name .. "%('([^']+)'%)"

    local key = line:match(double_quote_pattern) or line:match(single_quote_pattern)
    if key then
      return key
    end
  end

  return nil
end

return M
