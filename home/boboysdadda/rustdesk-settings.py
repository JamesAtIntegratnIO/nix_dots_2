"""RustDesk options this laptop needs, merged into the app's mutable config."""

import os
from pathlib import Path
import tomlkit

directory = Path.home() / ".config/rustdesk"
directory.mkdir(parents=True, exist_ok=True)


def set_options(name, options):
    path = directory / name
    document = tomlkit.parse(path.read_text()) if path.exists() else tomlkit.document()
    table = document.setdefault("options", tomlkit.table())
    for key, value in options.items():
        table[key] = value
    temporary = path.with_suffix(".toml.tmp")
    temporary.write_text(tomlkit.dumps(document))
    temporary.chmod(0o600)
    os.replace(temporary, path)


# Stop RustDesk holding the laptop awake for as long as a session is open.
set_options("RustDesk_local.toml", {"keep-awake-during-outgoing-sessions": "N"})
# The laptop is never a RustDesk host. studio-desktop runs RustDesk's server
# process for its hardware codec list; with the service stopped that process
# neither registers with the rendezvous server nor listens for connections.
set_options("RustDesk2.toml", {"stop-service": "Y"})
