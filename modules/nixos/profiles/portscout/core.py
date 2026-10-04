"""portscout checks: what is this Ethernet port, and does it work?

Each check returns a dict the dashboard (./ui.py) and the CLI render the same
way:

    status    ok | warn | bad | wait | off
    headline  the one thing to read at a glance
    lines     up to four short supporting lines for the tile
    details   [key, value] rows for the detail page
    data      machine-readable extras other checks build on (optional)

Passive checks only listen, or do what any client plugged into the port does
anyway (DHCP, pinging its gateway, a DNS lookup, one HTTP request). Active
checks put probes on the wire -- an ARP sweep, a DHCP discover, iperf3 -- and
only run when asked.

Everything is bound to the wired interface: Wi-Fi and Tailscale stay up next
to it, and an unbound test would quietly report on the wrong network.

Checks that need root (lldpcli, tcpdump, arp-scan, nmap) go through
`sudo -n`.

There is no cable (TDR) test: the Pi 5's PHY driver has no cable-test
support, so `ethtool --cable-test` can only ever answer "not supported".
"""

import argparse
import ipaddress
import json
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import time

IFACE = os.environ.get("PORTSCOUT_IFACE", "end0")
IPERF_SERVER = os.environ.get("PORTSCOUT_IPERF_SERVER", "")
# Extra MAC-prefix -> vendor list for arp-scan, whose own dates from 2022.
OUI_FILE = os.environ.get("PORTSCOUT_OUI", "")

# The two NetworkManager profiles the port switches between (./default.nix).
# Scout, what every plug-in starts as, keeps the port's routes in a table of
# their own: the checks here reach it because they bind to the interface,
# while the handheld's own traffic and DNS stay on Wi-Fi. Live is an ordinary
# connection and lasts until the link drops.
PROFILES = {
    "scout": os.environ.get("PORTSCOUT_SCOUT", "portscout-scout"),
    "live": os.environ.get("PORTSCOUT_LIVE", "portscout-live"),
}
CHECK_HOST = "connectivitycheck.gstatic.com"

# A sweep of anything bigger than this is cut down to the /24 around us.
MAX_SWEEP_PREFIX = 22


def res(status, headline, lines=(), details=(), data=None):
    return {
        "status": status,
        "headline": headline,
        "lines": [x for x in lines if x][:4],
        "details": [[str(k), str(v)] for k, v in details],
        "data": data or {},
    }


def run(cmd, timeout=10, root=False):
    """Run cmd -> (returncode, stdout, stderr); never raises."""
    exe = shutil.which(cmd[0])
    if exe is None:
        return 127, "", f"{cmd[0]}: not installed"
    argv = [exe] + [str(c) for c in cmd[1:]]
    if root and os.geteuid() != 0:
        argv = ["sudo", "-n"] + argv
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
        if isinstance(out, bytes):
            out = out.decode(errors="replace")
        return 124, out, "timed out"
    except OSError as e:
        return 126, "", str(e)


def sysfs(name):
    try:
        with open(f"/sys/class/net/{IFACE}/{name}") as f:
            return f.read().strip()
    except OSError:
        # `carrier` and `speed` fail with EINVAL while the link is down.
        return ""


def carrier():
    return sysfs("carrier") == "1"


# --- scout / live -------------------------------------------------------------


def mode_of(profile):
    """NetworkManager profile on the port -> scout | live | other | down."""
    for name, p in PROFILES.items():
        if profile == p:
            return name
    return "other" if profile else "down"


def mode():
    _, out, _ = run(["nmcli", "-g", "GENERAL.CONNECTION", "device", "show", IFACE])
    return mode_of(out.strip())


def set_mode(name):
    """Activate the scout or live profile on the port -> (ok, message). The
    cable stays in; NetworkManager just takes a fresh lease under the other
    profile."""
    rc, out, err = run(
        ["nmcli", "--wait", "20", "connection", "up", "id", PROFILES[name], "ifname", IFACE],
        timeout=25,
    )
    return rc == 0, (err or out).strip()


# --- link ---------------------------------------------------------------------


def parse_ethtool(text):
    """`ethtool IFACE` -> {key: [tokens]}; continuation lines extend a key."""
    out, key = {}, None
    for line in text.splitlines():
        m = re.match(r"^\s+([A-Za-z][^:]*):\s*(.*)$", line)
        if m:
            key = m.group(1).strip()
            out[key] = m.group(2).split()
        elif key and line.strip():
            out[key] += line.split()
    return out


def best_mode(modes):
    """Fastest of ['100baseT/Full', '1000baseT/Full', ...] -> (speed, mode)."""
    best = (0, "")
    for m in modes:
        n = re.match(r"(\d+)base", m)
        if n and int(n.group(1)) >= best[0]:
            best = (int(n.group(1)), m)
    return best


def fmt_speed(mbps):
    if mbps >= 1000:
        return f"{mbps / 1000:g} Gb/s"
    return f"{mbps} Mb/s"


ERROR_COUNTERS = ("rx_errors", "rx_crc_errors", "rx_dropped", "tx_errors")


def error_baseline(stats):
    """The error counters as they stood when this link came up.

    The kernel's counters run since boot, so on their own one marginal cable
    would mark every port tested after it. link() saves them while the link is
    down, stamped with the carrier_up_count the next link will have; a first
    look at a link that is already up starts counting from that look.
    """
    path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), f"portscout-{IFACE}.json")
    ups, up = sysfs("carrier_up_count"), carrier()
    try:
        with open(path) as f:
            saved = json.load(f)
        base = {k: int(saved["counters"][k]) for k in stats}
        # A counter below its baseline means the driver was reloaded.
        if up and saved["ups"] == ups and all(stats[k] >= base[k] for k in stats):
            return base
    except (OSError, ValueError, KeyError, TypeError):
        pass
    try:
        stamp = ups if up else str(int(ups) + 1)
        with open(f"{path}.{os.getpid()}", "w") as f:
            json.dump({"ups": stamp, "counters": stats}, f)
        os.replace(f.name, path)
    except (OSError, ValueError):
        pass
    return stats


def link():
    if not os.path.isdir(f"/sys/class/net/{IFACE}"):
        return res("bad", "No interface", [f"{IFACE} does not exist"])
    mac = sysfs("address")
    stats = {k: int(sysfs(f"statistics/{k}") or 0) for k in ERROR_COUNTERS}
    base = error_baseline(stats)
    if not carrier():
        return res(
            "bad",
            "No link",
            ["no carrier: cable unplugged,", "port disabled, or dead run"],
            [("interface", IFACE), ("mac", mac)],
        )

    _, out, _ = run(["ethtool", IFACE])
    et = parse_ethtool(out)
    try:
        speed = int(sysfs("speed"))
    except ValueError:
        speed = 0
    duplex = sysfs("duplex").capitalize() or "?"
    partner_speed, partner_mode = best_mode(et.get("Link partner advertised link modes", []))
    ours_speed, _ = best_mode(et.get("Advertised link modes", []))
    errors = {k: stats[k] - base[k] for k in stats}

    status, notes = "ok", []
    if duplex == "Half":
        status = "warn"
        notes.append("half duplex: autoneg mismatch?")
    if partner_speed and speed < min(partner_speed, ours_speed or partner_speed):
        status = "warn"
        notes.append(f"below {fmt_speed(partner_speed)}: suspect cable")
    if errors["rx_crc_errors"]:
        status = "warn"
        notes.append(f"{errors['rx_crc_errors']} CRC errors on this link")

    lines = notes + [
        f"partner: up to {partner_mode}" if partner_mode else "partner: no autoneg info",
        f"autoneg {' '.join(et.get('Auto-negotiation', ['?']))}"
        f" · mdi-x {' '.join(et.get('MDI-X', ['?']))}",
        f"errors rx {errors['rx_errors']} tx {errors['tx_errors']}",
    ]
    details = [
        ("interface", IFACE),
        ("mac", mac),
        ("speed", fmt_speed(speed) if speed else "?"),
        ("duplex", duplex),
        ("mtu", sysfs("mtu")),
    ]
    details += [(f"{k} (this link)", errors[k]) for k in stats]
    details += [(f"{k} (since boot)", stats[k]) for k in stats]
    details += [(k.lower(), " ".join(v)) for k, v in et.items() if v]
    return res(status, f"{fmt_speed(speed)} {duplex}" if speed else "Link up", lines, details)


# --- switch (LLDP / CDP) ------------------------------------------------------


def _items(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def _val(x):
    for item in _items(x):
        if isinstance(item, dict):
            return str(item.get("value", ""))
        return str(item)
    return ""


def _first(x):
    for item in _items(x):
        if isinstance(item, dict):
            return item
    return {}


def flatten(obj, prefix=""):
    """Nested lldpcli JSON -> [(dotted.path, scalar)] rows."""
    rows = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            rows += flatten(v, f"{prefix}.{k}" if prefix else k)
    elif isinstance(obj, list):
        for n, v in enumerate(obj):
            rows += flatten(v, prefix if len(obj) == 1 else f"{prefix}[{n}]")
    elif obj not in (None, ""):
        rows.append((prefix.removesuffix(".value"), obj))
    return rows


def parse_lldp(doc):
    """lldpcli json0 output -> one dict per neighbor heard on IFACE."""
    found = []
    for top in _items(doc.get("lldp")):
        for nb in _items(top.get("interface") if isinstance(top, dict) else None):
            if not isinstance(nb, dict):
                continue
            ch, port = _first(nb.get("chassis")), _first(nb.get("port"))
            vlans = []
            for v in _items(nb.get("vlan")):
                if isinstance(v, dict) and v.get("vlan-id"):
                    tag = str(v["vlan-id"]) + (" (pvid)" if v.get("pvid") else "")
                    vlans.append(f"{tag} {v.get('value', '')}".strip())
            found.append(
                {
                    "via": str(nb.get("via", "LLDP")),
                    "name": _val(ch.get("name")) or _val(ch.get("id")),
                    "descr": _val(ch.get("descr")),
                    "mgmt": [_val(m) for m in _items(ch.get("mgmt-ip"))],
                    "port": _val(port.get("id")),
                    "port_type": str(_first(port.get("id")).get("type", "")),
                    "port_descr": _val(port.get("descr")),
                    "vlans": vlans,
                    "raw": flatten(nb),
                }
            )
    return found


def port_name(nb):
    """-> (the port as a person would name it, the rest). UniFi gateways send
    the port's MAC as its ID and the usable name ("eth3") as the description;
    switches usually send the name as the ID."""
    if nb["port_type"] == "mac" and nb["port_descr"]:
        return nb["port_descr"], nb["port"]
    return nb["port"], nb["port_descr"] if nb["port_descr"] != nb["port"] else ""


def switch():
    """What the far end says about itself. `wait` until something is heard:
    LLDP is only sent every 30 s (CDP every 60), so the caller polls."""
    rc, out, err = run(
        ["lldpcli", "-f", "json0", "show", "neighbors", "details", "ports", IFACE], root=True
    )
    if rc != 0:
        msg = (err.strip() or "lldpcli failed").splitlines()[-1]
        return res("off", "LLDP unavailable", [msg], [("lldpcli", msg)])
    try:
        nbs = parse_lldp(json.loads(out))
    except (ValueError, AttributeError, TypeError) as e:
        return res("off", "LLDP parse error", [str(e)], [("raw", out[:2000])])
    if not nbs:
        return res("wait", "Listening...", ["LLDP/CDP: up to 60 s"])

    nb = nbs[0]
    port, port_extra = port_name(nb)
    lines = [
        f"port {port}" + (f" · {port_extra}" if port_extra else ""),
        f"mgmt {', '.join(nb['mgmt'])}" if nb["mgmt"] else "",
        f"vlan {', '.join(nb['vlans'])}" if nb["vlans"] else "",
        # One line: a Cisco description runs to several, and a tile must not grow.
        f"+{len(nbs) - 1} more neighbor(s)" if len(nbs) > 1 else " ".join(nb["descr"].split()),
    ]
    details = []
    for n in nbs:
        details += [
            ("neighbor", f"{n['name']} ({n['via']})"),
            ("port", " · ".join(x for x in port_name(n) if x)),
            ("mgmt ip", ", ".join(n["mgmt"])),
            ("vlans", ", ".join(n["vlans"])),
            ("description", n["descr"]),
        ]
        details += n["raw"]
    data = {"name": nb["name"], "port": port, "mgmt": nb["mgmt"], "vlans": nb["vlans"]}
    # Keep False: "enabled False" on a capability is information.
    shown = [d for d in details if d[1] not in ("", None)]
    return res("ok", nb["name"] or "Unnamed switch", lines, shown, data)


def switch_silent():
    return res(
        "warn",
        "No LLDP/CDP heard",
        ["unmanaged switch, or LLDP is", "off on this port"],
    )


# --- tagged VLANs -------------------------------------------------------------


def vlans(seconds=8):
    """Listen for 802.1Q tags: an access port carries none, a trunk shows its
    tagged VLANs as soon as anything broadcasts on them."""
    rc, out, err = run(
        ["timeout", seconds, shutil.which("tcpdump") or "tcpdump"]
        + ["-i", IFACE, "-nn", "-e", "-l", "-c", "400", "vlan"],
        timeout=seconds + 5,
        root=True,
    )
    if rc not in (0, 124) and not out:
        msg = (err.strip() or "capture failed").splitlines()[-1]
        return res("off", "Capture unavailable", [msg], [("tcpdump", msg)])
    seen = {}
    for line in out.splitlines():
        m = re.search(r"vlan (\d+)", line)
        # VID 0 is an 802.1p priority tag on an untagged frame, not a VLAN.
        if m and int(m.group(1)):
            seen[int(m.group(1))] = seen.get(int(m.group(1)), 0) + 1
    if not seen:
        return res(
            "ok",
            "Untagged only",
            [f"no 802.1Q tags in {seconds} s", "looks like an access port"],
            [("tagged vlans", "none seen")],
        )
    ids = sorted(seen)
    return res(
        "ok",
        "Tagged: " + ", ".join(map(str, ids[:6])) + ("..." if len(ids) > 6 else ""),
        [f"{len(ids)} tagged VLAN(s): trunk port"]
        + [f"vlan {v}: {seen[v]} frames" for v in ids[:3]],
        [(f"vlan {v}", f"{seen[v]} frames in {seconds} s") for v in ids],
        {"tagged": ids},
    )


# --- address (DHCP lease) -----------------------------------------------------


def fmt_duration(seconds):
    try:
        s = int(seconds)
    except (TypeError, ValueError):
        return str(seconds)
    if s >= 86400:
        return f"{s / 86400:g} d"
    if s >= 3600:
        return f"{s / 3600:g} h"
    return f"{s // 60} min"


def address():
    rc, out, err = run(
        ["nmcli", "-t", "-e", "no", "-f", "GENERAL,IP4,IP6,DHCP4", "device", "show", IFACE]
    )
    if rc != 0:
        return res("off", "NetworkManager?", [(err.strip() or "nmcli failed").splitlines()[-1]])
    f = {}
    for line in out.splitlines():
        k, _, v = line.partition(":")
        f.setdefault(re.sub(r"\[\d+\]$", "", k), []).append(v)
    state = (f.get("GENERAL.STATE") or ["0"])[0]
    try:
        code = int(state.split()[0])
    except ValueError:
        code = 0
    opts = {}
    for o in f.get("DHCP4.OPTION", []):
        k, _, v = o.partition(" = ")
        opts[k] = v

    ips = f.get("IP4.ADDRESS", [])
    profile = (f.get("GENERAL.CONNECTION") or [""])[0]
    port_mode = mode_of(profile)
    details = [("state", state), ("profile", profile), ("mode", port_mode)]
    # Still activating, even if an address is already there: the routing rule
    # scout mode depends on is only in place once NetworkManager says "connected".
    if 40 <= code < 100:
        return res("wait", "Getting address...", [state], details, {"mode": port_mode})
    if not ips:
        lines = [state, "no DHCP answer on this port?"]
        return res("bad", "No address", lines, details, {"mode": port_mode})

    iface = ipaddress.ip_interface(ips[0])
    gw = (f.get("IP4.GATEWAY") or [""])[0]
    if not gw:
        # Scout keeps the default route in its own table, and NetworkManager
        # only reports a gateway for the main one.
        for route in f.get("IP4.ROUTE", []):
            m = re.match(r"dst = 0\.0\.0\.0/0, nh = ([\d.]+)", route)
            if m and m.group(1) != "0.0.0.0":
                gw = m.group(1)
                break
        gw = gw or opts.get("routers", "").split(" ")[0]
    # ...and it leaves the lease's DNS out of its own configuration there.
    dns = f.get("IP4.DNS", []) or opts.get("domain_name_servers", "").split()
    domain = ", ".join(f.get("IP4.DOMAIN", [])) or opts.get("domain_name", "")
    server = opts.get("dhcp_server_identifier", "")

    status = "ok"
    lines = [f"gw {gw}" if gw else "no gateway", f"dns {' '.join(dns)}" if dns else "no DNS"]
    if iface.ip.is_link_local:
        status = "bad"
        lines.insert(0, "link-local: DHCP failed")
    elif not gw or not dns:
        status = "warn"
    if server:
        lines.append(f"lease {fmt_duration(opts.get('dhcp_lease_time'))} from {server}")
    else:
        lines.append("static (no DHCP lease)")
    lines.append(domain)

    details += [("address", a) for a in ips]
    details += [("gateway", gw), ("dns", ", ".join(dns)), ("domain", domain)]
    details += [("route", r) for r in f.get("IP4.ROUTE", [])]
    details += [("ipv6", a) for a in f.get("IP6.ADDRESS", [])]
    details += [("ipv6 gateway", g) for g in f.get("IP6.GATEWAY", []) if g]
    # "requested_x = 1" only lists what the client asked for.
    details += sorted((k, v) for k, v in opts.items() if not k.startswith("requested_"))
    try:
        obtained = int(opts["expiry"]) - int(opts["dhcp_lease_time"])
    except (KeyError, ValueError):
        obtained = None  # static address or infinite lease
    data = {
        "ip": str(iface.ip),
        "network": str(iface.network),
        "prefix": iface.network.prefixlen,
        "gateway": gw,
        "dns": dns,
        "dhcp_server": server,
        "obtained": obtained,
        "mode": port_mode,
    }
    return res(status, str(iface), lines, [d for d in details if d[1]], data)


def dhcp_probe():
    """Active: broadcast a DHCP discover and list every server that answers."""
    # Ask as ourselves. The script's default is a made-up client MAC, which
    # DHCP snooping drops and which gets offered some other client's address.
    mac = sysfs("address")
    args = ["--script-args", f"broadcast-dhcp-discover.mac={mac}"] if mac else []
    rc, out, err = run(
        ["nmap", "--script", "broadcast-dhcp-discover", *args, "-e", IFACE], timeout=40, root=True
    )
    offers = []
    for block in re.split(r"Response \d+ of \d+", out)[1:]:
        # nmap marks the last line of a script's output "|_" instead of "| ".
        offers.append(dict(re.findall(r"\|[_ ]\s*([A-Za-z][A-Za-z ()/-]+): (.*)", block)))
    if not offers:
        # nmap always grumbles on stderr here; it only matters if it failed.
        if rc != 0:
            msg = (err.strip() or "nmap failed").splitlines()[-1]
            return res("off", "Probe unavailable", [msg], [("nmap", msg)])
        return res("warn", "No offers", ["no DHCP server answered"])
    servers = sorted({o.get("Server Identifier", "?") for o in offers})
    details = []
    for o in offers:
        details += [("offer from", o.get("Server Identifier", "?"))] + sorted(o.items())
    return res(
        "ok" if len(servers) == 1 else "warn",
        f"{len(servers)} DHCP server(s)",
        (["more than one server answered"] if len(servers) > 1 else [])
        + [f"{o.get('Server Identifier', '?')} offers {o.get('IP Offered', '?')}" for o in offers],
        details,
        {"servers": servers},
    )


# --- path (gateway / DNS / internet) ------------------------------------------


def ping(target, count=3, extra=()):
    """-> (loss %, average ms or None), out of the wired interface."""
    cmd = ["ping", "-I", IFACE, "-n", "-c", count, "-i", "0.2", "-W", "1", *extra, target]
    _, out, _ = run(cmd, timeout=10)
    loss = re.search(r"([\d.]+)% packet loss", out)
    rtt = re.search(r"= [\d.]+/([\d.]+)/", out)
    return (float(loss.group(1)) if loss else 100.0, float(rtt.group(1)) if rtt else None)


def a_records(reply, offset):
    """The A records of a DNS reply whose question ends at `offset`."""
    out = []
    try:
        (count,) = struct.unpack(">H", reply[6:8])
        for _ in range(count):
            while reply[offset] and reply[offset] < 0xC0:
                offset += reply[offset] + 1
            offset += 1 if reply[offset] == 0 else 2
            rtype, _, _, rdlen = struct.unpack(">HHIH", reply[offset : offset + 10])
            offset += 10
            if rtype == 1 and rdlen == 4:
                out.append(socket.inet_ntoa(reply[offset : offset + 4]))
            offset += rdlen
    except (IndexError, struct.error):
        pass
    return out


def dns_query(server, source, name=CHECK_HOST, timeout=2.0):
    """One A lookup out of the wired interface -> (answered, ms, addresses).

    Not `dig -b`: that only sets the source address, and the kernel still
    routes by destination, so a resolver inside the Wi-Fi's subnet would be
    asked over Wi-Fi."""
    query = os.urandom(2) + struct.pack(">HHHHH", 0x0100, 1, 0, 0, 0)
    query += b"".join(bytes([len(p)]) + p.encode() for p in name.split("."))
    query += b"\0" + struct.pack(">HH", 1, 1)
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, IFACE.encode() + b"\0")
            s.bind((source, 0))
            s.settimeout(timeout)
            s.connect((server, 53))
            t0 = time.monotonic()
            s.send(query)
            while True:
                reply = s.recv(1500)
                if len(reply) >= 12 and reply[:2] == query[:2] and reply[2] & 0x80:
                    ms = (time.monotonic() - t0) * 1000
                    return reply[3] & 0x0F == 0, ms, a_records(reply, len(query))
    except (OSError, ValueError):
        return False, None, []


def fmt_ms(ms):
    return "-" if ms is None else f"{ms:.1f} ms" if ms < 10 else f"{ms:.0f} ms"


def path(addr):
    """Gateway, DNS and internet, in that order, so the first failure is the
    one to chase. `addr` is address()['data']."""
    ip, gw = addr.get("ip"), addr.get("gateway")
    status, lines, details = "ok", [], []

    def worse(new):
        nonlocal status
        order = ["ok", "warn", "bad"]
        if order.index(new) > order.index(status):
            status = new

    gw_ok = False
    if gw:
        loss, rtt = ping(gw)
        gw_ok = loss < 100
        lines.append(f"gw   {gw}  {fmt_ms(rtt) if gw_ok else 'no reply'}")
        details.append(("gateway", f"{gw}: {fmt_ms(rtt)}, {loss:g}% loss"))
        if loss > 0:
            worse("warn")
    else:
        lines.append("gw   none")
        worse("bad")

    dns_ok = False
    resolved = []
    for server in addr.get("dns", [])[:2]:
        good, ms, answers = dns_query(server, ip)
        dns_ok = dns_ok or good
        resolved = resolved or answers
        answer = fmt_ms(ms) if good else "failed"
        if not dns_ok or len(lines) < 2:
            lines.append(f"dns  {server}  {answer}")
        details.append(("dns", f"{server}: {answer}"))
        if not good:
            worse("warn")
    if not dns_ok:
        worse("bad")

    # curl binds its connection to the port but resolves names through the
    # system resolver, which in scout mode is Wi-Fi's: hand it this port's own
    # answer, or with none fall back to an address that needs no lookup.
    if resolved:
        target = ["--resolve", f"{CHECK_HOST}:80:{resolved[0]}", f"http://{CHECK_HOST}/generate_204"]
    else:
        target = ["https://1.1.1.1/cdn-cgi/trace"]
    rc, out, _ = run(
        ["curl", "--interface", IFACE, "-s", "-m", "6", "-o", "/dev/null"]
        + ["-w", "%{http_code} %{time_total}"]
        + target,
        timeout=10,
    )
    if not resolved and out.startswith("200 "):
        out = "204" + out[3:]  # reached the internet; only the port's DNS is at fault
    code, _, secs = out.partition(" ")
    if rc == 0 and code == "204":
        headline = f"Online · {fmt_ms(float(secs) * 1000)}"
        details.append(("internet", f"HTTP 204 in {fmt_ms(float(secs) * 1000)}"))
        _, trace, _ = run(
            ["curl", "--interface", IFACE, "-s", "-m", "6", "https://1.1.1.1/cdn-cgi/trace"],
            timeout=10,
        )
        t = dict(x.split("=", 1) for x in trace.splitlines() if "=" in x)
        if t.get("ip"):
            lines.append(f"wan  {t['ip']}  {t.get('colo', '')}")
            details += [("public ip", t["ip"]), ("cloudflare pop", t.get("colo", ""))]
        # 1472 + 28 header bytes = a full 1500-byte frame that may not fragment.
        if ping("1.1.1.1", 1, ["-M", "do", "-s", "1472"])[0] == 0:
            details.append(("path mtu", "1500 ok"))
        elif ping("1.1.1.1", 1)[0] == 0:
            lines.append("path MTU below 1500")
            details.append(("path mtu", "below 1500 (full-size frame dropped)"))
            worse("warn")
    elif rc == 0 and code not in ("", "000"):
        headline = "Captive portal?"
        lines.append(f"web check got HTTP {code}, not 204")
        details.append(("internet", f"HTTP {code} (expected 204)"))
        worse("warn")
    else:
        headline = "No internet" if gw_ok else "Gateway unreachable"
        details.append(("internet", "no answer"))
        worse("bad")
    return res(status, headline, lines, details)


def speed(addr):
    """Active: iperf3 both ways against PORTSCOUT_IPERF_SERVER."""
    if not IPERF_SERVER:
        return res("off", "No iperf3 server", ["set iperfServer in", "portscout/default.nix"])
    rates = {}
    for label, flag in (("up", []), ("down", ["-R"])):
        rc, out, err = run(
            ["iperf3", "-c", IPERF_SERVER, "-B", addr.get("ip", ""), "--bind-dev", IFACE]
            + ["-t", "5", "-J"]
            + flag,
            timeout=20,
        )
        try:
            doc = json.loads(out)
            rates[label] = doc["end"]["sum_received"]["bits_per_second"] / 1e6
        except (ValueError, KeyError):
            msg = err.strip() or "iperf3 failed"
            try:
                msg = json.loads(out).get("error", msg)
            except ValueError:
                pass
            return res("bad", "Speed test failed", [str(msg)], [("iperf3", msg)])
    return res(
        "ok",
        f"up {rates['up']:.0f} / down {rates['down']:.0f} Mb/s",
        [f"iperf3 to {IPERF_SERVER}, 5 s each way"],
        [("server", IPERF_SERVER)] + [(k, f"{v:.1f} Mb/s") for k, v in rates.items()],
        rates,
    )


# --- neighbors ----------------------------------------------------------------


def neighbors(addr):
    """Active: ARP-sweep the segment."""
    target = "--localnet"
    note = ""
    if addr.get("prefix", 24) < MAX_SWEEP_PREFIX and addr.get("ip"):
        target = str(ipaddress.ip_network(f"{addr['ip']}/24", strict=False))
        note = f"/{addr['prefix']} is huge: swept {target} only"
    vendors = [f"--macfile={OUI_FILE}"] if os.path.isfile(OUI_FILE) else []
    rc, out, err = run(
        ["arp-scan", "-I", IFACE, "-x", "-r", "2", *vendors, target], timeout=60, root=True
    )
    # Our other interfaces answer too when they sit on this same segment.
    own = {}
    for name in os.listdir("/sys/class/net"):
        try:
            with open(f"/sys/class/net/{name}/address") as f:
                own[f.read().strip().lower()] = name
        except OSError:
            pass
    hosts = {}
    for line in out.splitlines():
        m = re.match(r"^(\d+\.\d+\.\d+\.\d+)\t([0-9a-fA-F:]{17})\t?(.*)$", line)
        if m:
            mac = m.group(2).lower()
            vendor = f"this device ({own[mac]})" if mac in own else m.group(3).strip()
            hosts.setdefault(m.group(1), (mac, vendor))
    if rc != 0 and not hosts:
        msg = (err.strip() or "arp-scan failed").splitlines()[-1]
        return res("off", "Sweep unavailable", [msg], [("arp-scan", msg)])
    ordered = sorted(hosts, key=ipaddress.ip_address)
    return res(
        "ok",
        f"{len(ordered)} host(s)",
        ([note] if note else []) + [f"{ip}  {hosts[ip][1][:18]}" for ip in ordered[:4]],
        [(ip, f"{hosts[ip][0]}  {hosts[ip][1]}") for ip in ordered],
        {"hosts": [{"ip": ip, "mac": hosts[ip][0], "vendor": hosts[ip][1]} for ip in ordered]},
    )


# --- CLI ----------------------------------------------------------------------

PASSIVE = ["link", "switch", "vlans", "address", "path"]
ACTIVE = ["neighbors", "dhcp_probe", "speed"]


def run_check(name, addr=None):
    if name in ("path", "neighbors", "speed"):
        addr = addr if addr is not None else address()["data"]
        if not addr.get("ip"):
            return res("off", "No address", ["needs an IP on " + IFACE])
        return globals()[name](addr)
    return globals()[name]()


def main():
    if sys.argv[1:2] == ["mode"]:
        if sys.argv[2:3] and sys.argv[2] in PROFILES:
            ok, msg = set_mode(sys.argv[2])
            if not ok:
                sys.exit(msg or "could not switch")
        elif sys.argv[2:]:
            sys.exit("usage: portscout mode [scout|live]")
        print(mode())
        return
    ap = argparse.ArgumentParser(
        prog="portscout",
        description=f"Diagnose the Ethernet port {IFACE} is plugged into. "
        f"With no checks named, runs the passive ones: {' '.join(PASSIVE)}. "
        "'portscout mode [scout|live]' shows or switches how the port is used.",
    )
    ap.add_argument("checks", nargs="*", metavar="check")
    ap.add_argument("--active", action="store_true", help=f"also run: {' '.join(ACTIVE)}")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    names = args.checks or PASSIVE + (ACTIVE if args.active else [])
    unknown = [n for n in names if n not in PASSIVE + ACTIVE]
    if unknown:
        ap.error(f"unknown check: {' '.join(unknown)} (have: {' '.join(PASSIVE + ACTIVE)})")
    results = {}
    for name in names:
        if name != "link" and not carrier():
            results[name] = res("off", "No link")
        else:
            results[name] = run_check(name)
        if not args.json:
            r = results[name]
            print(f"{name.upper():<11}[{r['status']}] {r['headline']}")
            for line in r["lines"]:
                print(f"{'':<11}{line}")
    if args.json:
        json.dump(results, sys.stdout, indent=2)
        print()


if __name__ == "__main__":
    main()
