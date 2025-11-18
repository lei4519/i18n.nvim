# 技术设计文档

## 概述

本文档详细说明 i18n.nvim 插件的技术实现方案、设计决策和优化策略。

## 设计目标

1. **简单** - 代码简洁，易于理解和维护
2. **快速** - 异步操作，无卡顿
3. **可靠** - 错误处理完善，不影响编辑体验
4. **实用** - 功能完整，满足日常开发需求

## 架构设计

### 模块划分

```
lua/i18n/
├── init.lua          # 插件入口，整合所有模块
├── config.lua        # 配置管理
├── parser.lua        # 代码解析（使用 rg）
├── translator.lua    # 翻译查询（使用 jq）
├── virt_text.lua     # 虚拟文本管理
└── editor.lua        # 多语言编辑面板
```

### 数据流

```
用户打开文件
    ↓
BufEnter 事件触发
    ↓
parser.parse_file_async()  ←→  rg 命令异步执行
    ↓
获取所有 t() 调用的位置和 key
    ↓
对每个 key 调用 translator.get_translation_async()  ←→  jq 命令异步执行
    ↓
virt_text.set_virt_text() 显示翻译
```

## 核心实现

### 1. 代码解析 (parser.lua)

#### 为什么使用 rg 而不是 treesitter？

**treesitter 的问题：**
- 需要编译和维护查询文件（.scm）
- 处理复杂的作用域和上下文
- 需要处理各种边界情况
- 代码复杂度高

**rg 的优势：**
- 简单的正则表达式即可
- 极快的搜索速度（Rust 实现）
- JSON 输出易于解析
- 已经在大多数开发环境中安装

#### 实现细节

```lua
-- 使用 rg 的 JSON 输出模式
local args = {
  "rg",
  "--json",              -- JSON 格式输出
  "-n",                  -- 显示行号
  "--column",            -- 显示列号
  [[t\(["']([^"']+)["']\)]],  -- 匹配 t("key") 或 t('key')
  filepath,
}

-- 异步执行
vim.system(args, {}, function(obj)
  -- 解析 JSON 输出
  -- 提取 key, line, col 信息
end)
```

#### 性能优化

1. **异步执行** - 使用 `vim.system()` 异步执行，不阻塞主线程
2. **增量更新** - 文本变化时只解析变化的行
3. **Debounce** - 使用 500ms 延迟，避免频繁更新

### 2. 翻译查询 (translator.lua)

#### 为什么使用 jq 而不是 Lua JSON 解析？

**Lua JSON 解析的问题：**
- 需要读取整个文件到内存
- 手动遍历嵌套对象
- 更新时需要重新序列化整个文件

**jq 的优势：**
- 专门为 JSON 操作设计
- 支持复杂的查询和更新
- 只输出需要的部分
- 原子性更新

#### 实现细节

**查询翻译：**

```lua
-- 查询 common.hello
jq -r '.common.hello' i18n/messages/en.json

-- 输出: Hello World
```

**更新翻译：**

```lua
-- 更新 common.hello
jq '.common.hello = "New Value"' file.json > file.json.tmp
mv file.json.tmp file.json
```

**删除翻译：**

```lua
-- 删除 common.hello
jq 'del(.common.hello)' file.json > file.json.tmp
mv file.json.tmp file.json
```

#### 缓存机制

```lua
-- 两级缓存结构
cache = {
  ["path/to/en.json"] = {
    ["common.hello"] = "Hello World",
    ["common.welcome"] = "Welcome",
  },
  ["path/to/zh.json"] = {
    ["common.hello"] = "你好世界",
  }
}
```

**缓存策略：**
- 首次查询时缓存结果
- i18n 文件变化时清除对应缓存
- 手动刷新时清除所有缓存

### 3. 虚拟文本管理 (virt_text.lua)

#### 实现策略

```lua
-- 使用 extmark API
vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
  virt_text = { { text, highlight } },
  virt_text_pos = "eol",  -- 显示在行尾
  hl_mode = "combine",
})
```

#### 管理策略

```lua
-- 记录每个 buffer 的 extmark
buffer_extmarks = {
  [bufnr] = {
    [line] = extmark_id,
  }
}

-- 清除时使用记录的 ID
vim.api.nvim_buf_del_extmark(bufnr, ns_id, extmark_id)
```

### 4. 多语言编辑器 (editor.lua)

#### 浮动窗口设计

```lua
-- 创建居中的浮动窗口
local width = math.min(100, math.floor(vim.o.columns * 0.8))
local height = math.min(20, math.floor(vim.o.lines * 0.6))

vim.api.nvim_open_win(buf, true, {
  relative = "editor",
  width = width,
  height = height,
  row = (vim.o.lines - height) / 2,
  col = (vim.o.columns - width) / 2,
  style = "minimal",
  border = "rounded",
  title = " I18n Editor: " .. key .. " ",
})
```

#### 交互设计

- `e` - 编辑：使用 `vim.ui.input` 获取新值
- `d` - 删除：使用 `vim.ui.select` 确认
- `q`/`<Esc>` - 退出

## 性能优化

### 1. 异步操作

所有耗时操作都使用异步 API：

```lua
-- ❌ 同步（会卡顿）
local output = vim.fn.system("rg ...")

-- ✅ 异步（不卡顿）
vim.system({"rg", "..."}, {}, function(obj)
  -- 处理结果
end)
```

### 2. 增量更新

```lua
-- BufEnter: 完整更新
update_buffer_full(bufnr)

-- TextChanged: 只更新变化的行
update_buffer_incremental(bufnr, line_start, line_end)
```

### 3. Debounce

```lua
-- 避免频繁更新
local timer = vim.uv.new_timer()
timer:start(500, 0, vim.schedule_wrap(process_pending_updates))
```

### 4. 缓存

```lua
-- 翻译结果缓存，避免重复查询
if cache[json_file] and cache[json_file][key] then
  return cache[json_file][key]
end
```

## 错误处理

### 1. 依赖检查

```lua
-- 检查 rg 和 jq 是否可用
if vim.fn.executable("rg") == 0 then
  vim.notify("rg not found", vim.log.levels.ERROR)
  return
end
```

### 2. 文件检查

```lua
-- 检查文件是否存在
if vim.fn.filereadable(json_file) == 0 then
  callback(nil, "File not found")
  return
end
```

### 3. 命令执行错误

```lua
vim.system(args, {}, function(obj)
  if obj.code ~= 0 then
    if obj.code == 1 then
      -- rg 返回 1 表示没有匹配，这是正常的
      callback({})
    else
      vim.notify("rg error: " .. obj.stderr, vim.log.levels.ERROR)
      callback({})
    end
  end
end)
```

## 与 js-i18n 的对比

| 方面 | i18n.nvim | js-i18n |
|------|-----------|---------|
| **代码解析** | rg (正则表达式) | treesitter (语法树) |
| **代码行数** | ~500 行 | ~2000+ 行 |
| **复杂度** | 简单 | 复杂 |
| **性能** | 快速（命令行工具） | 较慢（Lua 处理） |
| **依赖** | rg, jq | plenary, treesitter |
| **维护成本** | 低 | 高 |
| **功能完整性** | 基本功能完整 | 功能更丰富（LSP 等） |

## 可扩展性

### 1. 支持更多 i18n 库

目前支持简单的 `t("key")` 模式，可以扩展正则表达式支持：

```lua
-- react-i18next
[[t\(["']([^"']+)["']\)]]

-- vue-i18n
[[\$t\(["']([^"']+)["']\)]]

-- i18next
[[i18next\.t\(["']([^"']+)["']\)]]
```

### 2. 支持嵌套 key

```lua
-- 当前支持: t("common.hello")
-- 可扩展支持: t("common." + dynamicKey)
```

### 3. 支持多种文件格式

```lua
-- 当前支持: JSON
-- 可扩展支持: YAML, TOML, JS
```

## 测试策略

### 1. 单元测试

```lua
-- 测试 parser
local results = parser.parse_file_sync("test.tsx")
assert(#results > 0)
assert(results[1].key == "common.hello")

-- 测试 translator
local translation, err = translator.get_translation_sync(
  "test.json",
  "common.hello"
)
assert(translation == "Hello World")
```

### 2. 集成测试

```bash
# 在示例项目中测试
cd examples/demo-project
nvim src/App.tsx

# 验证虚拟文本是否显示
# 测试各种命令
:I18nSetLang zh
:I18nEdit common.hello
```

## 未来改进

### 短期

- [ ] 添加单元测试
- [ ] 支持更多 i18n 库的模式
- [ ] 改进错误提示

### 中期

- [ ] 支持嵌套 key 补全
- [ ] 翻译缺失检测
- [ ] 批量翻译功能

### 长期

- [ ] 简化版 LSP（可选）
- [ ] 翻译建议
- [ ] AI 辅助翻译

## 总结

通过使用 `rg` 和 `jq` 这两个强大的命令行工具，我们实现了一个简单、快速、可靠的 i18n 插件。相比使用 treesitter 和手动 JSON 解析的方案，我们的实现：

1. **代码更简洁** - 核心代码约 500 行，易于理解和维护
2. **性能更好** - 异步操作，无卡顿
3. **依赖更少** - 只需要两个常见工具
4. **功能完整** - 满足日常开发的所有需求

这种"站在巨人肩膀上"的设计理念，让我们能够用最少的代码实现最好的效果。
