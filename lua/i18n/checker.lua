--- 翻译缺失检测
local config = require("i18n.config")
local translator = require("i18n.translator")
local parser = require("i18n.parser")

local M = {}

--- 检测结果
--- @class I18n.CheckResult
--- @field key string i18n key
--- @field line number 行号
--- @field missing_languages string[] 缺失的语言列表

--- 检查指定文件中的翻译缺失
--- @param filepath string 文件路径
--- @param callback fun(results: I18n.CheckResult[]) 回调函数
function M.check_file_async(filepath, callback)
  local i18n_dir = config.get_i18n_dir()
  if not i18n_dir then
    vim.schedule(function()
      callback({})
    end)
    return
  end

  -- 获取所有语言
  local languages = translator.get_available_languages(i18n_dir)
  
  if vim.tbl_isempty(languages) then
    vim.schedule(function()
      callback({})
    end)
    return
  end

  -- 解析文件中的所有 t() 调用
  parser.parse_file_async(filepath, function(parse_results)
    local check_results = {}
    local pending_count = #parse_results

    if pending_count == 0 then
      callback({})
      return
    end

    -- 对每个 key 检查所有语言的翻译
    for _, result in ipairs(parse_results) do
      local key = result.key
      local missing_languages = {}
      local lang_count = 0

      for lang, json_file in pairs(languages) do
        lang_count = lang_count + 1
      end

      local checked_count = 0

      for lang, json_file in pairs(languages) do
        translator.get_translation_async(json_file, key, function(translation, err)
          if not translation or err then
            table.insert(missing_languages, lang)
          end

          checked_count = checked_count + 1

          -- 当这个 key 的所有语言都检查完成
          if checked_count == lang_count then
            if #missing_languages > 0 then
              table.insert(check_results, {
                key = key,
                line = result.line,
                missing_languages = missing_languages,
              })
            end

            pending_count = pending_count - 1

            -- 所有 key 都检查完成
            if pending_count == 0 then
              callback(check_results)
            end
          end
        end)
      end
    end
  end)
end

--- 检查默认语言的翻译缺失
--- @param filepath string 文件路径
--- @param callback fun(missing_keys: table[]) 回调函数
function M.check_default_language_async(filepath, callback)
  local i18n_dir = config.get_i18n_dir()
  if not i18n_dir then
    vim.schedule(function()
      callback({})
    end)
    return
  end

  -- 获取默认语言
  local languages = translator.get_available_languages(i18n_dir)
  local default_lang = config.config.default_language
  local json_file = languages[default_lang]

  if not json_file then
    vim.schedule(function()
      callback({})
    end)
    return
  end

  -- 解析文件中的所有 t() 调用
  parser.parse_file_async(filepath, function(parse_results)
    local missing_keys = {}
    local pending_count = #parse_results

    if pending_count == 0 then
      callback({})
      return
    end

    -- 对每个 key 检查默认语言的翻译
    for _, result in ipairs(parse_results) do
      translator.get_translation_async(json_file, result.key, function(translation, err)
        if not translation or err then
          table.insert(missing_keys, {
            key = result.key,
            line = result.line,
            col = result.col,
            text = result.text,
          })
        end

        pending_count = pending_count - 1

        if pending_count == 0 then
          callback(missing_keys)
        end
      end)
    end
  end)
end

--- 在缓冲区中显示翻译缺失的诊断信息
--- @param bufnr number 缓冲区号
function M.show_diagnostics(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    return
  end

  -- 检查默认语言的翻译缺失
  M.check_default_language_async(filepath, function(missing_keys)
    local diagnostics = {}

    for _, item in ipairs(missing_keys) do
      table.insert(diagnostics, {
        lnum = item.line - 1, -- 0-based
        col = item.col - 1,   -- 0-based
        severity = vim.diagnostic.severity.WARN,
        source = "i18n",
        message = string.format("Missing translation for key: %s", item.key),
      })
    end

    -- 设置诊断信息
    vim.diagnostic.set(vim.api.nvim_create_namespace("i18n_checker"), bufnr, diagnostics, {})
  end)
end

--- 清除缓冲区的诊断信息
--- @param bufnr number 缓冲区号
function M.clear_diagnostics(bufnr)
  vim.diagnostic.reset(vim.api.nvim_create_namespace("i18n_checker"), bufnr)
end

--- 检查所有语言的翻译缺失并生成报告
--- @param filepath string 文件路径
--- @param callback fun(report: string) 回调函数
function M.generate_report_async(filepath, callback)
  M.check_file_async(filepath, function(results)
    if #results == 0 then
      callback("All translations are complete! ✅")
      return
    end

    local lines = {}
    table.insert(lines, "Translation Missing Report")
    table.insert(lines, "=======================")
    table.insert(lines, "")

    for _, result in ipairs(results) do
      table.insert(lines, string.format("Line %d: %s", result.line, result.key))
      table.insert(lines, string.format("  Missing languages: %s", table.concat(result.missing_languages, ", ")))
      table.insert(lines, "")
    end

    callback(table.concat(lines, "\n"))
  end)
end

return M
