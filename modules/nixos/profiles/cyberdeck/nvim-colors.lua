-- Cyberdeck for Neovim. `p` is the palette, prepended by ./nvim.nix.
--
-- Every color is given twice: the palette's hex for a truecolor terminal, and
-- the ANSI slot the terminal already maps to the same color, so the Linux
-- console and any terminal without truecolor still come out in the palette.
-- The background is left to the terminal, which keeps its transparency.
vim.cmd.highlight("clear")
vim.g.colors_name = "cyberdeck"
vim.o.background = "dark"

local c = {
  none = { "NONE", "NONE" },
  void = { p.void, 0 },
  mantle = { p.mantle, 0 },
  surface = { p.surface, 0 },
  overlay = { p.overlay, 8 },
  subtext = { p.subtext, 8 },
  text = { p.text, 7 },
  bright = { p.bright, 15 },
  red = { p.red, 1 },
  green = { p.green, 2 },
  amber = { p.amber, 3 },
  blue = { p.blue, 4 },
  magenta = { p.magenta, 5 },
  cyan = { p.cyan, 6 },
  purple = { p.purple, 13 },
  cyanBright = { p.cyanBright, 14 },
  blueBright = { p.blueBright, 12 },
}

local function hi(group, spec)
  if type(spec) == "string" then
    vim.api.nvim_set_hl(0, group, { link = spec })
    return
  end
  local o = {}
  for k, v in pairs(spec) do
    if k == "fg" or k == "bg" then
      o[k], o["cterm" .. k] = c[v][1], c[v][2]
    elseif k == "sp" then
      o.sp = c[v][1]
    else
      o[k] = v
    end
  end
  vim.api.nvim_set_hl(0, group, o)
end

local groups = {
  -- Editor
  Normal = { fg = "text", bg = "none" },
  NormalNC = "Normal",
  NormalFloat = { fg = "text", bg = "mantle" },
  FloatBorder = { fg = "cyan", bg = "mantle" },
  FloatTitle = { fg = "cyan", bg = "mantle", bold = true },
  Cursor = { fg = "void", bg = "green" },
  CursorLine = { bg = "mantle" },
  CursorColumn = "CursorLine",
  ColorColumn = { bg = "mantle" },
  LineNr = { fg = "overlay" },
  CursorLineNr = { fg = "amber", bold = true },
  SignColumn = { bg = "none" },
  FoldColumn = { fg = "overlay" },
  Folded = { fg = "subtext", bg = "mantle" },
  WinSeparator = { fg = "surface" },
  VertSplit = "WinSeparator",
  StatusLine = { fg = "text", bg = "surface" },
  StatusLineNC = { fg = "overlay", bg = "mantle" },
  TabLine = { fg = "subtext", bg = "mantle" },
  TabLineFill = { bg = "mantle" },
  TabLineSel = { fg = "void", bg = "cyan", bold = true },
  WinBar = { fg = "subtext", bold = true },
  WinBarNC = { fg = "overlay" },
  Visual = { bg = "surface" },
  Search = { fg = "void", bg = "amber" },
  CurSearch = { fg = "void", bg = "magenta" },
  IncSearch = "CurSearch",
  Substitute = { fg = "void", bg = "magenta" },
  MatchParen = { fg = "cyanBright", bold = true, underline = true },
  Pmenu = { fg = "text", bg = "mantle" },
  PmenuSel = { fg = "void", bg = "cyan" },
  PmenuSbar = { bg = "mantle" },
  PmenuThumb = { bg = "overlay" },
  WildMenu = "PmenuSel",
  NonText = { fg = "overlay" },
  Whitespace = { fg = "surface" },
  SpecialKey = { fg = "overlay" },
  EndOfBuffer = { fg = "surface" },
  Conceal = { fg = "overlay" },
  Directory = { fg = "cyan" },
  Title = { fg = "cyan", bold = true },
  Question = { fg = "green" },
  MoreMsg = { fg = "green" },
  ModeMsg = { fg = "subtext", bold = true },
  ErrorMsg = { fg = "red", bold = true },
  WarningMsg = { fg = "amber" },
  QuickFixLine = { bg = "surface", bold = true },
  SpellBad = { undercurl = true, sp = "red" },
  SpellCap = { undercurl = true, sp = "amber" },
  SpellRare = { undercurl = true, sp = "purple" },
  SpellLocal = { undercurl = true, sp = "blue" },

  -- Syntax. Treesitter and LSP groups link to these by default.
  Comment = { fg = "subtext", italic = true },
  Constant = { fg = "amber" },
  String = { fg = "green" },
  Character = { fg = "green" },
  Number = { fg = "amber" },
  Boolean = { fg = "amber" },
  Float = { fg = "amber" },
  Identifier = { fg = "text" },
  Function = { fg = "cyan" },
  Statement = { fg = "magenta" },
  Keyword = { fg = "magenta" },
  Conditional = { fg = "magenta" },
  Repeat = { fg = "magenta" },
  Exception = { fg = "magenta" },
  Operator = { fg = "cyanBright" },
  PreProc = { fg = "purple" },
  Include = { fg = "purple" },
  Type = { fg = "blueBright" },
  StorageClass = { fg = "magenta" },
  Special = { fg = "cyanBright" },
  Delimiter = { fg = "subtext" },
  Tag = { fg = "cyan" },
  Underlined = { fg = "blue", underline = true },
  Error = { fg = "red", bold = true },
  Todo = { fg = "void", bg = "amber", bold = true },
  ["@variable"] = { fg = "text" },
  ["@variable.builtin"] = { fg = "purple" },
  ["@variable.parameter"] = { fg = "bright" },
  ["@property"] = { fg = "blueBright" },
  ["@constructor"] = { fg = "blueBright" },
  ["@module"] = { fg = "purple" },
  ["@tag.attribute"] = { fg = "amber" },
  ["@markup.heading"] = "Title",
  ["@markup.link"] = { fg = "blue", underline = true },
  ["@markup.raw"] = { fg = "green" },

  -- Diagnostics, diffs, version control
  DiagnosticError = { fg = "red" },
  DiagnosticWarn = { fg = "amber" },
  DiagnosticInfo = { fg = "blue" },
  DiagnosticHint = { fg = "cyan" },
  DiagnosticOk = { fg = "green" },
  DiagnosticUnderlineError = { undercurl = true, sp = "red" },
  DiagnosticUnderlineWarn = { undercurl = true, sp = "amber" },
  DiagnosticUnderlineInfo = { undercurl = true, sp = "blue" },
  DiagnosticUnderlineHint = { undercurl = true, sp = "cyan" },
  DiffAdd = { fg = "green", bg = "mantle" },
  DiffChange = { fg = "amber", bg = "mantle" },
  DiffDelete = { fg = "red", bg = "mantle" },
  DiffText = { fg = "void", bg = "amber" },
  Added = { fg = "green" },
  Changed = { fg = "amber" },
  Removed = { fg = "red" },
  diffAdded = "Added",
  diffChanged = "Changed",
  diffRemoved = "Removed",
  GitSignsAdd = "Added",
  GitSignsChange = "Changed",
  GitSignsDelete = "Removed",
}

for group, spec in pairs(groups) do
  hi(group, spec)
end

-- :terminal gets the same 16 slots as the terminal outside.
for i, hex in ipairs(p.ansi) do
  vim.g["terminal_color_" .. (i - 1)] = hex
end
