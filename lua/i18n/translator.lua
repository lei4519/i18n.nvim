--- 使用 jq 获取翻译并缓存
local M = {}

--- 翻译缓存 { [json_file][key] = value }
--- @type table<string, table<string, string>>
local cache = {}

--- 语言列表缓存 { [i18n_dir] = { [lang] = json_file_path } }
--- @type table<string, table<string, string>>
local languages_cache = {}

--- 清空缓存
function M.clear_cache()
  cache = {}
  languages_cache = {}
end

--- 清空指定文件的缓存
--- @param json_file string JSON 文件路径
function M.clear_file_cache(json_file)
  cache[json_file] = nil
end

--- 使用 jq 获取翻译（异步）
--- @param json_file string JSON 文件路径
--- @param key string i18n key (使用 . 分隔)
--- @param callback fun(translation: string|nil, error: string|nil) 回调函数
function M.get_translation_async(json_file, key, callback)
  -- 检查缓存
  if cache[json_file] and cache[json_file][key] then
    vim.schedule(function()
      callback(cache[json_file][key], nil)
    end)
    return
  end

  -- 检查文件是否存在
  if vim.fn.filereadable(json_file) == 0 then
    vim.schedule(function()
      callback(nil, "File not found: " .. json_file)
    end)
    return
  end

  -- 构建 jq 查询
  -- 例如: key = "common.hello" -> jq '.common.hello'
  local jq_query = "." .. key

  local args = {
    "jq",
    "-r", -- raw output (不包含引号)
    jq_query,
    json_file,
  }

  vim.system(args, {}, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        callback(nil, "jq error: " .. (obj.stderr or "unknown"))
        return
      end

      local translation = obj.stdout:gsub("%s+$", "") -- 去除尾部空格和换行

      -- null 表示 key 不存在
      if translation == "null" or translation == "" then
        callback(nil, "Key not found: " .. key)
        return
      end

      -- 缓存结果
      if not cache[json_file] then
        cache[json_file] = {}
      end
      cache[json_file][key] = translation

      callback(translation, nil)
    end)
  end)
end

--- 更新翻译（异步）
--- @param json_file string JSON 文件路径
--- @param key string i18n key
--- @param value string 新的翻译值
--- @param callback fun(success: boolean, error: string|nil) 回调函数
function M.update_translation_async(json_file, key, value, callback)
  -- 转义特殊字符
  local escaped_value = value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\t", "\\t")

  -- 构建 jq 更新命令
  -- 使用临时文件避免直接覆盖
  local jq_query = string.format('.%s = "%s"', key, escaped_value)

  local temp_file = json_file .. ".tmp"

  local args = {
    "jq",
    jq_query,
    json_file,
  }

  vim.system(args, {}, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        callback(false, "jq error: " .. (obj.stderr or "unknown"))
        return
      end

      -- 写入临时文件
      local f = io.open(temp_file, "w")
      if not f then
        callback(false, "Failed to create temp file")
        return
      end

      f:write(obj.stdout)
      f:close()

      -- 替换原文件
      local ok = os.rename(temp_file, json_file)
      if not ok then
        callback(false, "Failed to replace file")
        return
      end

      -- 清除该文件的缓存
      M.clear_file_cache(json_file)

      callback(true, nil)
    end)
  end)
end

--- 删除翻译（异步）
--- @param json_file string JSON 文件路径
--- @param key string i18n key
--- @param callback fun(success: boolean, error: string|nil) 回调函数
function M.delete_translation_async(json_file, key, callback)
  -- 构建 jq 删除命令
  local jq_query = string.format("del(.%s)", key)

  local temp_file = json_file .. ".tmp"

  local args = {
    "jq",
    jq_query,
    json_file,
  }

  vim.system(args, {}, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        callback(false, "jq error: " .. (obj.stderr or "unknown"))
        return
      end

      -- 写入临时文件
      local f = io.open(temp_file, "w")
      if not f then
        callback(false, "Failed to create temp file")
        return
      end

      f:write(obj.stdout)
      f:close()

      -- 替换原文件
      local ok = os.rename(temp_file, json_file)
      if not ok then
        callback(false, "Failed to replace file")
        return
      end

      -- 清除该文件的缓存
      M.clear_file_cache(json_file)

      callback(true, nil)
    end)
  end)
end

--- 获取所有可用的语言和对应的 JSON 文件（带缓存）
--- @param i18n_dir string i18n 目录路径 (例如: "i18n/messages")
--- @return table<string, string> { [lang] = json_file_path }
function M.get_available_languages(i18n_dir)
  if not i18n_dir then
    return {}
  end

  -- 检查缓存
  if languages_cache[i18n_dir] then
    return languages_cache[i18n_dir]
  end

  local result = {}

  -- 使用 glob 查找所有 JSON 文件
  local pattern = i18n_dir .. "/*.json"
  local files = vim.fn.glob(pattern, false, true)

  for _, file in ipairs(files) do
    -- 从文件名提取语言
    -- 例如: i18n/messages/en.json -> en
    local lang = vim.fn.fnamemodify(file, ":t:r")
    result[lang] = file
  end

  -- 缓存结果
  languages_cache[i18n_dir] = result

  return result
end

return M
