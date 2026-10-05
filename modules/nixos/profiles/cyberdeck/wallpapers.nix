# Every wallpaper style, rendered with one set of ./wallpaper.nix arguments
# into a directory for hosts that rotate their wallpaper. The files are named
# in rotation order (1-grid.png, 2-ridgeline.png, ...) and are also available
# as a list of store paths in `images`.
{
  pkgs,
  name,
  ...
}@args:

let
  styles = [
    "grid"
    "ridgeline"
    "traces"
    "sweep"
    "hexdump"
    "skyline"
  ];
  images = map (
    style:
    import ./wallpaper.nix (
      args
      // {
        inherit style;
        name = "${name}-${style}";
      }
    )
  ) styles;
in
pkgs.runCommand "${name}s" { passthru = { inherit images styles; }; } (
  ''
    mkdir $out
  ''
  + pkgs.lib.concatImapStrings (i: image: ''
    cp ${image} $out/${toString i}-${builtins.elemAt styles (i - 1)}.png
  '') images
)
