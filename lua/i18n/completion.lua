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

--- 从 JSON 文件中提取所有的 keys 和 values（支持嵌套，使用递归方式）
--- @param json_file string JSON 文件路径
--- @return table<string, string> 所有的 keys 映射到对应的 value { [key] = value }
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

  --- 递归提取 keys 和 values
  --- @param obj table JSON 对象
  --- @param prefix string 前缀
  local function extract(obj, prefix)
    for k, v in pairs(obj) do
      local key = prefix == "" and k or (prefix .. "." .. k)
      if type(v) == "table" then
        -- 递归处理嵌套对象
        extract(v, key)
      else
        -- 叶子节点，保存 key -> value 映射
        keys[key] = tostring(v)
      end
    end
  end

  extract(data, "")

  return keys
end

--- 获取所有可用的 i18n keys（用于补全）
--- @return table[] items 补全项列表
--- @return table<string, string> key_values key到value的映射
function M.get_completion_items()
  local i18n_dir = config.get_i18n_dir()
  if not i18n_dir then
    return {}, {}
  end

  -- 获取所有语言
  local languages = translator.get_available_languages(i18n_dir)
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
    return {}, {}
  end

  -- 提取所有 keys 和 values
  local key_values = extract_keys_recursive(json_file)

  -- 转换为补全项格式
  local items = {}
  for key, value in pairs(key_values) do
    -- 截断过长的值
    local display_value = value
    local max_length = config.config.virt_text.max_length or 50
    if max_length > 0 and #display_value > max_length then
      display_value = display_value:sub(1, max_length) .. "..."
    end

    table.insert(items, {
      label = key,
      insertText = key,                -- 插入 key
      filterText = key,                -- 使用 key 进行过滤
      kind = vim.lsp.protocol.CompletionItemKind.Constant,
      detail = key,                    -- 详细信息显示 key
      documentation = {
        kind = "markdown",
        value = string.format("**Key:** `%s`\n\n**Value:** %s", key, value),
      },
    })
  end

  return items, key_values
end

--- 转义特殊字符用于 Lua 模式匹配
--- @param str string 要转义的字符串
--- @return string 转义后的字符串
local function escape_pattern(str)
  -- 转义 Lua 模式中的特殊字符
  return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

--- 获取当前光标位置的补全上下文
--- @param line string 当前行文本
--- @param col number 当前列号 (1-based)
--- @return string|nil prefix 补全前缀
--- @return number|nil start_col 补全起始列号
local function get_completion_context(line, col)
  local method_names = config.config.translation_method_names or { "t" }
  local before_cursor = line:sub(1, col - 1)

  -- 检查是否在翻译函数调用中
  for _, method_name in ipairs(method_names) do
    local escaped_name = escape_pattern(method_name)

    -- 尝试匹配双引号和单引号两种情况
    -- 匹配 functionName(" 或 functionName('
    for _, quote_pattern in ipairs({ '("', "('" }) do
      local pattern = escaped_name .. quote_pattern:gsub("([%(%)%'%\"])", "%%%1")
      local start_pos, end_pos = before_cursor:find(pattern)

      -- 查找最后一个匹配（最接近光标的）
      while start_pos do
        local next_start, next_end = before_cursor:find(pattern, end_pos + 1)
        if not next_start then
          break
        end
        start_pos, end_pos = next_start, next_end
      end

      if start_pos then
        -- 检查是否已经闭合（包含了右引号和右括号）
        local after_match = before_cursor:sub(end_pos + 1)
        local quote_char = quote_pattern:sub(2, 2) -- " 或 '
        local has_closing = after_match:match(quote_char .. "%)") ~= nil

        if not has_closing then
          -- 在翻译函数调用中，且尚未闭合
          local prefix = after_match
          return prefix, end_pos + 1
        end
      end
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

  -- 获取补全项和 key-value 映射
  local items, key_values = M.get_completion_items()

  -- 根据前缀过滤并提取下一级字段
  local filtered = {}
  local seen = {}  -- 用于去重

  for _, item in ipairs(items) do
    local key = item.filterText or item.label

    -- 检查是否匹配前缀
    if vim.startswith(key, prefix) then
      local remainder = key:sub(#prefix + 1)  -- 去掉前缀部分

      -- 提取下一级字段（第一个点之前的部分，或者全部如果没有点）
      local next_level = remainder:match("^([^.]+)")

      if next_level and not seen[next_level] then
        seen[next_level] = true

        -- 构建完整的 key
        local full_key = prefix .. next_level

        -- 检查是否是叶子节点（直接从 key_values 查找）
        local leaf_value = key_values[full_key]
        local is_leaf = leaf_value ~= nil

        -- 截断过长的值
        local display_value = leaf_value
        if display_value then
          local max_length = config.config.virt_text.max_length or 50
          if max_length > 0 and #display_value > max_length then
            display_value = display_value:sub(1, max_length) .. "..."
          end
        end

        table.insert(filtered, {
          label = next_level,           -- 只显示下一级字段名
          insertText = full_key,         -- 插入完整路径
          filterText = full_key,         -- 使用完整路径过滤
          kind = is_leaf and vim.lsp.protocol.CompletionItemKind.Constant
                          or vim.lsp.protocol.CompletionItemKind.Module,
          detail = is_leaf and display_value or (full_key .. ".*"),  -- 叶子节点显示值，否则显示有子项
          documentation = is_leaf and {
            kind = "markdown",
            value = string.format("**Key:** `%s`\n\n**Value:** %s", full_key, leaf_value),
          } or {
            kind = "markdown",
            value = string.format("**Key:** `%s`\n\n*Has nested keys*", full_key),
          },
        })
      end
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

  -- 获取补全项和 key-value 映射
  local items, key_values = M.get_completion_items()

  -- 根据前缀过滤并提取下一级字段
  local filtered = {}
  local seen = {}  -- 用于去重

  for _, item in ipairs(items) do
    local key = item.filterText or item.label

    -- 检查是否匹配前缀
    if vim.startswith(key, prefix) then
      local remainder = key:sub(#prefix + 1)  -- 去掉前缀部分

      -- 提取下一级字段（第一个点之前的部分，或者全部如果没有点）
      local next_level = remainder:match("^([^.]+)")

      if next_level and not seen[next_level] then
        seen[next_level] = true

        -- 构建完整的 key
        local full_key = prefix .. next_level

        -- 检查是否是叶子节点（直接从 key_values 查找）
        local leaf_value = key_values[full_key]
        local is_leaf = leaf_value ~= nil

        -- 截断过长的值
        local display_value = leaf_value
        if display_value then
          local max_length = config.config.virt_text.max_length or 50
          if max_length > 0 and #display_value > max_length then
            display_value = display_value:sub(1, max_length) .. "..."
          end
        end

        table.insert(filtered, {
          label = next_level,           -- 只显示下一级字段名
          insertText = full_key,         -- 插入完整路径
          filterText = full_key,         -- 使用完整路径过滤
          kind = is_leaf and vim.lsp.protocol.CompletionItemKind.Constant
                          or vim.lsp.protocol.CompletionItemKind.Module,
          detail = is_leaf and display_value or (full_key .. ".*"),  -- 叶子节点显示值，否则显示有子项
          documentation = is_leaf and {
            kind = "markdown",
            value = string.format("**Key:** `%s`\n\n**Value:** %s", full_key, leaf_value),
          } or {
            kind = "markdown",
            value = string.format("**Key:** `%s`\n\n*Has nested keys*", full_key),
          },
        })
      end
    end
  end

  callback({
    items = filtered,
    isIncomplete = false,
  })
end

return M
