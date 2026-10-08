"""Stop RustDesk holding the laptop awake for as long as a session is open."""

import os
from pathlib import Path
import tomlkit

directory = Path.home() / ".config/rustdesk"
directory.mkdir(parents=True, exist_ok=True)
path = directory / "RustDesk_local.toml"
document = tomlkit.parse(path.read_text()) if path.exists() else tomlkit.document()
options = document.setdefault("options", tomlkit.table())
options["keep-awake-during-outgoing-sessions"] = "N"
temporary = path.with_suffix(".toml.tmp")
temporary.write_text(tomlkit.dumps(document))
temporary.chmod(0o600)
os.replace(temporary, path)
