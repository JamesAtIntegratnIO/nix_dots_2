{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:
stdenvNoCC.mkDerivation {
  pname = "rustdesk";
  version = "1.4.9";
  src = fetchurl {
    url = "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-aarch64.dmg";
    hash = "sha256-95NVl7JH1CyPKi7XEXap9YaAGM2eGjO4CWQYpmjIyvA=";
  };
  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  dontBuild = true;
  dontFixup = true; # Preserve the official app's code signature.
  installPhase = ''
    mkdir -p "$out/Applications" "$out/bin"
    cp -R RustDesk.app "$out/Applications/"
    ln -s "$out/Applications/RustDesk.app/Contents/MacOS/RustDesk" "$out/bin/rustdesk"
  '';
  meta = {
    description = "Official RustDesk Apple Silicon desktop app";
    homepage = "https://rustdesk.com";
    license = lib.licenses.agpl3Only;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "rustdesk";
  };
}
