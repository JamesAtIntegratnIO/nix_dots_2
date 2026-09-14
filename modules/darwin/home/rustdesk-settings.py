"""Preserve RustDesk credentials while enabling the Studio's Tailscale access."""

import os
from pathlib import Path
import tomlkit

directory = Path.home() / "Library/Preferences/com.carriez.RustDesk"
directory.mkdir(parents=True, exist_ok=True)
path = directory / "RustDesk2.toml"
document = tomlkit.parse(path.read_text()) if path.exists() else tomlkit.document()
options = document.setdefault("options", tomlkit.table())
options["direct-server"] = "Y"
options["direct-access-port"] = "21118"
options["whitelist"] = "100.91.78.45"
temporary = path.with_suffix(".toml.tmp")
temporary.write_text(tomlkit.dumps(document))
temporary.chmod(0o600)
os.replace(temporary, path)
