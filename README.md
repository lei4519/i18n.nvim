# i18n.nvim

一个简单、快速的 Neovim i18n 插件，用于展示和编辑国际化文案。

## ✨ 特性

- 🚀 **快速异步** - 使用 `rg` 和 `jq` 命令行工具，异步处理，不卡顿
- 💬 **虚拟文本** - 在代码旁边显示翻译文案
- 📝 **增量更新** - 只更新变化的行，性能优秀
- 🌍 **多语言编辑** - 可视化编辑面板，轻松管理所有语言的翻译
- 🤖 **AI 翻译** - 集成 OpenAI，自动翻译缺失的语言
- 🔍 **缺失检测** - 检查当前文件的翻译完整性
- 🎯 **灵活配置** - 支持数组、glob 模式、自定义函数匹配
- 🔧 **简单配置** - 开箱即用，配置简单
- 💾 **智能缓存** - 翻译结果缓存，减少重复查询

## 📦 安装

### 依赖

确保系统已安装以下工具：

```bash
# ripgrep
brew install ripgrep  # macOS
sudo apt install ripgrep  # Ubuntu/Debian

# jq
brew install jq  # macOS
sudo apt install jq  # Ubuntu/Debian
```

### 使用 lazy.nvim

```lua
{
  "lei4519/i18n.nvim",
  ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  keys = {
    { "<leader>it", "<cmd>I18nToggle<cr>", desc = "Toggle i18n virtual text" },
    { "<leader>ir", "<cmd>I18nRefresh<cr>", desc = "Refresh i18n virtual text" },
    { "<leader>il", "<cmd>I18nSetLang<cr>", desc = "Set i18n language" },
    { "<leader>ie", "<cmd>I18nEdit<cr>", desc = "Edit i18n key under cursor" },
    { "<leader>ic", "<cmd>I18nCheck<cr>", desc = "Check i18n translations" },
    { "<leader>iC", "<cmd>I18nClearCache<cr>", desc = "Clear i18n cache" },
  },
  config = function()
    require("i18n").setup({
      i18n_dir = "i18n/messages",  -- i18n 目录路径
      default_language = "en",      -- 默认语言
      virt_text = {
        enabled = true,
        max_length = 50,           -- 最大显示长度
        prefix = " 💬 ",           -- 前缀图标
        highlight = "Comment",     -- 高亮组
      },
    })
  end,
}
```

## 🔧 配置

### 默认配置

```lua
require("i18n").setup({
  enabled = true,                    -- 启用插件
  -- i18n 目录路径（支持字符串、数组、glob）
  -- 按顺序查找，使用第一个存在的目录
  i18n_dir = { "i18n/messages" },        -- 单个目录
  -- i18n_dir = { "i18n/messages", "locales", "translations" },  -- 多个备选目录
  -- i18n_dir = { "packages/*/i18n" },           -- glob 模式（使用第一个匹配）

  default_language = "en",           -- 默认语言

  virt_text = {
    enabled = true,                  -- 启用虚拟文本
    max_length = 50,                 -- 最大显示长度，0 表示不限制
    prefix = " 💬 ",                 -- 前缀
    highlight = "Comment",           -- 高亮组
  },

  auto_detect_project = true,        -- 自动检测项目根目录

  filetypes = {                      -- 支持的文件类型
    "typescript",
    "javascript",
    "typescriptreact",
    "javascriptreact"
  },

  -- 翻译函数调用的匹配模式（正则表达式）
  translation_patterns = {
    [[t\(["']([^"']+)["']\)]],           -- t("key")
    -- [[i18n\.t\(["']([^"']+)["']\)]],     -- i18n.t("key")
    -- [[\$t\(["']([^"']+)["']\)]],         -- $t("key") (Vue)
  },

  -- OpenAI 配置
  openai = {
    enabled = true,                       -- 是否启用 OpenAI 翻译
    api_key_env = "OPENAI_API_KEY",       -- API Key 的环境变量名
    model = "gpt-3.5-turbo",              -- 使用的模型
    api_url = "https://api.openai.com/v1/chat/completions", -- API URL
  },
})
```

## 📖 使用方法


### 翻译文件示例

```json
// i18n/messages/en.json
{
  "common": {
    "hello": "Hello World",
    "welcome": "Welcome to our app"
  },
  "errors": {
    "not_found": "Page not found"
  }
}
```

```json
// i18n/messages/zh.json
{
  "common": {
    "hello": "你好世界",
    "welcome": "欢迎使用我们的应用"
  },
  "errors": {
    "not_found": "页面未找到"
  }
}
```

### 代码中使用

```typescript
// src/app.tsx
function App() {
  return (
    <div>
      <h1>{t("common.hello")}</h1>
      <p>{t("common.welcome")}</p>
    </div>
  );
}
```

当你打开这个文件时，会在代码旁边看到翻译文案：

```typescript
function App() {
  return (
    <div>
      <h1>{t("common.hello")}</h1>  💬 Hello World
      <p>{t("common.welcome")}</p>  💬 Welcome to our app
    </div>
  );
}
```

## 🎯 命令

### `:I18nToggle`

切换虚拟文本显示（开启/关闭）。

```vim
:I18nToggle
```

### `:I18nRefresh`

刷新当前缓冲区的虚拟文本。

```vim
:I18nRefresh
```

### `:I18nSetLang [language]`

设置当前显示的语言。

```vim
:I18nSetLang zh     " 切换到中文
:I18nSetLang        " 弹出选择菜单
```

### `:I18nEdit [key]`

打开多语言编辑面板，查看和编辑所有语言的翻译。

```vim
:I18nEdit common.hello     " 编辑指定 key
:I18nEdit                  " 编辑光标下的 key
```

在编辑面板中：
- 按 `e` 编辑当前行的翻译
- 按 `d` 删除当前行的翻译
- 按 `t` 使用 OpenAI 自动翻译所有语言（需要配置 API Key）, 如果在 v 模式中选中了行，则仅翻译选中行
- 按 `q` 或 `<Esc>` 关闭面板
- 按 `r` 刷新当前面板


### `:I18nCheck`

检查当前文件中所有 key 的翻译是否完整，生成缺失报告。

```vim
:I18nCheck
```

### `:I18nClearCache`

清除所有 i18n 缓存（项目根目录、i18n 目录、翻译结果、语言列表）。

```vim
:I18nClearCache
```

## 🎨 高级用法

### 自定义高亮

```lua
-- 在 setup 之后设置
vim.api.nvim_set_hl(0, "Comment", { fg = "#6B7280", italic = true })
```

### 配置 OpenAI 翻译

1. 设置环境变量：

```bash
export OPENAI_API_KEY="your-api-key"
```

2. 或在配置中指定环境变量名：

```lua
require("i18n").setup({
  openai = {
    enabled = true,
    api_key_env = "MY_OPENAI_KEY",  -- 自定义环境变量名
    model = "gpt-4",                -- 使用 GPT-4
  },
})
```

3. 在编辑面板中按 `t` 即可自动翻译所有语言

### 多目录和 Glob 配置

插件会按照配置的顺序查找目录，使用第一个存在的目录。这样可以让同一个配置适应不同的项目结构：

```lua
require("i18n").setup({
  -- 多个备选目录（按顺序查找第一个存在的）
  i18n_dir = {
    "i18n/messages",   -- 先找这个
    "locales",         -- 没有再找这个
    "translations",    -- 还没有再找这个
  },

  -- 或使用 glob 模式（使用第一个匹配的）
  i18n_dir = {
    "packages/*/i18n",    -- 先尝试这个模式
    "apps/*/locales",     -- 没有匹配再试这个
    "src/i18n",           -- 最后的兜底选项
  },
})
```

**使用场景示例**：
- 团队使用多种项目结构，用一个配置适配所有项目
- Monorepo 中不同包可能使用不同的目录结构
- 支持旧项目和新项目的不同约定

### 自定义翻译函数匹配

```lua
require("i18n").setup({
  translation_patterns = {
    [[t\(["']([^"']+)["']\)]],              -- t("key")
    [[translate\(["']([^"']+)["']\)]],      -- translate("key")
    [[I18n\.t\(["']([^"']+)["']\)]],        -- I18n.t("key")
    [[useTranslation\(['"]([^'"]+)['"]\)]], -- useTranslation("key")
  },
})
```

## 🐛 故障排除

### 虚拟文本不显示

1. 检查 `rg` 和 `jq` 是否已安装：
   ```bash
   which rg
   which jq
   ```

2. 检查 i18n 目录路径是否正确：
   ```vim
   :lua print(require("i18n.config").get_i18n_dir())
   ```

3. 检查文件类型是否支持：
   ```vim
   :set filetype?
   ```

### 翻译查询失败

1. 验证 JSON 文件格式是否正确：
   ```bash
   jq . i18n/messages/en.json
   ```

2. 手动测试 jq 查询：
   ```bash
   jq '.common.hello' i18n/messages/en.json
   ```

## 📝 更新日志

### 当前版本

**核心功能**：
- ✅ 虚拟文本显示翻译内容
- ✅ 增量更新和智能缓存
- ✅ 多语言编辑面板（支持编辑、删除、AI 翻译）
- ✅ 切换语言和显示控制
- ✅ 翻译缺失检查报告
- ✅ 支持多个 i18n 目录和 glob 模式
- ✅ 支持自定义翻译函数匹配模式
- ✅ 集成 OpenAI 自动翻译功能
- ✅ 手动缓存管理

**暂不支持的功能**：
- ⏸️ 自动刷新（i18n 文件变化时需手动清除缓存）
- ⏸️ 实时诊断（可用 `:I18nCheck` 生成报告）
- ⏸️ 支持 nvim-cmp 和 blink.cmp 嵌套 key 的智能补全

## 📄 License

MIT

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
