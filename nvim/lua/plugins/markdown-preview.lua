return {
  "markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  ft = "markdown",
  build = function()
    vim.fn["mkdp#util#install"]()
  end,
  after = function()
    vim.g.mkdp_filetypes = { "markdown" }
  end,
}
