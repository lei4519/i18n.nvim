# 使用指南

## 🎯 快速测试

### 1. 进入示例项目

```bash
cd /workspace/examples/demo-project
```

### 2. 临时加载插件（用于测试）

在 Neovim 中执行：

```vim
:lua package.path = package.path .. ";/workspace/lua/?.lua;/workspace/lua/?/init.lua"
:lua require("i18n").setup()
```

### 3. 打开示例文件

```vim
:e src/App.tsx
```

你应该会看到类似这样的效果：

```typescript
<h1>{t("common.hello")}</h1>   💬 Hello World
<p>{t("common.welcome")}</p>   💬 Welcome to our application
```

### 4. 尝试命令

#### 切换语言到中文

```vim
:I18nSetLang zh
```

现在应该显示：

```typescript
<h1>{t("common.hello")}</h1>   💬 你好世界
<p>{t("common.welcome")}</p>   💬 欢迎使用我们的应用
```

#### 编辑翻译

将光标放在 `t("common.hello")` 上，然后：

```vim
:I18nEdit
```

会打开浮动窗口显示所有语言：

```
Key: common.hello

Press <e> to edit, <d> to delete, <q> to quit
────────────────────────────────────────────────
  [en] Hello World
  [zh] 你好世界
  [ja] こんにちは世界
```

- 按 `e` 编辑当前行
- 按 `d` 删除当前行
- 按 `q` 退出

#### 切换虚拟文本显示

```vim
:I18nToggle
```

#### 刷新

```vim
:I18nRefresh
```

## 📦 正式安装

### 使用 lazy.nvim

```lua
-- ~/.config/nvim/lua/plugins/i18n.lua
return {
  dir = "/workspace",  -- 或者你的插件路径
  ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  config = function()
    require("i18n").setup({
      i18n_dir = "i18n/messages",
      default_language = "en",
      virt_text = {
        enabled = true,
        max_length = 50,
        prefix = " 💬 ",
        highlight = "Comment",
      },
    })
    
    -- 推荐的键盘映射
    local keymap = vim.keymap.set
    keymap("n", "<leader>it", ":I18nToggle<CR>", { desc = "Toggle i18n" })
    keymap("n", "<leader>ie", ":I18nEdit<CR>", { desc = "Edit i18n" })
    keymap("n", "<leader>il", ":I18nSetLang<CR>", { desc = "Set language" })
    keymap("n", "<leader>ir", ":I18nRefresh<CR>", { desc = "Refresh i18n" })
  end,
}
```

## 🔧 配置选项

### 完整配置示例

```lua
require("i18n").setup({
  -- 是否启用插件
  enabled = true,
  
  -- i18n 目录路径（相对于项目根目录）
  i18n_dir = "i18n/messages",
  
  -- 默认显示语言
  default_language = "en",
  
  -- 虚拟文本配置
  virt_text = {
    enabled = true,         -- 是否启用虚拟文本
    max_length = 50,        -- 最大显示长度，0 表示不限制
    prefix = " 💬 ",        -- 前缀图标
    highlight = "Comment",  -- 高亮组名称
  },
  
  -- 是否自动检测项目根目录
  auto_detect_project = true,
  
  -- 支持的文件类型
  filetypes = {
    "typescript",
    "javascript",
    "typescriptreact",
    "javascriptreact",
  },
})
```

### 自定义高亮

```lua
-- 在 setup 之后设置自定义颜色
vim.api.nvim_set_hl(0, "Comment", {
  fg = "#6B7280",      -- 灰色
  italic = true,       -- 斜体
})

-- 或者创建专门的高亮组
vim.api.nvim_set_hl(0, "I18nVirtText", {
  fg = "#10B981",      -- 绿色
  italic = true,
})

-- 然后在配置中使用
require("i18n").setup({
  virt_text = {
    highlight = "I18nVirtText",
  },
})
```

## 🎹 推荐的键盘映射

### 基础映射

```lua
local keymap = vim.keymap.set

-- i18n 相关
keymap("n", "<leader>it", ":I18nToggle<CR>", { desc = "Toggle i18n virtual text" })
keymap("n", "<leader>ie", ":I18nEdit<CR>", { desc = "Edit i18n key under cursor" })
keymap("n", "<leader>il", ":I18nSetLang<CR>", { desc = "Set i18n language" })
keymap("n", "<leader>ir", ":I18nRefresh<CR>", { desc = "Refresh i18n" })
```

### 进阶映射

```lua
-- 快速切换常用语言
keymap("n", "<leader>ie", ":I18nSetLang en<CR>", { desc = "Switch to English" })
keymap("n", "<leader>iz", ":I18nSetLang zh<CR>", { desc = "Switch to Chinese" })
keymap("n", "<leader>ij", ":I18nSetLang ja<CR>", { desc = "Switch to Japanese" })

-- 在 which-key 中组织
local wk = require("which-key")
wk.register({
  ["<leader>i"] = {
    name = "i18n",
    t = { ":I18nToggle<CR>", "Toggle virtual text" },
    e = { ":I18nEdit<CR>", "Edit translation" },
    l = { ":I18nSetLang<CR>", "Set language" },
    r = { ":I18nRefresh<CR>", "Refresh" },
  },
})
```

## 🌍 项目结构要求

### 标准结构

```
your-project/
├── package.json          # 必需：用于检测项目根目录
├── i18n/
│   └── messages/         # 默认路径
│       ├── en.json      # 英文
│       ├── zh.json      # 中文
│       ├── ja.json      # 日文
│       └── ...          # 其他语言
└── src/
    └── *.tsx            # 你的代码
```

### 自定义结构

如果你的项目结构不同，可以配置 `i18n_dir`：

```lua
require("i18n").setup({
  i18n_dir = "locales",      -- 使用 locales 而不是 i18n/messages
  -- 或
  i18n_dir = "public/locales",
  -- 或
  i18n_dir = "src/locales",
})
```

## 📝 翻译文件格式

### 基本格式

```json
{
  "key": "translation",
  "nested": {
    "key": "nested translation"
  }
}
```

### 示例

```json
{
  "common": {
    "hello": "Hello World",
    "welcome": "Welcome to our app",
    "goodbye": "Goodbye"
  },
  "auth": {
    "login": "Login",
    "logout": "Logout",
    "register": "Register"
  },
  "errors": {
    "not_found": "Page not found",
    "server_error": "Internal server error"
  }
}
```

### 在代码中使用

```typescript
// 简单 key
{t("hello")}              // 对应 JSON 中的 "hello"

// 嵌套 key（使用点分隔）
{t("common.hello")}       // 对应 "common": { "hello": "..." }
{t("auth.login")}         // 对应 "auth": { "login": "..." }
{t("errors.not_found")}   // 对应 "errors": { "not_found": "..." }
```

## 🐛 故障排除

### 问题 1: 虚拟文本不显示

**检查清单：**

1. 确认依赖已安装：
   ```bash
   which rg && which jq
   ```

2. 确认文件类型正确：
   ```vim
   :set filetype?
   ```
   应该是 `typescript`, `javascript`, `typescriptreact`, 或 `javascriptreact`

3. 确认 i18n 目录存在：
   ```vim
   :lua print(require("i18n.config").get_i18n_dir())
   ```

4. 确认虚拟文本已启用：
   ```vim
   :lua print(require("i18n.config").config.virt_text.enabled)
   ```

5. 查看错误信息：
   ```vim
   :messages
   ```

### 问题 2: 找不到翻译

**检查清单：**

1. 确认 JSON 格式正确：
   ```bash
   jq . i18n/messages/en.json
   ```

2. 确认 key 路径正确：
   ```bash
   # 如果代码是 t("common.hello")
   # 检查：
   jq '.common.hello' i18n/messages/en.json
   ```

3. 手动测试 rg：
   ```bash
   cd your-project
   rg 't\("common.hello"\)' src/
   ```

### 问题 3: 编辑功能不工作

**检查清单：**

1. 确认 jq 版本：
   ```bash
   jq --version  # 应该是 1.6 或更高
   ```

2. 测试 jq 更新：
   ```bash
   jq '.common.hello = "test"' i18n/messages/en.json
   ```

3. 检查文件权限：
   ```bash
   ls -la i18n/messages/
   ```

### 问题 4: 性能问题

**优化建议：**

1. 减少最大显示长度：
   ```lua
   virt_text = {
     max_length = 30,  -- 从 50 减少到 30
   }
   ```

2. 临时关闭虚拟文本：
   ```vim
   :I18nToggle
   ```

3. 清除缓存：
   ```vim
   :I18nRefresh
   ```

## 📚 更多资源

- **完整文档**: [README.md](README.md)
- **快速开始**: [QUICKSTART.md](QUICKSTART.md)
- **技术设计**: [TECHNICAL_DESIGN.md](TECHNICAL_DESIGN.md)
- **项目总览**: [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
- **示例项目**: `examples/demo-project/`

## 💬 获取帮助

如果遇到问题：

1. 查看 `:messages` 中的错误信息
2. 阅读 [故障排除](#-故障排除) 部分
3. 查看 [TECHNICAL_DESIGN.md](TECHNICAL_DESIGN.md) 了解实现细节
4. 提交 Issue（如果插件已发布）

## 🎉 享受使用！

现在你已经掌握了所有需要知道的内容，开始享受更高效的 i18n 开发体验吧！🚀
