--- 配置管理
local M = {}

--- 缓存
--- @type table<string, string> 项目根目录缓存 { [buffer_path] = root }
local project_root_cache = {}

--- @type table<string, string|nil> i18n 目录缓存 { [project_root] = i18n_dir }
local i18n_dir_cache = {}

--- 默认配置
--- @class I18n.Config
--- @field enabled boolean 是否启用插件
--- @field i18n_dir string|string[] i18n 目录路径（相对于项目根目录），支持字符串、数组和glob模式
--- @field default_language string 默认语言
--- @field virt_text I18n.VirtTextConfig 虚拟文本配置
--- @field auto_detect_project boolean 是否自动检测项目根目录
--- @field filetypes string[] 支持的文件类型
--- @field translation_patterns string[] 翻译函数调用的匹配模式（正则表达式）
--- @field openai I18n.OpenAIConfig OpenAI 配置
local default_config = {
  enabled = true,
  i18n_dir = "i18n/messages", -- 默认 i18n 目录（支持字符串、数组和glob）
  default_language = "en",    -- 默认语言
  virt_text = {
    enabled = true,
    max_length = 50, -- 最大显示长度，0 表示不限制
    prefix = " 💬 ", -- 前缀
    highlight = "Comment", -- 高亮组
  },
  auto_detect_project = true, -- 自动检测项目根目录
  filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  -- 翻译函数调用的匹配模式（rg 正则表达式）
  -- 默认匹配 t("key") 和 t('key')
  translation_patterns = {
    [[t\(["']([^"']+)["']\)]], -- t("key") 或 t('key')
    -- [[i18n\.t\(["']([^"']+)["']\)]],     -- i18n.t("key")
    -- [[\$t\(["']([^"']+)["']\)]],         -- $t("key") (Vue)
  },
  -- OpenAI 配置
  openai = {
    enabled = true,                                         -- 是否启用 OpenAI 翻译
    api_key_env = "OPENAI_API_KEY",                         -- API Key 的环境变量名
    model = "gpt-3.5-turbo",                                -- 使用的模型
    api_url = "https://api.openai.com/v1/chat/completions", -- API URL
  },
}

--- @class I18n.OpenAIConfig
--- @field enabled boolean 是否启用 OpenAI 翻译
--- @field api_key_env string API Key 的环境变量名
--- @field model string 使用的模型
--- @field api_url string API URL

--- @class I18n.VirtTextConfig
--- @field enabled boolean 是否启用虚拟文本
--- @field max_length number 最大显示长度
--- @field prefix string 前缀
--- @field highlight string 高亮组

--- 当前配置
--- @type I18n.Config
M.config = vim.deepcopy(default_config)

--- 当前语言
M.current_language = nil

--- 设置配置
--- @param user_config table 用户配置
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
  M.current_language = M.config.default_language
end

--- 获取当前语言
--- @return string
function M.get_current_language()
  return M.current_language or M.config.default_language
end

--- 设置当前语言
--- @param lang string 语言代码
function M.set_current_language(lang)
  M.current_language = lang
end

--- 获取项目根目录（带缓存）

--- @param bufnr number|nil 缓冲区号，nil 表示当前缓冲区
--- @return string|nil
function M.get_project_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not M.config.auto_detect_project then
    return vim.fn.getcwd()
  end

  -- 查找包含 package.json 或 .git 的目录
  local markers = { "package.json", ".git" }
  local path = vim.api.nvim_buf_get_name(bufnr)

  if path == "" then
    return vim.fn.getcwd()
  end

-- 检查缓存
if project_root_cache[path] then
    return project_root_cache[path]
end

  local root = vim.fs.root(path, markers)
local result = root or vim.fn.getcwd()


-- 缓存结果
project_root_cache[path] = result

return result

end

--- 获取 i18n 目录的完整路径（带缓存）

--- 按照配置的顺序依次查找，返回第一个存在的目录
--- @param bufnr number|nil 缓冲区号
--- @return string|nil 第一个匹配的目录路径
function M.get_i18n_dir(bufnr)
  local root = M.get_project_root(bufnr)
  if not root then
    return nil
  end

-- 检查缓存
if i18n_dir_cache[root] ~= nil then
    return i18n_dir_cache[root]
end

  local i18n_dir = M.config.i18n_dir

  -- 如果是字符串，直接处理
  if type(i18n_dir) == "string" then
    i18n_dir = { i18n_dir }
  end

local result = nil

  -- 按顺序查找第一个存在的目录
  for _, dir_pattern in ipairs(i18n_dir) do
    -- 如果包含 glob 模式字符，进行 glob 展开
    if dir_pattern:match("[*?%[%]]") then
      local full_pattern = root .. "/" .. dir_pattern
      local matches = vim.fn.glob(full_pattern, false, true)

      -- 返回第一个匹配的目录
      for _, match in ipairs(matches) do
        if vim.fn.isdirectory(match) == 1 then
result = match
break

        end
      end
if result then
    break
end

    else
      -- 普通路径
      local full_path = root .. "/" .. dir_pattern
      if vim.fn.isdirectory(full_path) == 1 then
result = full_path
break

      end
    end
  end

-- 缓存结果（包括 nil 值，避免重复查找）
i18n_dir_cache[root] = result

return result

end

--- 检查文件类型是否支持
--- @param filetype string 文件类型
--- @return boolean
function M.is_supported_filetype(filetype)
  return vim.tbl_contains(M.config.filetypes, filetype)
end

--- 清空所有缓存
function M.clear_all_cache()
    project_root_cache = {}
    i18n_dir_cache = {}
end

return M
