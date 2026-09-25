"""One app per workspace, for a screen too small for tiling.

- A new tiled window that opens on a workspace that already has windows is
  moved to a fresh workspace inserted right after it (current + 1); the
  workspaces to its right shift up by one. Floating windows (dialogs,
  popups) and the first window on an empty workspace stay put.
- Closing the last window on a workspace returns you to the workspace on
  its left (where it was most likely launched from) instead of leaving you
  on an empty one.
- When a workspace empties, the rest are renumbered 1..n so there are never
  gaps and "next"/"previous" stay predictable.

Only purely numeric workspace names are renamed; anything named by hand is
left alone.
"""

import i3ipc

sway = i3ipc.Connection()


def numeric(ws):
    return ws.name == str(ws.num)


def compact():
    """Renumber numeric workspaces to 1..n, in order."""
    for i, ws in enumerate(sorted(sway.get_workspaces(), key=lambda w: w.num), 1):
        if numeric(ws) and ws.num != i:
            sway.command(f'rename workspace "{ws.name}" to "{i}"')


def on_new_window(_conn, event):
    con = sway.get_tree().find_by_id(event.container.id)
    if con is None or con.type == "floating_con":
        return
    ws = con.workspace()
    if ws is None or len(ws.leaves()) <= 1:
        return  # alone on its workspace already

    n = ws.num
    # Shift everything right of n up by one, highest first so names never collide.
    for other in sorted(sway.get_workspaces(), key=lambda w: -w.num):
        if other.num > n and numeric(other):
            sway.command(f'rename workspace "{other.name}" to "{other.num + 1}"')
    sway.command(f"[con_id={con.id}] move container to workspace number {n + 1}")
    sway.command(f"workspace number {n + 1}")


def on_close(_conn, _event):
    focused = sway.get_tree().find_focused()
    ws = focused.workspace() if focused else None
    if ws is None or ws.leaves() or ws.floating_nodes:
        return
    others = sorted(w.num for w in sway.get_workspaces() if w.num != ws.num)
    if not others:
        return
    left = [n for n in others if n < ws.num]
    sway.command(f"workspace number {left[-1] if left else others[0]}")


def on_workspace(_conn, event):
    if event.change == "empty":
        compact()


sway.on(i3ipc.Event.WINDOW_NEW, on_new_window)
sway.on(i3ipc.Event.WINDOW_CLOSE, on_close)
sway.on(i3ipc.Event.WORKSPACE, on_workspace)
compact()
sway.main()
