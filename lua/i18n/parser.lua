--- 使用 rg 解析文件中的 t() 调用
local M = {}

--- 解析结果项
--- @class I18n.ParseResult
--- @field key string i18n key
--- @field line number 行号 (1-based)
--- @field col number 列号 (1-based)
--- @field text string 匹配的文本

--- 使用 rg 解析文件中的 t() 调用
--- @param filepath string 文件路径
--- @param callback fun(results: I18n.ParseResult[]) 回调函数
function M.parse_file_async(filepath, callback)
  -- 使用 rg 搜索 t("...") 或 t('...') 模式
  -- -n: 显示行号
  -- -o: 只显示匹配的部分
  -- --column: 显示列号
  -- --json: JSON 格式输出
  local args = {
    "rg",
    "--json",
    "-n",
    "--column",
    [[t\(["']([^"']+)["']\)]],
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
            -- 从匹配文本中提取 key
            local key = match_data.lines.text:match([[t%(["']([^"']+)["']%)]])
            if key then
              table.insert(results, {
                key = key,
                line = match_data.line_number,
                col = match_data.submatches[1].start + 1, -- rg 是 0-based
                text = match_data.lines.text:gsub("^%s+", ""), -- 去除前导空格
              })
            end
          end
        end
      end

      callback(results)
    end)
  end)
end

--- 同步版本（用于测试）
--- @param filepath string 文件路径
--- @return I18n.ParseResult[]
function M.parse_file_sync(filepath)
  local args = {
    "rg",
    "--json",
    "-n",
    "--column",
    [[t\(["']([^"']+)["']\)]],
    filepath,
  }

  local obj = vim.system(args, {}):wait()

  if obj.code ~= 0 then
    if obj.code == 1 then
      return {}
    else
      return {}
    end
  end

  local results = {}
  local lines = vim.split(obj.stdout or "", "\n", { plain = true })

  for _, line in ipairs(lines) do
    if line ~= "" then
      local ok, data = pcall(vim.json.decode, line)
      if ok and data.type == "match" then
        local match_data = data.data
        local key = match_data.lines.text:match([[t%(["']([^"']+)["']%)]])
        if key then
          table.insert(results, {
            key = key,
            line = match_data.line_number,
            col = match_data.submatches[1].start + 1,
            text = match_data.lines.text:gsub("^%s+", ""),
          })
        end
      end
    end
  end

  return results
end

--- 解析指定行的 t() 调用（用于增量更新）
--- @param filepath string 文件路径
--- @param line_number number 行号 (1-based)
--- @param callback fun(results: I18n.ParseResult[]) 回调函数
function M.parse_line_async(filepath, line_number, callback)
  -- 读取指定行
  local lines = vim.fn.readfile(filepath, "", line_number)
  if #lines == 0 then
    callback({})
    return
  end

  local line_text = lines[#lines]

  -- 使用 Lua 模式匹配查找所有 t() 调用
  local results = {}
  for key in line_text:gmatch([[t%(["']([^"']+)["']%)]]) do
    local col = line_text:find([[t%(["']]] .. key:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
    table.insert(results, {
      key = key,
      line = line_number,
      col = col or 1,
      text = line_text:gsub("^%s+", ""),
    })
  end

  vim.schedule(function()
    callback(results)
  end)
end

return M
