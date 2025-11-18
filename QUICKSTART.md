# 快速开始指南

## 1. 安装依赖

```bash
# macOS
brew install ripgrep jq

# Ubuntu/Debian
sudo apt install ripgrep jq

# Arch Linux
sudo pacman -S ripgrep jq
```

## 2. 安装插件

### 使用 lazy.nvim（推荐）

```lua
-- ~/.config/nvim/lua/plugins/i18n.lua
return {
  dir = "/path/to/this/repo",  -- 本地开发时使用
  ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  config = function()
    require("i18n").setup()
  end,
}
```

### 使用 packer.nvim

```lua
use {
  "/path/to/this/repo",
  config = function()
    require("i18n").setup()
  end
}
```

## 3. 准备项目

确保你的项目有以下结构：

```
your-project/
├── package.json          # 项目根目录标记
├── i18n/
│   └── messages/
│       ├── en.json      # 英文翻译
│       ├── zh.json      # 中文翻译
│       └── ja.json      # 日文翻译
└── src/
    └── App.tsx          # 你的代码
```

## 4. 创建翻译文件

### en.json

```json
{
  "common": {
    "hello": "Hello World",
    "welcome": "Welcome"
  }
}
```

### zh.json

```json
{
  "common": {
    "hello": "你好世界",
    "welcome": "欢迎"
  }
}
```

## 5. 在代码中使用

```typescript
// src/App.tsx
function App() {
  return (
    <div>
      <h1>{t("common.hello")}</h1>
      <p>{t("common.welcome")}</p>
    </div>
  );
}
```

## 6. 打开文件查看效果

用 Neovim 打开 `src/App.tsx`：

```bash
cd your-project
nvim src/App.tsx
```

你应该会看到：

```typescript
function App() {
  return (
    <div>
      <h1>{t("common.hello")}</h1>   💬 Hello World
      <p>{t("common.welcome")}</p>   💬 Welcome
    </div>
  );
}
```

## 7. 常用命令

### 切换显示语言

```vim
:I18nSetLang zh    " 切换到中文
:I18nSetLang       " 弹出选择菜单
```

切换后会看到：

```typescript
function App() {
  return (
    <div>
      <h1>{t("common.hello")}</h1>   💬 你好世界
      <p>{t("common.welcome")}</p>   💬 欢迎
    </div>
  );
}
```

### 编辑翻译

将光标放在 `t("common.hello")` 上，执行：

```vim
:I18nEdit
```

会打开一个浮动窗口显示所有语言的翻译：

```
Key: common.hello

Press <e> to edit, <d> to delete, <q> to quit
────────────────────────────────────────────────
  [en] Hello World
  [zh] 你好世界
  [ja] こんにちは世界
```

按 `e` 可以编辑当前行的翻译。

### 切换虚拟文本

```vim
:I18nToggle    " 切换显示/隐藏虚拟文本
```

### 刷新

```vim
:I18nRefresh   " 刷新当前缓冲区的虚拟文本
```

## 8. 推荐键盘映射

```lua
-- ~/.config/nvim/lua/config/keymaps.lua
local keymap = vim.keymap.set

-- i18n 相关
keymap("n", "<leader>it", ":I18nToggle<CR>", { desc = "Toggle i18n" })
keymap("n", "<leader>ie", ":I18nEdit<CR>", { desc = "Edit i18n key" })
keymap("n", "<leader>il", ":I18nSetLang<CR>", { desc = "Set language" })
keymap("n", "<leader>ir", ":I18nRefresh<CR>", { desc = "Refresh i18n" })
```

使用：
- `<leader>it` - 切换虚拟文本
- `<leader>ie` - 编辑光标下的 key
- `<leader>il` - 切换语言
- `<leader>ir` - 刷新

## 9. 测试示例项目

我们提供了一个完整的示例项目：

```bash
cd examples/demo-project
nvim src/App.tsx
```

然后尝试各种命令！

## 10. 自定义配置

```lua
require("i18n").setup({
  -- 自定义 i18n 目录
  i18n_dir = "locales",  -- 默认是 "i18n/messages"
  
  -- 设置默认语言
  default_language = "zh",  -- 默认是 "en"
  
  -- 虚拟文本配置
  virt_text = {
    enabled = true,
    max_length = 80,        -- 增加最大长度
    prefix = " 🌍 ",        -- 使用不同的图标
    highlight = "Special",  -- 使用不同的高亮组
  },
  
  -- 支持更多文件类型
  filetypes = {
    "typescript",
    "javascript",
    "typescriptreact",
    "javascriptreact",
    "vue",  -- 添加 Vue 支持
  },
})
```

## 故障排除

### 问题：虚拟文本不显示

**解决方案：**

1. 检查依赖是否安装：
   ```bash
   which rg && which jq
   ```

2. 检查 i18n 目录是否存在：
   ```bash
   ls i18n/messages/
   ```

3. 手动测试 rg：
   ```bash
   rg 't\("' src/App.tsx
   ```

4. 手动测试 jq：
   ```bash
   jq '.common.hello' i18n/messages/en.json
   ```

5. 查看 Neovim 日志：
   ```vim
   :messages
   ```

### 问题：找不到翻译

**解决方案：**

1. 确认 JSON 文件格式正确：
   ```bash
   jq . i18n/messages/en.json
   ```

2. 确认 key 路径正确：
   ```bash
   # 如果代码中是 t("common.hello")
   # JSON 应该是:
   {
     "common": {
       "hello": "..."
     }
   }
   ```

3. 刷新缓存：
   ```vim
   :I18nRefresh
   ```

### 问题：性能问题

**解决方案：**

1. 减少显示长度：
   ```lua
   virt_text = {
     max_length = 30,  -- 减小这个值
   }
   ```

2. 只在需要时启用：
   ```vim
   :I18nToggle  " 不用时关闭
   ```

## 下一步

- 阅读完整的 [README.md](README.md)
- 查看 [examples/](examples/) 目录中的更多示例
- 根据你的需求自定义配置

享受更高效的 i18n 开发体验！🚀
