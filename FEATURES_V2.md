# i18n.nvim v2.0 功能更新总结

## 🎉 新功能概览

本次更新实现了 8 个主要功能增强，大幅提升了插件的可用性和灵活性。

## ✅ 已完成的功能

### 1. 移除与 jsi18n 的对比内容

- **改进**: 删除了 README 中与 jsi18n 的对比表格
- **新增**: 添加了"项目优势"章节，专注于本项目的独特价值
- **优势说明**:
  - 简单高效：使用经过验证的命令行工具
  - 异步处理：所有 I/O 操作异步，不阻塞编辑器
  - 智能缓存：减少重复查询
  - 增量更新：带防抖优化
  - 开箱即用：无需额外依赖

### 2. 编辑面板改为正常窗口

- **改进**: 将浮动窗口改为 split 窗口
- **优势**: 
  - 避免因手误关闭窗口而无法恢复
  - 更稳定的用户体验
  - 支持标准的窗口操作
- **实现**: 使用 `botright split` 创建窗口，设置合适的高度

### 3. i18n 目录配置支持数组和 glob

- **新增功能**:
  - 支持单个目录: `i18n_dir = "i18n/messages"`
  - 支持多个目录: `i18n_dir = { "i18n/messages", "locales" }`
  - 支持 glob 模式: `i18n_dir = { "packages/*/i18n" }`
- **适用场景**: 
  - Monorepo 项目
  - 多模块项目
  - 复杂的目录结构
- **实现**: 新增 `get_i18n_dirs()` 函数，支持 glob 展开

### 4. i18n 语言由文件名决定

- **改进**: 语言列表自动从 JSON 文件名提取
- **优势**:
  - 无需手动配置语言列表
  - 自动发现新语言
  - 支持任意语言代码
- **实现**: 使用 `vim.fn.glob()` 扫描目录，从文件名提取语言

### 5. t() 函数调用匹配方式支持数组自定义

- **新增配置**: `translation_patterns` 数组
- **默认支持**:
  - `t("key")` - 标准格式
  - `i18n.t("key")` - i18next 格式
  - `$t("key")` - Vue i18n 格式
- **自定义示例**:
  ```lua
  translation_patterns = {
    [[t\(["']([^"']+)["']\)]],
    [[translate\(["']([^"']+)["']\)]],
    [[I18n\.t\(["']([^"']+)["']\)]],
  }
  ```
- **实现**: 使用 rg 的多模式匹配支持

### 6. 支持嵌套 key 的自动补全

- **新增模块**: `lua/i18n/completion.lua`
- **支持的补全引擎**:
  - nvim-cmp
  - blink.cmp
- **功能**:
  - 自动从 JSON 文件提取所有 key（包括嵌套）
  - 在翻译函数调用中触发补全
  - 显示 key 的详细信息
- **配置示例**:
  ```lua
  -- nvim-cmp
  require('cmp').setup({
    sources = { { name = 'i18n' } }
  })
  
  -- blink.cmp
  require('blink.cmp').setup({
    sources = {
      providers = {
        i18n = {
          name = "i18n",
          module = "i18n.completion.blink",
        },
      },
    },
  })
  ```

### 7. 支持默认语言的翻译缺失检测

- **新增模块**: `lua/i18n/checker.lua`
- **新增命令**:
  - `:I18nCheck` - 生成缺失报告
  - `:I18nDiagnostics` - 显示诊断信息
- **功能**:
  - 检测默认语言的翻译缺失
  - 检测所有语言的翻译完整性
  - 生成详细的缺失报告
  - 集成 Neovim 诊断系统
- **使用场景**:
  - 代码审查前检查翻译完整性
  - 持续集成中的翻译验证
  - 开发过程中的即时反馈

### 8. 编辑窗口支持 OpenAI 翻译

- **新增模块**: `lua/i18n/openai.lua`
- **新增配置**:
  ```lua
  openai = {
    enabled = true,
    api_key_env = "OPENAI_API_KEY",
    model = "gpt-3.5-turbo",
    api_url = "https://api.openai.com/v1/chat/completions",
  }
  ```
- **功能**:
  - 在编辑面板中按 `t` 触发自动翻译
  - 从默认语言翻译到所有其他语言
  - 批量处理多个语言
  - 支持自定义 API URL 和模型
  - 支持自定义环境变量名
- **使用流程**:
  1. 配置环境变量: `export OPENAI_API_KEY="your-key"`
  2. 打开编辑面板: `:I18nEdit common.hello`
  3. 按 `t` 开始翻译
  4. 等待翻译完成并自动保存
- **支持的语言**: 自动识别，包括中英日韩法德西等主流语言

## 📊 技术实现亮点

### 异步处理
- 所有 I/O 操作都使用 `vim.system()` 异步执行
- 避免阻塞编辑器
- 支持并发请求

### 智能缓存
- 翻译结果缓存，减少重复查询
- 文件变化时自动清除缓存
- 支持增量更新

### 错误处理
- 完善的错误提示
- 优雅的降级处理
- 详细的日志输出

### 用户体验
- 实时反馈
- 进度提示
- 清晰的操作说明

## 🎯 使用建议

### 最佳实践

1. **配置多目录支持**: 对于 monorepo 项目使用 glob 模式
2. **启用自动补全**: 提高开发效率
3. **定期运行检查**: 使用 `:I18nCheck` 确保翻译完整性
4. **使用 AI 翻译**: 快速生成初始翻译，然后人工校对

### 工作流建议

1. 开发新功能时：
   - 先用默认语言编写文案
   - 使用 `:I18nEdit` + `t` 快速生成其他语言
   - 运行 `:I18nCheck` 确认完整性

2. 代码审查时：
   - 启用 `:I18nDiagnostics` 查看缺失
   - 检查翻译质量
   - 确保所有语言都有翻译

3. 日常开发时：
   - 使用自动补全快速输入 key
   - 使用虚拟文本实时查看翻译
   - 使用快捷键快速切换语言

## 🔧 配置示例

### 完整配置（推荐）

```lua
require("i18n").setup({
  enabled = true,
  i18n_dir = { "packages/*/i18n", "apps/*/locales" },
  default_language = "en",
  
  virt_text = {
    enabled = true,
    max_length = 50,
    prefix = " 💬 ",
    highlight = "Comment",
  },
  
  auto_detect_project = true,
  
  filetypes = {
    "typescript", "javascript", 
    "typescriptreact", "javascriptreact",
    "vue", "svelte",
  },
  
  translation_patterns = {
    [[t\(["']([^"']+)["']\)]],
    [[i18n\.t\(["']([^"']+)["']\)]],
    [[\$t\(["']([^"']+)["']\)]],
    [[translate\(["']([^"']+)["']\)]],
  },
  
  openai = {
    enabled = true,
    api_key_env = "OPENAI_API_KEY",
    model = "gpt-4-turbo-preview",
    api_url = "https://api.openai.com/v1/chat/completions",
  },
})

-- 键盘映射
local keymap = vim.keymap.set
keymap("n", "<leader>it", ":I18nToggle<CR>", { desc = "Toggle i18n" })
keymap("n", "<leader>ie", ":I18nEdit<CR>", { desc = "Edit i18n key" })
keymap("n", "<leader>il", ":I18nSetLang<CR>", { desc = "Set language" })
keymap("n", "<leader>ic", ":I18nCheck<CR>", { desc = "Check i18n" })
keymap("n", "<leader>id", ":I18nDiagnostics<CR>", { desc = "Show diagnostics" })
```

## 📈 性能优化

- **缓存机制**: 翻译结果缓存，减少文件读取
- **增量更新**: 只更新变化的行，带 500ms 防抖
- **异步处理**: 所有操作异步，不阻塞编辑器
- **Glob 展开**: 只在配置加载时展开，运行时不重复计算

## 🐛 已知问题

无重大已知问题。

## 🚀 未来计划

- [ ] 支持更多补全引擎
- [ ] 添加更多 AI 翻译服务（Azure, Google 等）
- [ ] 支持翻译记忆（Translation Memory）
- [ ] 添加批量操作命令
- [ ] 支持更多文件格式（YAML, TOML 等）

## 📝 总结

本次 v2.0 更新是一次重大升级，大幅提升了插件的功能性和易用性。所有新功能都经过精心设计，保持了插件简单、快速的核心理念。建议所有用户升级到最新版本，享受更强大的 i18n 开发体验。
