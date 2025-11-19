--- 虚拟文本管理
local config = require("i18n.config")

local M = {}

--- 命名空间 ID
local ns_id = vim.api.nvim_create_namespace("i18n-virt-text")

--- 每个 buffer 的虚拟文本记录 { [bufnr] = { [line] = { [col] = extmark_id } } }
--- @type table<number, table<number, table<number, number>>>
local buffer_extmarks = {}

--- 设置虚拟文本
--- @param bufnr number 缓冲区号
--- @param line number 行号 (1-based)
--- @param col number 列号 (1-based)
--- @param text string 显示的文本
function M.set_virt_text(bufnr, line, col, text)
  if not config.config.virt_text.enabled then
    return
  end

  -- 截断文本
  local max_length = config.config.virt_text.max_length
  if max_length > 0 and #text > max_length then
    text = text:sub(1, max_length) .. "..."
  end

  -- 转义特殊字符
  text = text:gsub("\n", "\\n"):gsub("\t", "  ")

  local virt_text = config.config.virt_text.prefix .. text
  local highlight = config.config.virt_text.highlight

  -- 删除该位置已有的虚拟文本（如果存在）
  M.clear_virt_text_at_position(bufnr, line, col)

  -- 设置新的虚拟文本（显示在指定列位置，inline 模式）
  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, col - 1, {
    virt_text = { { virt_text, highlight } },
    virt_text_pos = "inline",
    hl_mode = "combine",
  })

  -- 记录 extmark（支持同一行多个位置）
  if not buffer_extmarks[bufnr] then
    buffer_extmarks[bufnr] = {}
  end
  if not buffer_extmarks[bufnr][line] then
    buffer_extmarks[bufnr][line] = {}
  end
  buffer_extmarks[bufnr][line][col] = extmark_id
end

--- 清除指定位置的虚拟文本
--- @param bufnr number 缓冲区号
--- @param line number 行号 (1-based)
--- @param col number 列号 (1-based)
function M.clear_virt_text_at_position(bufnr, line, col)
  if buffer_extmarks[bufnr] and buffer_extmarks[bufnr][line] and buffer_extmarks[bufnr][line][col] then
    local extmark_id = buffer_extmarks[bufnr][line][col]
    pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
    buffer_extmarks[bufnr][line][col] = nil
  end
end

--- 清除指定行的虚拟文本
--- @param bufnr number 缓冲区号
--- @param line number 行号 (1-based)
function M.clear_line_virt_text(bufnr, line)
  if buffer_extmarks[bufnr] and buffer_extmarks[bufnr][line] then
    for col, extmark_id in pairs(buffer_extmarks[bufnr][line]) do
      pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
    end
    buffer_extmarks[bufnr][line] = nil
  end
end

--- 清除缓冲区所有虚拟文本
--- @param bufnr number 缓冲区号
function M.clear_buffer_virt_text(bufnr)
  if buffer_extmarks[bufnr] then
    for line, cols in pairs(buffer_extmarks[bufnr]) do
      for col, extmark_id in pairs(cols) do
        pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmark_id)
      end
    end
    buffer_extmarks[bufnr] = nil
  end
end

--- 清除所有虚拟文本
function M.clear_all_virt_text()
  for bufnr, _ in pairs(buffer_extmarks) do
    M.clear_buffer_virt_text(bufnr)
  end
end

--- 切换虚拟文本显示
function M.toggle_virt_text()
  config.config.virt_text.enabled = not config.config.virt_text.enabled

  if not config.config.virt_text.enabled then
    M.clear_all_virt_text()
  end

  return config.config.virt_text.enabled
end

--- 获取命名空间 ID
--- @return number
function M.get_namespace()
  return ns_id
end

return M
