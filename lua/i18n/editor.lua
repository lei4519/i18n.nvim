--- 多语言编辑面板
local config = require("i18n.config")
local translator = require("i18n.translator")

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

  -- 创建浮动窗口
  local width = math.min(100, math.floor(vim.o.columns * 0.8))
  local height = math.min(20, math.floor(vim.o.lines * 0.6))

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- 创建缓冲区
  local buf = vim.api.nvim_create_buf(false, true)

  -- 创建窗口
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " I18n Editor: " .. key .. " ",
    title_pos = "center",
  })

  -- 设置缓冲区选项
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  -- 准备显示内容
  local lines = {}
  local lang_list = {}

  table.insert(lines, "Key: " .. key)
  table.insert(lines, "")
  table.insert(lines, "Press <e> to edit, <d> to delete, <q> to quit")
  table.insert(lines, string.rep("─", width - 2))

  -- 异步获取所有语言的翻译
  local pending_count = 0
  for lang, json_file in pairs(languages) do
    pending_count = pending_count + 1
    table.insert(lang_list, { lang = lang, json_file = json_file })

    translator.get_translation_async(json_file, key, function(translation, err)
      local line_idx = #lines + 1
      local display_text = translation or (err and "[Not found]" or "[Error]")

      table.insert(lines, string.format("  [%s] %s", lang, display_text))

      -- 更新显示
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
      end

      pending_count = pending_count - 1
    end)
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

  -- 编辑
  vim.keymap.set("n", "e", function()
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]

    -- 查找对应的语言
    local lang_idx = cursor_line - 4 -- 跳过前面的标题行
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

  -- 删除
  vim.keymap.set("n", "d", function()
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]

    local lang_idx = cursor_line - 4
    if lang_idx < 1 or lang_idx > #lang_list then
      vim.notify("Please select a language line to delete", vim.log.levels.WARN)
      return
    end

    local selected = lang_list[lang_idx]

    -- 确认删除
    vim.ui.select({ "Yes", "No" }, {
      prompt = string.format("Delete translation for [%s]?", selected.lang),
    }, function(choice)
      if choice == "Yes" then
        translator.delete_translation_async(selected.json_file, key, function(success, err)
          if success then
            vim.notify("Translation deleted successfully", vim.log.levels.INFO)
            -- 刷新显示
            close_window()
            vim.schedule(function()
              M.open_editor(key)
            end)
          else
            vim.notify("Failed to delete translation: " .. (err or "unknown"), vim.log.levels.ERROR)
          end
        end)
      end
    end)
  end, { buffer = buf, nowait = true })

  -- 初始显示
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

--- 从光标位置获取 i18n key
--- @return string|nil
function M.get_key_under_cursor()
  local line = vim.api.nvim_get_current_line()

  -- 尝试匹配 t("key") 或 t('key')
  local key = line:match([[t%(["']([^"']+)["']%)]]) or line:match([[t%("([^"]+)"%)]]) or line:match([[t%('([^']+)'%)]])

  return key
end

return M
