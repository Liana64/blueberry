-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Leader key (before lazy)
vim.g.mapleader = " "

-- Options
local opt = vim.opt
opt.relativenumber = true
opt.number = true
opt.expandtab = true
opt.autoindent = true
opt.wrap = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.ignorecase = true
opt.smartcase = true
opt.cursorline = true
opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"
opt.backspace = "indent,eol,start"
opt.clipboard:append("unnamedplus")
opt.splitright = true
opt.splitbelow = true
opt.mousescroll = "ver:10,hor:6"
opt.undofile = true
opt.undodir = vim.fn.stdpath("data") .. "/undo"

-- Plugins
require("lazy").setup({
  -- Colorscheme
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        contrast = "hard",
        italic = { strings = false, comments = true },
      })
      vim.cmd.colorscheme("gruvbox")
    end,
  },

  -- Snacks (file explorer, picker, notifications, etc.)
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    config = function()
      local Snacks = require("snacks")
      vim.cmd("let g:loaded_netrw = 1")
      Snacks.setup({
        indent = { enabled = true, char = "┊", scope = { enabled = true }, animate = { enabled = false } },
        notifier = { enabled = true, timeout = 3000 },
        words = { enabled = true, debounce = 200 },
        bigfile = { enabled = true, size = 1024 * 1024 },
        picker = {
          enabled = true,
          sources = {
            files = { cmd = "fd", args = { "--type", "f", "--hidden", "--exclude", ".git" } },
            grep = { cmd = "rg", args = { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case", "--hidden", "--glob", "!.git" } },
            explorer = { win = { list = { wo = { number = true, relativenumber = true } } }, auto_close = false, jump = { close = false } },
          },
        },
        zen = { enabled = true, toggles = { dim = false, git_sign = true, diagnostics = true } },
        terminal = { enabled = true, win = { position = "float" } },
        dim = { enabled = false },
        input = { enabled = true },
        select = { enabled = true },
        quickfile = { enabled = false },
        lazygit = { enabled = true },
        git = { enabled = true },
        scroll = { enabled = true },
        statuscolumn = { enabled = true },
        bufdelete = { enabled = true },
        image = { enabled = true },
        layout = { enabled = true },
        notify = { enabled = true },
        rename = { enabled = true },
        scope = { enabled = true },
        scratch = { enabled = true },
        toggle = { enabled = true },
        win = { enabled = true },
      })
    end,
  },

  -- Git signs
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
          end
          map("n", "]h", gs.next_hunk, "Next Hunk")
          map("n", "[h", gs.prev_hunk, "Prev Hunk")
          map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
          map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
          map("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage hunk")
          map("v", "<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset hunk")
          map("n", "<leader>hS", gs.stage_buffer, "Stage buffer")
          map("n", "<leader>hR", gs.reset_buffer, "Reset buffer")
          map("n", "<leader>hu", gs.undo_stage_hunk, "Undo stage hunk")
          map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
          map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
          map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle line blame")
          map("n", "<leader>hd", gs.diffthis, "Diff this")
          map("n", "<leader>hD", function() gs.diffthis("~") end, "Diff this ~")
          map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Gitsigns select hunk")
        end,
      })
    end,
  },

  -- LSP
  { "neovim/nvim-lspconfig" },

  -- Completion
  { "hrsh7th/nvim-cmp", dependencies = { "hrsh7th/cmp-nvim-lsp", "L3MON4D3/LuaSnip" } },

  -- Treesitter
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

  -- UI
  { "akinsho/bufferline.nvim", config = true },
  { "nvim-lualine/lualine.nvim", config = true },
  { "nvim-tree/nvim-web-devicons" },
  { "norcalli/nvim-colorizer.lua", config = true },

  -- Editing
  { "numToStr/Comment.nvim", config = true },
  { "windwp/nvim-autopairs", config = function() require("nvim-autopairs").setup({ check_ts = true, enable_check_bracket_line = false }) end },
  { "kylechui/nvim-surround", config = true },
  { "tpope/vim-sleuth" },
  { "RRethy/vim-illuminate" },

  -- Tools
  { "mbbill/undotree" },
  { "kdheepak/lazygit.nvim" },
  { "folke/which-key.nvim", config = true },
  { "folke/todo-comments.nvim", config = true },
  { "folke/trouble.nvim", config = true },
  { "mrcjkb/rustaceanvim" },
  { "j-hui/fidget.nvim", config = true },
})

-- LSP setup
local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

for _, server in ipairs({ "lua_ls", "rust_analyzer", "gopls" }) do
  lspconfig[server].setup({ capabilities = capabilities })
end

-- Completion setup
local cmp = require("cmp")
cmp.setup({
  snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ["<C-p>"] = cmp.mapping.select_prev_item(),
  }),
  sources = cmp.config.sources({ { name = "nvim_lsp" } }),
})

-- Keymaps
local keymap = vim.keymap

keymap.set("n", "<C-h>", "<C-w>h", { desc = "Focus left" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Focus down" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Focus up" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Focus right" })

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })
keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Undotree" })

keymap.set("n", "<leader>zz", "<cmd>wqa<cr>", { desc = "Write and close everything" })
keymap.set("n", "<leader>qq", "<cmd>qa!<cr>", { desc = "Close everything without saving" })

keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })

-- Snacks keymaps
keymap.set("n", "<leader>e", function() Snacks.explorer() end, { desc = "File Explorer" })
keymap.set("n", "<leader>nt", function() Snacks.notifier.hide() end, { desc = "Hide Notifications" })
keymap.set("n", "<leader>nl", function() Snacks.notifier.show_history() end, { desc = "Notification History" })
keymap.set("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "Find Files" })
keymap.set("n", "<leader>fs", function() Snacks.picker.grep() end, { desc = "Search Text" })
keymap.set("n", "<leader>fb", function() Snacks.picker.buffers() end, { desc = "Buffers" })
keymap.set("n", "<leader>fh", function() Snacks.picker.help() end, { desc = "Help" })
keymap.set("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "Recent Files" })
keymap.set("n", "<leader>nz", function() Snacks.zen() end, { desc = "Zen Mode" })

-- LSP keymaps
keymap.set("n", "<leader>ld", function() Snacks.picker.lsp_definitions() end, { desc = "Go to Definition" })
keymap.set("n", "<leader>lr", function() Snacks.picker.lsp_references() end, { desc = "References" })
keymap.set("n", "<leader>ls", function() Snacks.picker.lsp_symbols() end, { desc = "Document Symbols" })
keymap.set("n", "<leader>lt", function() Snacks.picker.diagnostics() end, { desc = "Diagnostics" })

-- Git keymaps
keymap.set("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
keymap.set("n", "<leader>gs", function() Snacks.picker.git_status() end, { desc = "Git Status" })
keymap.set("n", "<leader>gb", function() Snacks.git.blame_line() end, { desc = "Git Blame Line" })
