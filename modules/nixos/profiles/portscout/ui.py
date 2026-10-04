"""portscout dashboard: a touch front end for ./core.py on the 640x480 panel.

One screen, six tiles (link, switch, address, path, VLANs, neighbors), each
with a status stripe and a headline readable at arm's length. Tap a tile for
the full detail; the bar's back button returns. Nothing needs a keyboard, a
double-tap or a hover.

It starts PASSIVE: it only listens and does what any client on the port does.
The bar's mode button switches to ACTIVE, which sweeps the segment for
neighbors and unlocks the per-tile probes (DHCP discover, iperf3).

The port itself starts in SCOUT on every plug-in: it has an address for the
checks, but the handheld's own traffic and DNS stay on Wi-Fi. The second bar
button switches it to LIVE, an ordinary connection, until the link drops.

The checks rerun by themselves whenever the link comes up or drops, and the
address is followed for as long as the link stays up.

PORTSCOUT_REPORT=<file> shows a saved report (the bar's save button writes
them to ~/portscout) instead of scanning, e.g. to review one later or to work
on the layout without a cable. A "detail" key in it opens that tile's page.
It runs as its own application, so it never stands in for the live dashboard.
"""

import json
import os
import re
import subprocess
import threading
import time

import gi

gi.require_version("Gdk", "4.0")
gi.require_version("Gtk", "4.0")
from gi.repository import Gdk, Gio, GLib, Gtk, Pango  # noqa: E402

import core  # noqa: E402

APP_ID = "io.integratn.portscout"
REPORTS = os.path.expanduser("~/portscout")

TILES = [
    ("link", "LINK"),
    ("switch", "SWITCH"),
    ("address", "ADDRESS"),
    ("path", "PATH"),
    ("vlans", "VLANS"),
    ("neighbors", "NEIGHBORS"),
]
TITLES = dict(TILES)

# Active-only probe offered on a tile's detail page: tile -> (check, button).
PROBES = {
    "address": ("dhcp_probe", "Probe for DHCP servers"),
    "path": ("speed", "Speed test (iperf3)"),
    "neighbors": ("neighbors", "Sweep again"),
}
PROBE_TITLES = {"dhcp_probe": "DHCP SERVERS", "speed": "SPEED TEST"}

# How long to wait for the slow starters before calling it. LLDP is sent every
# 30 s, CDP every 60 s.
LLDP_WAIT = 65
DHCP_SETTLE = 12
DHCP_WAIT = 45
# How long a lease from before the link came up is distrusted (see job_net).
LEASE_RECHECK = 20

# Nerd Font glyphs by codepoint: literal Private Use Area characters get
# stripped from source files by editors and tools.
G_ETHERNET = ""
G_REFRESH = ""
G_SAVE = ""
G_BACK = ""

LOCKED = core.res("off", "Passive mode", ["switch to ACTIVE to sweep", "the segment for hosts"])
NO_LINK = core.res("off", "-", ["no link"])

PALETTE = {
    "void": "05070a",
    "base": "0b0f14",
    "mantle": "121a22",
    "surface": "1c2833",
    "overlay": "3b5160",
    "subtext": "7f93a3",
    "text": "d4e2ea",
    "cyan": "00e5ff",
    "green": "39ff9f",
    "magenta": "ff2e88",
    "amber": "ffb000",
    "red": "ff3355",
}

# Sized for 640x456 (the panel minus Waybar): the bar is 44px, each tile about
# 319x137. No gaps or padding beyond what keeps text off the edges; the 1px
# lines between tiles are the grid's own background showing through.
CSS = """
window {{ background: #{void}; color: #{text}; }}
* {{ font-family: "JetBrainsMono Nerd Font", monospace; font-size: 13px; }}
button {{
  border: none; border-radius: 0; box-shadow: none; outline: none;
  background-image: none; background: #{mantle}; color: #{text};
  padding: 0; margin: 0; min-height: 0; min-width: 0;
}}
.bar {{ background: #{mantle}; border-bottom: 1px solid alpha(#{cyan}, 0.35); }}
.bar button {{
  min-height: 44px; min-width: 52px; padding: 0 10px;
  background: #{surface}; margin-left: 1px; font-size: 16px;
}}
.bar button:active {{ background: #{overlay}; }}
.bar .where {{ padding: 0 8px; color: #{cyan}; font-weight: bold; }}
.bar .mode {{ font-size: 12px; font-weight: bold; letter-spacing: 1px; color: #{cyan}; min-width: 84px; }}
.bar .mode:checked {{ background: #{magenta}; color: #{void}; }}
.bar .net:checked {{ background: #{amber}; color: #{void}; }}
.bar .mode:disabled {{ color: #{overlay}; }}
.tiles {{ background: #{surface}; }}
.tile {{ background: #{base}; border-left: 4px solid #{overlay}; padding: 4px 8px; }}
.tile:active {{ background: #{surface}; }}
.title {{ color: #{subtext}; font-size: 10px; font-weight: bold; letter-spacing: 2px; }}
.head {{ font-size: 18px; font-weight: bold; color: #{subtext}; }}
.st-ok {{ border-left-color: #{green}; }}
.st-warn {{ border-left-color: #{amber}; }}
.st-bad {{ border-left-color: #{red}; }}
.st-wait {{ border-left-color: #{cyan}; }}
.st-ok .head, .head.st-ok {{ color: #{green}; }}
.st-warn .head, .head.st-warn {{ color: #{amber}; }}
.st-bad .head, .head.st-bad {{ color: #{red}; }}
.st-wait .head, .head.st-wait {{ color: #{cyan}; }}
.st-off .head, .head.st-off {{ color: #{overlay}; }}
.st-off .line {{ color: #{overlay}; }}
.detail {{ background: #{base}; padding: 4px 8px; }}
.detail .key {{ color: #{subtext}; }}
.detail .section {{ margin-top: 10px; }}
.probe {{
  min-height: 48px; background: #{surface}; color: #{magenta};
  font-weight: bold; border-top: 1px solid alpha(#{magenta}, 0.5);
}}
.probe:active {{ background: #{overlay}; }}
"""

STATUSES = ("ok", "warn", "bad", "wait", "off")


def load_css():
    palette = dict(PALETTE)
    try:
        with open(os.environ["PORTSCOUT_PALETTE"]) as f:
            palette.update({k: v for k, v in json.load(f).items() if isinstance(v, str)})
    except (KeyError, OSError, ValueError):
        pass
    provider = Gtk.CssProvider()
    css = CSS.format(**palette)
    if hasattr(provider, "load_from_string"):
        provider.load_from_string(css)
    else:
        provider.load_from_data(css.encode())
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )


def label(text="", css=None, wrap=False):
    lb = Gtk.Label(label=text, xalign=0)
    if wrap:
        lb.set_wrap(True)
        lb.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
    else:
        # Ellipsize instead of growing: a long value must never resize a tile.
        lb.set_ellipsize(Pango.EllipsizeMode.END)
    if css:
        lb.add_css_class(css)
    return lb


def set_status(widget, status):
    for s in STATUSES:
        widget.remove_css_class(f"st-{s}")
    widget.add_css_class(f"st-{status}")


class Tile(Gtk.Button):
    def __init__(self, title):
        super().__init__(hexpand=True, vexpand=True)
        self.add_css_class("tile")
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1, valign=Gtk.Align.START)
        self.head = label(css="head")
        self.lines = [label(css="line") for _ in range(4)]
        box.append(label(title, "title"))
        box.append(self.head)
        for lb in self.lines:
            box.append(lb)
        self.set_child(box)

    def show_result(self, r):
        set_status(self, r["status"])
        self.head.set_text(r["headline"])
        for n, lb in enumerate(self.lines):
            lb.set_text(r["lines"][n] if n < len(r["lines"]) else "")


class Dashboard(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="portscout")
        self.set_decorated(False)
        self.set_default_size(640, 456)

        self.gen = 0  # bumped per rescan; results from an older one are dropped
        self.active = False
        self.results = {}
        self.addr = {}
        self.busy = set()
        self.detail_key = None
        self.was_up = None
        self.last_down = 0  # wall-clock time the link was last seen down
        self.frozen = False  # showing a saved report: nothing touches the wire

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        root.append(self.build_bar())
        self.stack = Gtk.Stack(vexpand=True)
        self.stack.add_named(self.build_tiles(), "tiles")
        self.stack.add_named(self.build_detail(), "detail")
        root.append(self.stack)
        self.set_child(root)

        report = os.environ.get("PORTSCOUT_REPORT")
        if report:
            self.show_report(report)
        else:
            GLib.timeout_add_seconds(1, self.poll_carrier)
            self.rescan()

    # --- layout ---------------------------------------------------------------

    def build_bar(self):
        bar = Gtk.Box()
        bar.add_css_class("bar")
        self.back = Gtk.Button(label=G_BACK, visible=False)
        self.back.connect("clicked", lambda _: self.show_tiles())
        self.where = label(css="where")
        self.where.set_hexpand(True)
        self.net = Gtk.ToggleButton(label="SCOUT", sensitive=False)
        self.net.add_css_class("mode")
        self.net.add_css_class("net")
        self.net_handler = self.net.connect("toggled", self.on_net)
        self.switching = False
        self.port_mode = "down"
        self.mode = Gtk.ToggleButton(label="PASSIVE")
        self.mode.add_css_class("mode")
        self.mode.connect("toggled", self.on_mode)
        self.rescan_button = Gtk.Button(label=G_REFRESH)
        self.rescan_button.connect("clicked", lambda _: self.rescan())
        save = Gtk.Button(label=G_SAVE)
        save.connect("clicked", self.on_save)
        for w in (self.back, self.where, self.net, self.mode, self.rescan_button, save):
            bar.append(w)
        return bar

    def build_tiles(self):
        grid = Gtk.Grid(
            column_homogeneous=True, row_homogeneous=True, column_spacing=1, row_spacing=1
        )
        grid.add_css_class("tiles")
        self.tiles = {}
        for n, (key, title) in enumerate(TILES):
            tile = Tile(title)
            tile.connect("clicked", lambda _, k=key: self.show_detail(k))
            grid.attach(tile, n % 2, n // 2, 1, 1)
            self.tiles[key] = tile
        return grid

    def build_detail(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.rows.add_css_class("detail")
        # Kinetic touch scrolling comes with ScrolledWindow.
        scroll = Gtk.ScrolledWindow(vexpand=True, hscrollbar_policy=Gtk.PolicyType.NEVER)
        scroll.set_child(self.rows)
        self.probe = Gtk.Button()
        self.probe.add_css_class("probe")
        self.probe.connect("clicked", self.on_probe)
        page.append(scroll)
        page.append(self.probe)
        return page

    # --- navigation -----------------------------------------------------------

    def show_tiles(self):
        self.detail_key = None
        self.back.set_visible(False)
        self.stack.set_visible_child_name("tiles")
        self.update_bar()

    def show_detail(self, key):
        self.detail_key = key
        self.back.set_visible(True)
        self.render_detail()
        self.stack.set_visible_child_name("detail")
        self.update_bar()

    def update_bar(self):
        saved = "REPORT · " if self.frozen else ""
        if self.detail_key:
            r = self.results.get(self.detail_key, NO_LINK)
            self.where.set_text(f"{saved}{TITLES[self.detail_key]} · {r['headline']}")
        else:
            r = self.results.get("link", NO_LINK)
            self.where.set_text(f"{saved}{G_ETHERNET} {core.IFACE} · {r['headline']}")

    def flash(self, text):
        self.where.set_text(text)
        GLib.timeout_add_seconds(3, lambda: self.update_bar() or False)

    def render_detail(self):
        key = self.detail_key
        while child := self.rows.get_first_child():
            self.rows.remove(child)
        self.add_section(self.results.get(key, NO_LINK))
        check, text = PROBES.get(key, (None, ""))
        if check and check != key and check in self.results:
            self.add_section(self.results[check], PROBE_TITLES[check])
        offered = bool(check) and self.active and not self.frozen
        offered = offered and (check != "speed" or bool(core.IPERF_SERVER))
        self.probe.set_visible(offered)
        self.probe.set_label("Running..." if check in self.busy else text)
        self.probe.set_sensitive(check not in self.busy)

    def add_section(self, r, title=None):
        if title:
            section = label(title, "title")
            section.add_css_class("section")
            self.rows.append(section)
        head = label(r["headline"], "head", wrap=True)
        set_status(head, r["status"])
        self.rows.append(head)
        for line in r["lines"]:
            self.rows.append(label(line, "line", wrap=True))
        grid = Gtk.Grid(column_spacing=10, row_spacing=3, margin_top=6)
        for n, (k, v) in enumerate(r["details"]):
            # Wrapped, not ellipsized: long keys differ only at the end.
            key = label(k, "key", wrap=True)
            key.set_width_chars(20)
            key.set_max_width_chars(20)
            key.set_valign(Gtk.Align.START)
            value = label(v, wrap=True)
            value.set_hexpand(True)
            grid.attach(key, 0, n, 1, 1)
            grid.attach(value, 1, n, 1, 1)
        self.rows.append(grid)

    # --- results --------------------------------------------------------------

    def show_net(self, mode):
        """Reflect how the port is being used on the SCOUT/LIVE button."""
        self.net.handler_block(self.net_handler)
        self.net.set_active(mode == "live")
        self.net.handler_unblock(self.net_handler)
        self.net.set_label("LIVE" if mode == "live" else "SCOUT")
        self.port_mode = mode
        self.net.set_sensitive(mode != "down" and not self.frozen and not self.switching)

    def on_net(self, button):
        # From any other profile (one activated by hand, say) a tap goes to scout.
        want = "live" if self.port_mode == "scout" else "scout"
        self.switching = True
        button.set_sensitive(False)
        button.set_label("...")

        def done(ok, msg):
            self.switching = False
            self.show_net(core.mode())
            self.rescan()
            if not ok:
                self.flash(f"switch failed: {msg}")
            return False

        def job():
            GLib.idle_add(done, *core.set_mode(want))

        threading.Thread(target=job, daemon=True).start()

    def set_result(self, key, r):
        self.results[key] = r
        # Placeholder results carry no mode; keep what the button shows.
        if key == "address" and not self.switching and "mode" in r["data"]:
            self.show_net(r["data"]["mode"])
        if key in self.tiles:
            self.tiles[key].show_result(r)
        if self.detail_key and key in (self.detail_key, PROBES.get(self.detail_key, ("",))[0]):
            self.render_detail()
        self.update_bar()

    def post(self, gen, key, r):
        """Hand a result from a worker thread to the UI thread."""

        def apply():
            if gen == self.gen:
                self.set_result(key, r)
            return False

        GLib.idle_add(apply)

    def poll_carrier(self):
        up = core.carrier()
        if not up:
            self.last_down = time.time()
        if up != self.was_up:
            self.rescan()
        return True

    def rescan(self):
        if self.frozen:
            return
        self.gen += 1
        gen = self.gen
        self.results = {}
        self.addr = {}
        # Remember what this scan saw, so poll_carrier notices the next change
        # however soon after it happens.
        self.was_up = core.carrier()

        self.set_result("link", core.link())
        if not self.was_up:
            self.last_down = time.time()
            self.show_net("down")
            for key, _ in TILES[1:]:
                self.set_result(key, NO_LINK)
            return
        for key in ("switch", "vlans", "address", "path"):
            self.set_result(key, core.res("wait", "...", []))
        self.set_result("neighbors", core.res("wait", "...", []) if self.active else LOCKED)
        for job, args in (
            (self.job_switch, (gen,)),
            (self.job_vlans, (gen,)),
            (self.job_net, (gen, self.last_down)),
        ):
            threading.Thread(target=job, args=args, daemon=True).start()

    def job_switch(self, gen):
        t0 = time.monotonic()
        said = None
        while gen == self.gen:
            r = core.switch()
            if r["status"] != "wait":
                self.post(gen, "switch", r)
                return
            # Past the deadline the verdict is "silent", but lldpd keeps
            # listening, so a late announcement still replaces it.
            late = time.monotonic() - t0 > LLDP_WAIT
            if late:
                r = core.switch_silent()
            if r != said:
                said = r
                self.post(gen, "switch", r)
            time.sleep(10 if late else 3)

    def job_vlans(self, gen):
        self.post(gen, "vlans", core.res("wait", "Listening...", ["802.1Q tags: 8 s"]))
        self.post(gen, "vlans", core.vlans())

    def job_net(self, gen, last_down):
        """Follow the address for as long as this link stays up, and test the
        path each time it settles on something new."""
        t0 = time.monotonic()
        shown = tested = None
        had_ip = False
        while gen == self.gen:
            r = core.address()
            d = r["data"]
            waited = time.monotonic() - t0
            # "obtained" is whole seconds rounded down, hence the second's grace:
            # without it a lease from this very link-up can look older than it.
            old = bool(d.get("ip")) and (d.get("obtained") or last_down) + 1 < last_down
            had_ip = had_ip or bool(d.get("ip"))
            if old and waited < LEASE_RECHECK:
                # NetworkManager keeps the previous port's lease across a quick
                # cable move until DHCP confirms or replaces it; don't present
                # it as this port's address, or test the path with it.
                lines = [f"had {d['ip']} on the last link", "waiting for DHCP to confirm"]
                r = core.res("wait", "Renewing lease...", lines, r["details"])
            elif not d.get("ip"):
                if had_ip:
                    # The address it had is gone (old lease dropped, profile
                    # re-activated): DHCP is starting over, and so is its clock.
                    t0, waited, had_ip = time.monotonic(), 0, False
                if waited > DHCP_WAIT:
                    if r["status"] == "wait":
                        lines = [f"no DHCP answer in {DHCP_WAIT} s"]
                        r = core.res("bad", "No address", lines, r["details"])
                elif r["status"] == "wait" or waited <= DHCP_SETTLE:
                    # NetworkManager takes a moment to start on a fresh link;
                    # don't call it failed until it has had the chance.
                    r = core.res("wait", "Getting address...", r["lines"], r["details"])
            if r != shown:
                shown = r
                self.post(gen, "address", r)

            settled = r["status"] != "wait"
            now = (d.get("ip"), d.get("gateway"), tuple(d.get("dns", [])))
            if settled and now != tested:
                tested = now
                GLib.idle_add(self.set_addr, gen, d)
                if d.get("ip"):
                    self.post(gen, "path", core.res("wait", "Testing...", ["gateway, DNS, internet"]))
                    self.post(gen, "path", core.path(d))
                    # Traffic has crossed the link now, so its error counters
                    # mean something; they were necessarily clean at link-up.
                    self.post(gen, "link", core.link())
                else:
                    self.post(gen, "path", core.res("off", "-", ["needs an address first"]))
            time.sleep(5 if settled else 2)

    def set_addr(self, gen, addr):
        if gen == self.gen:
            self.addr = addr
            if self.active:
                # With no address this says so, rather than leaving "...".
                self.start("neighbors")
        return False

    # --- active mode ----------------------------------------------------------

    def on_mode(self, button):
        self.active = button.get_active()
        button.set_label("ACTIVE" if self.active else "PASSIVE")
        if self.frozen:
            return
        if self.active:
            self.start("neighbors")
        elif core.carrier():
            self.set_result("neighbors", LOCKED)
        if self.detail_key:
            self.render_detail()

    def on_probe(self, _):
        check = PROBES.get(self.detail_key, (None,))[0]
        if check and self.active:
            self.start(check)

    def start(self, check):
        """Run one active check in the background."""
        if self.frozen or check in self.busy:
            return
        if not core.carrier():
            self.set_result(check, NO_LINK)
            return
        if check in ("neighbors", "speed") and not self.addr.get("ip"):
            self.set_result(check, core.res("off", "-", ["needs an address first"]))
            return
        gen, addr = self.gen, dict(self.addr)
        self.busy.add(check)
        self.set_result(check, core.res("wait", "Running...", []))

        def done(r):
            self.busy.discard(check)
            if gen == self.gen:
                self.set_result(check, r)
            elif check == "neighbors" and self.active:
                # A rescan made this sweep stale, and the sweep that rescan
                # asked for was refused while this one was busy: run it now.
                self.start(check)
            elif self.detail_key:
                self.render_detail()
            return False

        def job():
            GLib.idle_add(done, core.run_check(check, addr))

        threading.Thread(target=job, daemon=True).start()

    # --- report ---------------------------------------------------------------

    def show_report(self, path):
        with open(path) as f:
            report = json.load(f)
        self.frozen = True
        self.set_title("portscout report")
        self.mode.set_active(report.get("mode") == "active")
        self.mode.set_sensitive(False)
        self.rescan_button.set_visible(False)
        for key, r in report["results"].items():
            self.set_result(key, r)
        if report.get("detail") in self.tiles:
            self.show_detail(report["detail"])

    def on_save(self, _):
        sw = self.results.get("switch", {}).get("data", {})
        tag = "-".join(
            re.sub(r"[^A-Za-z0-9]+", "_", x).strip("_") for x in (sw.get("name"), sw.get("port")) if x
        )
        name = time.strftime("%Y%m%d-%H%M%S") + (f"-{tag}" if tag else "") + ".json"
        report = {
            "time": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "interface": core.IFACE,
            "mode": "active" if self.active else "passive",
            "port_mode": self.results.get("address", {}).get("data", {}).get("mode", "down"),
            "results": self.results,
        }
        try:
            os.makedirs(REPORTS, exist_ok=True)
            with open(os.path.join(REPORTS, name), "w") as f:
                json.dump(report, f, indent=2)
            self.flash(f"saved ~/portscout/{name}")
        except OSError as e:
            self.flash(f"save failed: {e}")


class App(Gtk.Application):
    def __init__(self):
        if os.environ.get("PORTSCOUT_REPORT"):
            # Not the dashboard: it must neither swallow a later launch of the
            # live one nor count as "already open" for the plug-in notification.
            super().__init__(
                application_id=APP_ID + ".report", flags=Gio.ApplicationFlags.NON_UNIQUE
            )
        else:
            super().__init__(application_id=APP_ID)

    def do_activate(self):
        win = self.get_active_window()
        if win is None:
            load_css()
            Dashboard(self).present()
            return
        # Already running (launched again from the notification or Super+N):
        # Sway only marks a re-presented window urgent, so focus it outright.
        win.present()
        try:
            # Anchored: Sway criteria are unanchored regexes, and the report
            # viewer's id starts the same way.
            criteria = f'[app_id="^{re.escape(APP_ID)}$"] focus'
            subprocess.Popen(["swaymsg", "-q", criteria], stderr=subprocess.DEVNULL)
        except OSError:
            pass


if __name__ == "__main__":
    App().run(None)
