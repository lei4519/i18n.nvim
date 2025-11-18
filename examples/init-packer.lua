-- packer.nvim 配置示例
-- 添加到 ~/.config/nvim/lua/plugins.lua

use {
  -- 如果插件还未发布，可以使用本地路径
  "path/to/i18n.nvim", -- 本地开发路径
  -- 或者从 GitHub 安装
  -- "yourusername/i18n.nvim",
  
  ft = { "typescript", "javascript", "typescriptreact", "javascriptreact" },
  
  config = function()
    require("i18n").setup({
      i18n_dir = "i18n/messages",
      default_language = "en",
      virt_text = {
        enabled = true,
        max_length = 60,
        prefix = " 💬 ",
        highlight = "Comment",
      },
    })
    
    -- 键盘映射
    vim.keymap.set("n", "<leader>it", ":I18nToggle<CR>", { desc = "Toggle i18n" })
    vim.keymap.set("n", "<leader>ie", ":I18nEdit<CR>", { desc = "Edit i18n key" })
    vim.keymap.set("n", "<leader>il", ":I18nSetLang<CR>", { desc = "Set language" })
    vim.keymap.set("n", "<leader>ir", ":I18nRefresh<CR>", { desc = "Refresh i18n" })
  end
}
