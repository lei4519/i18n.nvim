--- 配置管理
local M = {}

--- 默认配置
--- @class I18n.Config
--- @field enabled boolean 是否启用插件
--- @field i18n_dir string i18n 目录路径（相对于项目根目录）
--- @field default_language string 默认语言
--- @field virt_text I18n.VirtTextConfig 虚拟文本配置
--- @field auto_detect_project boolean 是否自动检测项目根目录
--- @field filetypes string[] 支持的文件类型
local default_config = {
  enabled = true,
  i18n_dir = "i18n/messages", -- 默认 i18n 目录
  default_language = "en", -- 默认语言
  virt_text = {
    enabled = true,
    max_length = 50, -- 最大显示长度，0 表示不限制
    prefix = " 💬 ", -- 前缀
    highlight = "Comment", -- 高亮组
  },
  auto_detect_project = true, -- 自动检测项目根目录
  filetypes = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
}

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

--- 获取项目根目录
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

  local root = vim.fs.root(path, markers)

  return root or vim.fn.getcwd()
end

--- 获取 i18n 目录的完整路径
--- @param bufnr number|nil 缓冲区号
--- @return string|nil
function M.get_i18n_dir(bufnr)
  local root = M.get_project_root(bufnr)
  if not root then
    return nil
  end

  return root .. "/" .. M.config.i18n_dir
end

--- 检查文件类型是否支持
--- @param filetype string 文件类型
--- @return boolean
function M.is_supported_filetype(filetype)
  return vim.tbl_contains(M.config.filetypes, filetype)
end

return M
