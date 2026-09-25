"""Click-through black overlay that dims the whole screen.

The Pi 5's vc4 CRTCs have no GAMMA_LUT, so gamma-based dimmers
(wl-gammarelay-rs, wlsunset) fail on this panel. Instead this puts a
full-screen layer-shell surface on the overlay layer, with an empty input
region so every touch and click passes through, and paints it black at
alpha = 1 - level.

The level (0.05..1) lives in $XDG_RUNTIME_DIR/screen-dim.level; the
`screen-dim` CLI writes it and sends SIGUSR1 (to the pid in screen-dim.pid)
to re-read. At 1 the window is
hidden entirely.
"""

import os
import signal

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import GLib, Gtk, GtkLayerShell  # noqa: E402

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
STATE = os.path.join(RUNTIME, "screen-dim.level")
PIDFILE = os.path.join(RUNTIME, "screen-dim.pid")


def level():
    try:
        with open(STATE) as f:
            return max(0.05, min(1.0, float(f.read())))
    except (OSError, ValueError):
        return 1.0


win = Gtk.Window()
GtkLayerShell.init_for_window(win)
GtkLayerShell.set_namespace(win, "screen-dim")
GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
for edge in (
    GtkLayerShell.Edge.TOP,
    GtkLayerShell.Edge.BOTTOM,
    GtkLayerShell.Edge.LEFT,
    GtkLayerShell.Edge.RIGHT,
):
    GtkLayerShell.set_anchor(win, edge, True)
GtkLayerShell.set_exclusive_zone(win, -1)  # cover the bar too
GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)

win.set_app_paintable(True)
win.set_visual(win.get_screen().get_rgba_visual())


def draw(_widget, cr):
    cr.set_operator(cairo.OPERATOR_SOURCE)
    cr.set_source_rgba(0, 0, 0, 1 - level())
    cr.paint()


win.connect("draw", draw)


def apply():
    if level() >= 0.999:
        win.hide()
    else:
        win.show_all()
        # Empty input region: the overlay never receives touches or clicks.
        win.input_shape_combine_region(cairo.Region())
        win.queue_draw()
    return True


GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, apply)
GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, Gtk.main_quit)
with open(PIDFILE, "w") as f:
    f.write(str(os.getpid()))
apply()
Gtk.main()
