# i18n.nvim

一个简单、快速的 Neovim i18n 插件，用于展示和编辑国际化文案。

## ✨ 特性

- 🚀 **快速异步** - 使用 `rg` 和 `jq` 命令行工具，异步处理，不卡顿
- 💬 **虚拟文本** - 在代码旁边显示翻译文案
- 📝 **增量更新** - 只更新变化的行，性能优秀
- 🌍 **多语言编辑** - 可视化面板，轻松管理所有语言的翻译
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
  "yourusername/i18n.nvim",
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

### 使用 packer.nvim

```lua
use {
  "yourusername/i18n.nvim",
  config = function()
    require("i18n").setup()
  end
}
```

## 🔧 配置

### 默认配置

```lua
require("i18n").setup({
  enabled = true,                    -- 启用插件
  i18n_dir = "i18n/messages",        -- i18n 目录路径（相对于项目根目录）
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
})
```

## 📖 使用方法

### 目录结构

插件期望以下目录结构：

```
your-project/
├── i18n/
│   └── messages/
│       ├── en.json
│       ├── zh.json
│       └── ja.json
└── src/
    └── app.tsx
```

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

切换虚拟文本显示。

```vim
:I18nToggle
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
- 按 `q` 或 `<Esc>` 关闭面板

### `:I18nRefresh`

刷新当前缓冲区的虚拟文本。

```vim
:I18nRefresh
```

## 🎨 高级用法

### 自定义高亮

```lua
-- 在 setup 之后设置
vim.api.nvim_set_hl(0, "Comment", { fg = "#6B7280", italic = true })
```

### 键盘映射示例

```lua
-- 快速切换虚拟文本
vim.keymap.set("n", "<leader>it", ":I18nToggle<CR>", { desc = "Toggle i18n" })

-- 快速编辑光标下的 key
vim.keymap.set("n", "<leader>ie", ":I18nEdit<CR>", { desc = "Edit i18n key" })

-- 快速切换语言
vim.keymap.set("n", "<leader>il", ":I18nSetLang<CR>", { desc = "Set i18n language" })
```

## 🔄 工作原理

1. **BufEnter**: 进入文件时，使用 `rg` 异步搜索所有 `t()` 调用
2. **翻译查询**: 对每个找到的 key，使用 `jq` 异步查询翻译文件
3. **虚拟文本**: 在代码行末显示翻译结果
4. **增量更新**: 文本变化时，只更新修改的行（带 500ms debounce）
5. **智能缓存**: 翻译结果会被缓存，i18n 文件变化时自动清除

## 🆚 与 js-i18n 对比

| 特性 | i18n.nvim | js-i18n |
|------|-----------|---------|
| 解析方式 | rg (命令行) | treesitter |
| JSON 操作 | jq (命令行) | Lua 手动解析 |
| 性能 | ⚡️ 快速 | 🐌 较慢 |
| 代码复杂度 | ✅ 简单 | ❌ 复杂 |
| LSP | ❌ 无 | ✅ 有 |
| 依赖 | rg, jq | plenary, treesitter |

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

## 📝 TODO

- [ ] 支持嵌套 key 的自动补全
- [ ] 支持多种 i18n 库（react-i18next, next-intl 等）
- [ ] 批量翻译功能
- [ ] 翻译缺失检测

## 📄 License

MIT

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
