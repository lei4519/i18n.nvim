--- blink.cmp 自动补全支持
local config = require("i18n.config")
local translator = require("i18n.translator")

local M = {}

--- 从 JSON 文件中提取所有的 keys（支持嵌套）
--- @param json_file string JSON 文件路径
--- @return string[] 所有的 keys
local function extract_all_keys(json_file)
  -- 使用 jq 提取所有的 keys
  local args = {
    "jq",
    "-r",
    ".. | select(type == \"string\") | path(.) | join(\".\")",
    json_file,
  }

  local obj = vim.system(args, {}):wait()

  if obj.code ~= 0 then
    return {}
  end

  local keys = {}
  local lines = vim.split(obj.stdout or "", "\n", { plain = true })

  for _, line in ipairs(lines) do
    if line ~= "" then
      table.insert(keys, line)
    end
  end

  return keys
end

--- 从 JSON 文件中提取所有的 keys（支持嵌套，使用递归方式）
--- @param json_file string JSON 文件路径
--- @return string[] 所有的 keys
local function extract_keys_recursive(json_file)
  -- 读取并解析 JSON 文件
  local f = io.open(json_file, "r")
  if not f then
    return {}
  end

  local content = f:read("*all")
  f:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return {}
  end

  local keys = {}

  --- 递归提取 keys
  --- @param obj table JSON 对象
  --- @param prefix string 前缀
  local function extract(obj, prefix)
    for k, v in pairs(obj) do
      local key = prefix == "" and k or (prefix .. "." .. k)
      if type(v) == "table" then
        -- 递归处理嵌套对象
        extract(v, key)
      else
        -- 叶子节点
        table.insert(keys, key)
      end
    end
  end

  extract(data, "")

  return keys
end

--- 获取所有可用的 i18n keys（用于补全）
--- @return table[] 补全项列表
function M.get_completion_items()
  local i18n_dirs = config.get_i18n_dirs()
  if #i18n_dirs == 0 then
    return {}
  end

  -- 获取所有语言
  local languages = translator.get_available_languages(i18n_dirs)
  local default_lang = config.config.default_language
  local json_file = languages[default_lang]

  if not json_file then
    -- 如果默认语言不存在，使用第一个可用语言
    for _, file in pairs(languages) do
      json_file = file
      break
    end
  end

  if not json_file then
    return {}
  end

  -- 提取所有 keys
  local keys = extract_keys_recursive(json_file)

  -- 转换为补全项格式
  local items = {}
  for _, key in ipairs(keys) do
    table.insert(items, {
      label = key,
      kind = vim.lsp.protocol.CompletionItemKind.Constant,
      detail = "i18n key",
      documentation = {
        kind = "markdown",
        value = string.format("i18n key: `%s`", key),
      },
    })
  end

  return items
end

--- 获取当前光标位置的补全上下文
--- @param line string 当前行文本
--- @param col number 当前列号 (1-based)
--- @return string|nil prefix 补全前缀
--- @return number|nil start_col 补全起始列号
local function get_completion_context(line, col)
  local patterns = config.config.translation_patterns or { [[t\(["']([^"']+)["']\)]] }

  -- 检查是否在翻译函数调用中
  for _, pattern in ipairs(patterns) do
    -- 简化的检查：查找 t(" 或 t(' 或 i18n.t(" 等
    local lua_pattern = pattern:gsub("\\%(", "%("):gsub("\\%)", "%)"):gsub("\\%[", "%["):gsub("\\%]", "%]")
    -- 提取函数名部分（如 t、i18n.t、$t）
    local func_name = pattern:match("^([^\\]+)")

    -- 查找最近的函数调用
    local before_cursor = line:sub(1, col - 1)
    local start_pos, end_pos, quote = before_cursor:match("()" .. func_name .. "%([\"']()")
    
    if start_pos then
      -- 在翻译函数调用中
      local prefix = before_cursor:sub(end_pos)
      return prefix, end_pos
    end
  end

  return nil, nil
end

--- blink.cmp 源注册
--- @return table blink.cmp 源
function M.register_blink_source()
  return {
    name = "i18n",
    module = "i18n.completion.blink",
  }
end

--- blink.cmp 源实现
M.blink = {}

--- 初始化
function M.blink.new()
  return setmetatable({}, { __index = M.blink })
end

--- 获取补全触发字符
function M.blink.get_trigger_characters()
  return { ".", '"', "'" }
end

--- 获取补全项
--- @param self table
--- @param ctx table blink.cmp 上下文
--- @param callback function 回调函数
function M.blink.get_completions(self, ctx, callback)
  -- 检查文件类型
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = ctx.bufnr })
  if not config.is_supported_filetype(filetype) then
    callback({ items = {} })
    return
  end

  -- 获取当前行
  local line = ctx.line
  local col = ctx.col

  -- 检查是否在翻译函数调用中
  local prefix, start_col = get_completion_context(line, col)
  if not prefix then
    callback({ items = {} })
    return
  end

  -- 获取补全项
  local items = M.get_completion_items()

  -- 过滤匹配的项
  local filtered = {}
  for _, item in ipairs(items) do
    if vim.startswith(item.label, prefix) then
      table.insert(filtered, item)
    end
  end

  callback({
    items = filtered,
    is_incomplete_forward = false,
    is_incomplete_backward = false,
  })
end

--- nvim-cmp 源实现
M.cmp = {}

--- 是否可用
function M.cmp.is_available()
  return config.config.enabled
end

--- 获取触发字符
function M.cmp.get_trigger_characters()
  return { ".", '"', "'" }
end

--- 补全
--- @param self table
--- @param params table nvim-cmp 参数
--- @param callback function 回调函数
function M.cmp:complete(params, callback)
  -- 检查文件类型
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = params.context.bufnr })
  if not config.is_supported_filetype(filetype) then
    callback({ items = {}, isIncomplete = false })
    return
  end

  -- 获取当前行
  local line = params.context.cursor_before_line
  local col = params.context.cursor.col

  -- 检查是否在翻译函数调用中
  local prefix, start_col = get_completion_context(line, col)
  if not prefix then
    callback({ items = {}, isIncomplete = false })
    return
  end

  -- 获取补全项
  local items = M.get_completion_items()

  -- 过滤匹配的项
  local filtered = {}
  for _, item in ipairs(items) do
    if vim.startswith(item.label, prefix) then
      table.insert(filtered, item)
    end
  end

  callback({
    items = filtered,
    isIncomplete = false,
  })
end

return M
