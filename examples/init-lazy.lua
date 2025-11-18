-- lazy.nvim 配置示例
-- 放在 ~/.config/nvim/lua/plugins/i18n.lua

return {
  -- 如果插件还未发布，可以使用本地路径
  dir = "path/to/i18n.nvim", -- 本地开发路径
  -- 或者从 GitHub 安装
  -- "yourusername/i18n.nvim",
  
  -- 只在 TypeScript/JavaScript 文件中加载
  ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  
  config = function()
    require("i18n").setup({
      -- i18n 目录路径（相对于项目根目录）
      i18n_dir = "i18n/messages",
      
      -- 默认语言
      default_language = "en",
      
      -- 虚拟文本配置
      virt_text = {
        enabled = true,           -- 启用虚拟文本
        max_length = 60,          -- 最大显示长度
        prefix = " 💬 ",          -- 前缀图标
        highlight = "Comment",    -- 高亮组
      },
      
      -- 自动检测项目根目录
      auto_detect_project = true,
      
      -- 支持的文件类型
      filetypes = {
        "typescript",
        "javascript",
        "typescriptreact",
        "javascriptreact",
      },
    })
    
    -- 可选：设置键盘映射
    local keymap = vim.keymap.set
    keymap("n", "<leader>it", ":I18nToggle<CR>", { desc = "Toggle i18n virtual text" })
    keymap("n", "<leader>ie", ":I18nEdit<CR>", { desc = "Edit i18n key under cursor" })
    keymap("n", "<leader>il", ":I18nSetLang<CR>", { desc = "Set i18n language" })
    keymap("n", "<leader>ir", ":I18nRefresh<CR>", { desc = "Refresh i18n virtual text" })
  end,
}
