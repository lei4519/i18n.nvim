--- OpenAI 翻译支持
local config = require("i18n.config")

local M = {}

--- 默认语言映射表（ISO 639-1 代码到全名）
local default_lang_names = {
    -- 常用语言
    en = "English",
    zh = "Chinese",
    ja = "Japanese",
    ko = "Korean",
    fr = "French",
    de = "German",
    es = "Spanish",
    it = "Italian",
    pt = "Portuguese",
    ru = "Russian",
    ar = "Arabic",
    hi = "Hindi",

    -- 欧洲语言
    nl = "Dutch",
    pl = "Polish",
    tr = "Turkish",
    sv = "Swedish",
    no = "Norwegian",
    da = "Danish",
    fi = "Finnish",
    cs = "Czech",
    hu = "Hungarian",
    ro = "Romanian",
    el = "Greek",
    bg = "Bulgarian",
    uk = "Ukrainian",
    hr = "Croatian",
    sk = "Slovak",
    sl = "Slovenian",
    lt = "Lithuanian",
    lv = "Latvian",
    et = "Estonian",

    -- 亚洲语言
    th = "Thai",
    vi = "Vietnamese",
    id = "Indonesian",
    ms = "Malay",
    tl = "Tagalog",
    bn = "Bengali",
    ta = "Tamil",
    te = "Telugu",
    ur = "Urdu",
    fa = "Persian",
    he = "Hebrew",

    -- 其他
    af = "Afrikaans",
    ca = "Catalan",
    eu = "Basque",
    gl = "Galician",
    is = "Icelandic",
    ga = "Irish",
    cy = "Welsh",
    sq = "Albanian",
    mk = "Macedonian",
    sr = "Serbian",
    bs = "Bosnian",
    mt = "Maltese",
    sw = "Swahili"
}

--- 获取 OpenAI API Key
--- @return string|nil
local function get_api_key()
  local env_name = config.config.openai.api_key_env or "OPENAI_API_KEY"
  return vim.env[env_name] or os.getenv(env_name)
end

--- 获取语言全名
--- @param lang_code string 语言代码（如 "en"）
--- @return string 语言全名
local function get_lang_name(lang_code)
    -- 如果用户配置了自定义 lang_names，使用自定义配置（支持覆盖和扩展）
    if config.config.lang_names then
        local custom_name = config.config.lang_names[lang_code]
        if custom_name then
            return custom_name
        end
    end

    -- 否则使用默认值，如果找不到则返回原始代码
    return default_lang_names[lang_code] or lang_code
end

--- 使用 OpenAI 翻译文本
--- @param text string 要翻译的文本
--- @param source_lang string 源语言（如 "en"）
--- @param target_lang string 目标语言（如 "zh"）
--- @param callback fun(translation: string|nil, error: string|nil) 回调函数
function M.translate_async(text, source_lang, target_lang, callback)
  if not config.config.openai.enabled then
    vim.schedule(function()
      callback(nil, "OpenAI translation is disabled")
    end)
    return
  end

  local api_key = get_api_key()
  if not api_key then
    vim.schedule(function()
      callback(nil, "OpenAI API key not found. Please set " .. config.config.openai.api_key_env)
    end)
    return
  end

  local api_url = config.config.openai.api_url or "https://api.openai.com/v1/chat/completions"
  local model = config.config.openai.model or "gpt-3.5-turbo"

-- 获取语言全名
local source_name = get_lang_name(source_lang)
local target_name = get_lang_name(target_lang)




  -- 构建请求
  local prompt = string.format(
    "Translate the following text from %s to %s. Only output the translated text, without any explanation:\n\n%s",
    source_name,
    target_name,
    text
  )

  local request_body = vim.json.encode({
    model = model,
    messages = {
      {
        role = "user",
        content = prompt,
      },
    },
    temperature = 0.3,
  })

  -- 使用 curl 发送请求
  local args = {
    "curl",
    "-s",
    "-X", "POST",
    api_url,
    "-H", "Content-Type: application/json",
    "-H", "Authorization: Bearer " .. api_key,
    "-d", request_body,
  }

  vim.system(args, {}, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        callback(nil, "curl error: " .. (obj.stderr or "unknown"))
        return
      end

      local ok, response = pcall(vim.json.decode, obj.stdout)
      if not ok then
        callback(nil, "Failed to parse OpenAI response: " .. tostring(response))
        return
      end

      -- 检查错误
      if response.error then
        callback(nil, "OpenAI API error: " .. (response.error.message or "unknown"))
        return
      end

      -- 提取翻译结果
      if response.choices and #response.choices > 0 then
        local translation = response.choices[1].message.content
        -- 去除首尾空格和换行
        translation = translation:gsub("^%s+", ""):gsub("%s+$", "")
        callback(translation, nil)
      else
        callback(nil, "No translation returned from OpenAI")
      end
    end)
  end)
end

--- 批量翻译多个文本
--- @param texts table<string, string> { [lang] = text }
--- @param source_lang string 源语言
--- @param target_langs string[] 目标语言列表
--- @param callback fun(results: table<string, string>, errors: table<string, string>) 回调函数
function M.translate_batch_async(texts, source_lang, target_langs, callback)
  local results = {}
  local errors = {}
  local pending_count = #target_langs

  if pending_count == 0 then
    vim.schedule(function()
      callback(results, errors)
    end)
    return
  end

  for _, target_lang in ipairs(target_langs) do
    -- 跳过源语言
    if target_lang == source_lang then
      results[target_lang] = texts[source_lang]
      pending_count = pending_count - 1




      if pending_count == 0 then
        callback(results, errors)
      end
    else
      M.translate_async(texts[source_lang], source_lang, target_lang, function(translation, err)
        if translation then
          results[target_lang] = translation
        else
          errors[target_lang] = err or "Unknown error"
        end

        pending_count = pending_count - 1

        if pending_count == 0 then
          callback(results, errors)
        end
      end)
    end
  end
end

--- 检查 OpenAI 配置是否有效
--- @return boolean, string|nil
function M.check_config()
  if not config.config.openai.enabled then
    return false, "OpenAI translation is disabled"
  end

  local api_key = get_api_key()
  if not api_key then
    return false, "OpenAI API key not found. Please set " .. config.config.openai.api_key_env
  end

  return true, nil
end

return M
