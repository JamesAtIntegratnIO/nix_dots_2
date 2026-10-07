# The Neovim colorscheme, as the text of colors/cyberdeck.lua: the palette as
# a Lua table, then ./nvim-colors.lua, which only refers to it by name.
palette:

let
  entry =
    name:
    let
      value = palette.${name};
    in
    if builtins.isString value then
      "  ${name} = \"#${value}\","
    else
      "  ${name} = { ${builtins.concatStringsSep ", " (map (c: "\"#${c}\"") value)} },";
in
''
  local p = {
  ${builtins.concatStringsSep "\n" (map entry (builtins.attrNames palette))}
  }
''
+ builtins.readFile ./nvim-colors.lua
