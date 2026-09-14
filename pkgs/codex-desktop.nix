{ pkgs, lib, ... }:

let
  version = "26.908.61612";
  app = pkgs.stdenvNoCC.mkDerivation {
    pname = "codex-desktop-unwrapped";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
      hash = "sha256-HksYls1WlNtmcCKtqFgEVYMyIwJ6KURAnLS1Nee1SF4=";
    };
    nativeBuildInputs = [ pkgs.dpkg ];
    unpackPhase = ''
      dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-owner --no-same-permissions
    '';
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;
    installPhase = ''
      mkdir -p "$out"
      cp -a usr/lib usr/share "$out/"
    '';
  };
in
# Keep the vendor Electron tree intact, including its bundled CLI and Node.
pkgs.buildFHSEnv {
  name = "chatgpt";
  targetPkgs =
    p: with p; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      git
      glib
      gtk3
      libGL
      libgbm
      libnotify
      libpulseaudio
      libsecret
      libusb1
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      stdenv.cc.cc.lib
      systemd
      vulkan-loader
      xdg-utils
      xz
    ];
  runScript = "${app}/lib/chatgpt/ChatGPT";
  extraInstallCommands = ''
    mkdir -p "$out/share/applications"
    cp ${app}/share/applications/chatgpt.desktop "$out/share/applications/"
    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail "Exec=chatgpt %U" "Exec=$out/bin/chatgpt %U"
    cp -a ${app}/share/pixmaps "$out/share/"
  '';
  meta = {
    description = "OpenAI desktop app with Codex (official Linux preview)";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
