--- 使用纯 Lua 正则匹配解析文件中的翻译函数调用
local M = {}

--- 解析结果项
--- @class I18n.ParseResult
--- @field key string i18n key
--- @field line number 行号 (1-based)
--- @field col number 列号 (1-based)
--- @field text string 匹配的文本

--- 转义特殊字符用于 Lua 模式匹配
--- @param str string 要转义的字符串
--- @return string 转义后的字符串
local function escape_pattern(str)
  -- 转义 Lua 模式中的特殊字符
  return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

--- 根据函数名生成 Lua 匹配模式
--- @param method_name string 函数名（如 "t", "i18n.t", "$t"）
--- @return string[] 双引号和单引号的匹配模式
local function generate_patterns(method_name)
  local escaped_name = escape_pattern(method_name)
  return {
    escaped_name .. '%("([^"]+)"%)',  -- 匹配 functionName("key")
    escaped_name .. "%('([^']+)'%)",  -- 匹配 functionName('key')
  }
end

--- 使用 Lua 模式解析文本内容中的翻译函数调用
--- @param text string 文本内容
--- @param line_number number|nil 行号 (1-based)，如果为 nil 则从 1 开始
--- @return I18n.ParseResult[] 解析结果
local function parse_text_content(text, line_number)
  local config = require("i18n.config")
  local method_names = config.config.translation_method_names or { "t" }

  line_number = line_number or 1
  local results = {}

  -- 为每个配置的函数名生成匹配模式
  for _, method_name in ipairs(method_names) do
    local patterns = generate_patterns(method_name)
    
    -- 遍历每个模式（双引号和单引号）
    for _, pattern in ipairs(patterns) do
      local pos = 1
      while true do
        -- string.find 返回: start_pos, end_pos, captured_groups...
        local start_pos, end_pos, key = text:find(pattern, pos)
        if not start_pos then
          break
        end

        -- 添加结果，col 设置为右括号的位置（inline 模式会在该位置之前插入）
        table.insert(results, {
          key = key,
          line = line_number,
          col = end_pos,  -- 在 functionName("key") 的 ) 之前显示虚拟文本
          text = text:sub(start_pos, end_pos),
        })

        -- 继续从匹配结束的位置之后查找
        pos = end_pos + 1
      end
    end
  end

  return results
end

--- 解析文件或文本内容中的翻译函数调用
--- @param input string 文件路径或文本内容
--- @param opts table|nil 选项：{ is_text: boolean, line_number: number }
--- @param callback fun(results: I18n.ParseResult[]) 回调函数
function M.parse_file_async(input, opts, callback)
  -- 参数兼容处理：如果 opts 是函数，说明是旧的调用方式
  if type(opts) == "function" then
    callback = opts
    opts = { is_text = false }
  end

  opts = opts or {}
  local is_text = opts.is_text or false
  local line_number = opts.line_number or 1

  -- 如果是文本内容，直接使用 Lua 模式匹配
  if is_text then
    local results = parse_text_content(input, line_number)
    vim.schedule(function()
      callback(results)
    end)
    return
  end

  -- 否则异步读取文件内容，然后使用 Lua 模式匹配
  local filepath = input
  
  -- 使用 vim.uv 异步读取文件
  vim.uv.fs_open(filepath, "r", 438, function(err_open, fd)
    if err_open or not fd then
      vim.schedule(function()
        callback({})
      end)
      return
    end

    vim.uv.fs_fstat(fd, function(err_fstat, stat)
      if err_fstat or not stat then
        vim.uv.fs_close(fd)
        vim.schedule(function()
          callback({})
        end)
        return
      end

      vim.uv.fs_read(fd, stat.size, 0, function(err_read, data)
        vim.uv.fs_close(fd)
        
        if err_read or not data then
          vim.schedule(function()
            callback({})
          end)
          return
        end

        -- 解析文件内容
        local lines = vim.split(data, "\n", { plain = true })
        local all_results = {}

        for line_num, line_text in ipairs(lines) do
          local line_results = parse_text_content(line_text, line_num)
          for _, result in ipairs(line_results) do
            table.insert(all_results, result)
          end
        end

        vim.schedule(function()
          callback(all_results)
        end)
      end)
    end)
  end)
end

--- 解析指定行的 t() 调用（用于增量更新）
--- @param bufnr_or_filepath number|string 缓冲区号或文件路径
--- @param line_number number 行号 (1-based)
--- @param callback fun(results: I18n.ParseResult[]) 回调函数
function M.parse_line_async(bufnr_or_filepath, line_number, callback)
  local line_text

  -- 判断是缓冲区号还是文件路径
  if type(bufnr_or_filepath) == "number" then
    -- 从缓冲区读取（可以读取未保存的内容）
    local bufnr = bufnr_or_filepath
    if not vim.api.nvim_buf_is_valid(bufnr) then
      callback({})
      return
    end

    -- nvim_buf_get_lines 使用 0-based 索引，需要转换
    local lines = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)
    if #lines == 0 then
      callback({})
      return
    end
    line_text = lines[1]
  else
    -- 从文件读取（只能读取已保存的内容）
    local filepath = bufnr_or_filepath
    local lines = vim.fn.readfile(filepath, "", line_number)
    if #lines == 0 then
      callback({})
      return
    end
    line_text = lines[#lines]
  end

  -- 使用改造后的 parse_file_async 函数，传入文本内容
  M.parse_file_async(line_text, { is_text = true, line_number = line_number }, callback)
end

return M
