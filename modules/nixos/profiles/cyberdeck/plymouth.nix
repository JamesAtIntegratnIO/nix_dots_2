# Plymouth boot splash: the desktop wallpaper (status "BOOTING") with a neon
# progress bar tracing the horizon line and boot messages in the bottom HUD
# slot. A script theme so it scales to whatever mode simpledrm hands over.
{
  pkgs,
  palette,
}:

let
  p = palette;

  splash = import ./wallpaper.nix {
    inherit pkgs palette;
    name = "pocketterm-splash";
    statusText = "◌ BOOTING";
    statusColor = p.amber;
  };

  # Plymouth's script API takes 0..1 floats; convert a palette hex string.
  hexDigit = c: (builtins.fromTOML "x = 0x${c}").x;
  channel = hex: off: toString ((hexDigit (builtins.substring off 2 hex)) / 255.0);
  rgb = hex: "${channel hex 0}, ${channel hex 2}, ${channel hex 4}";

  script = pkgs.writeText "cyberdeck.script" ''
    Window.SetBackgroundTopColor(${rgb p.void});
    Window.SetBackgroundBottomColor(${rgb p.void});

    w = Window.GetWidth();
    h = Window.GetHeight();

    bg = Sprite(Image("splash.png").Scale(w, h));
    bg.SetZ(-10);

    # Progress: a glowing bar growing along the horizon (y = 336 of 480).
    bar_img = Image("bar.png");
    bar = Sprite();
    bar.SetPosition(0, Math.Int(h * 336 / 480) - 1, 10);

    fun progress_cb(duration, progress) {
      width = Math.Int(w * progress);
      if (width < 2) width = 2;
      bar.SetImage(bar_img.Scale(width, 3));
    }
    Plymouth.SetBootProgressFunction(progress_cb);

    # Boot/shutdown messages in the bottom-left HUD slot.
    msg = Sprite();
    msg.SetPosition(Math.Int(w * 30 / 640), Math.Int(h * 440 / 480), 20);
    fun message_cb(text) {
      msg.SetImage(Image.Text(text, ${rgb p.subtext}, 1, "JetBrainsMono Nerd Font 9"));
    }
    Plymouth.SetMessageFunction(message_cb);
  '';
in
pkgs.runCommand "plymouth-theme-cyberdeck"
  {
    nativeBuildInputs = [ pkgs.imagemagick ];
    passthru.themeName = "cyberdeck";
  }
  ''
    dir=$out/share/plymouth/themes/cyberdeck
    mkdir -p $dir
    cp ${splash} $dir/splash.png
    magick -size 3x640 'gradient:#${p.magenta}-#${p.cyan}' -rotate -90 $dir/bar.png
    cp ${script} $dir/cyberdeck.script
    cat > $dir/cyberdeck.plymouth <<EOF
    [Plymouth Theme]
    Name=Cyberdeck
    Description=PocketTerm35 cyberdeck boot splash
    ModuleName=script

    [script]
    ImageDir=$dir
    ScriptFile=$dir/cyberdeck.script
    EOF
  ''
