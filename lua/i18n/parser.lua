--- 使用 rg 解析文件中的 t() 调用
local M = {}

--- 解析结果项
--- @class I18n.ParseResult
--- @field key string i18n key
--- @field line number 行号 (1-based)
--- @field col number 列号 (1-based)
--- @field text string 匹配的文本

--- 使用 Lua 模式解析文本内容中的 t() 调用
--- @param text string 文本内容
--- @param line_number number|nil 行号 (1-based)，如果为 nil 则从 1 开始
--- @return I18n.ParseResult[] 解析结果
local function parse_text_content(text, line_number)
  local config = require("i18n.config")
  -- TODO: 支持多种模式
  -- local patterns = config.config.translation_patterns or { [[t\(["']([^"']+)["']\)]] }

  line_number = line_number or 1
  local results = {}

  -- 定义要匹配的模式列表
  local patterns = {
    't%("([^"]+)"%)',  -- 匹配 t("key")
    "t%('([^']+)'%)",  -- 匹配 t('key')
  }

  -- 遍历每个模式
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
        col = end_pos,  -- 在 t("key") 的 ) 之前显示虚拟文本
        text = text:sub(start_pos, end_pos),
      })

      -- 继续从匹配结束的位置之后查找
      pos = end_pos + 1
    end
  end

  return results
end

--- 解析文件或文本内容中的 t() 调用
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

  -- 否则使用 rg 解析文件
  local filepath = input
  local config = require("i18n.config")
  local patterns = config.config.translation_patterns or { [[t\(["']([^"']+)["']\)]] }

  -- 使用 rg 搜索所有配置的模式
  -- -n: 显示行号
  -- -o: 只显示匹配的部分
  -- --column: 显示列号
  -- --json: JSON 格式输出
  -- 构建多模式匹配：pattern1|pattern2|pattern3
  local combined_pattern = table.concat(patterns, "|")

  local args = {
    "rg",
    "--json",
    "-n",
    "--column",
    combined_pattern,
    filepath,
  }

  vim.system(args, {}, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        -- rg 返回 1 表示没有匹配，这是正常的
        if obj.code == 1 then
          callback({})
        else
          vim.notify("rg error: " .. (obj.stderr or "unknown"), vim.log.levels.ERROR)
          callback({})
        end
        return
      end

      local results = {}
      local lines = vim.split(obj.stdout or "", "\n", { plain = true })

      for _, line in ipairs(lines) do
        if line ~= "" then
          local ok, data = pcall(vim.json.decode, line)
          if ok and data.type == "match" then
            local match_data = data.data
            -- 尝试从匹配文本中提取 key（尝试所有模式）

            for _, submatch in ipairs(match_data.submatches) do
              local text = submatch.match.text
              -- 这里只需要从 `(` 开始，slice 掉 `("` 和 `")` 即可，因为 key 就是括号内的内容
              local paren_pos = text:find("%(")
              local key = paren_pos and text:sub(paren_pos + 2, -3) or nil

              if key then
                table.insert(results, {
                  key = key,
                  line = match_data.line_number,
                  col = submatch['end'] - 1,  -- 在 t("key") 的 ) 之前显示虚拟文本
                  text = text:gsub("^%s+", ""),  -- 去除前导空格
                })
              end
            end
          end
        end
      end

      callback(results)
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
