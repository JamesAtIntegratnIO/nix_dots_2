# The Hyprland session (modules/nixos/profiles/hyprland.nix puts it on the
# login screen): the cyberdeck palette, wallpaper and fonts of the Cinnamon
# desktop, on a compositor where each monitor has its own workspaces.
#
# Only ~/.config/hypr/hyprland.lua lands in the home directory. The bar,
# notifications, idle daemon and lock screen are started from it with their
# configs passed as store paths, so none of them can leak into Cinnamon.
#
# Hyprland 0.56 is configured in Lua. `Hyprland --verify-config -c <file>`
# checks a config without a running session.
{
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  p = import ../../modules/nixos/profiles/cyberdeck/palette.nix;
  font = "JetBrainsMono Nerd Font";
  host = osConfig.networking.hostName;
  wallpaper = osConfig.services.xserver.displayManager.lightdm.background;

  # Nerd Font glyph from its codepoint, as in the PocketTerm's bar: a JSON
  # escape, so the Private Use Area characters can't be stripped from the
  # source.
  icon = code: builtins.fromJSON ''"\${code}"'';
  i = {
    nixos = icon "uf313";
    wifi = icon "uf1eb";
    ethernet = icon "uf0e8";
    offline = icon "uf127";
    volOff = icon "uf026";
    volLow = icon "uf027";
    volHigh = icon "uf028";
    sun = icon "uf185";
    bolt = icon "uf0e7";
    battery = map icon [
      "uf244"
      "uf243"
      "uf242"
      "uf241"
      "uf240"
    ];
  };

  # --- Idle and lock ----------------------------------------------------------
  # The same policy as the Cinnamon session (cinnamon.nix): on battery the
  # panels go dark at 5 minutes and the laptop sleeps at 15; on AC it locks at
  # 15 and the panels go dark at 30. The lid is logind's, in
  # modules/nixos/profiles/laptop.nix, whatever the session.
  onBattery = pkgs.writeShellScript "on-battery" ''
    for supply in /sys/class/power_supply/*; do
      if [[ $(<"$supply/type") == Mains && $(<"$supply/online") == 1 ]]; then
        exit 1
      fi
    done
  '';
  lock = pkgs.writeShellScript "hypr-lock" ''
    ${pkgs.procps}/bin/pgrep -x hyprlock >/dev/null || exec hyprlock -c ${hyprlockConfig}
  '';
  panels = state: "${pkgs.wlopm}/bin/wlopm --${state} '*'";

  hypridleConfig = pkgs.writeText "hypridle.conf" ''
    general {
      lock_cmd = ${lock}
      before_sleep_cmd = loginctl lock-session
      after_sleep_cmd = ${panels "on"}
    }
    listener {
      timeout = 300
      on-timeout = ${onBattery} && ${panels "off"}
      on-resume = ${panels "on"}
    }
    listener {
      timeout = 900
      on-timeout = loginctl lock-session
    }
    # An hour into the suspend it hibernates, as a closed lid does.
    listener {
      timeout = 900
      on-timeout = ${onBattery} && systemctl suspend-then-hibernate
    }
    listener {
      timeout = 1800
      on-timeout = ${panels "off"}
      on-resume = ${panels "on"}
    }
  '';

  hyprlockConfig = pkgs.writeText "hyprlock.conf" ''
    general {
      hide_cursor = true
    }
    background {
      monitor =
      path = ${wallpaper}
      blur_passes = 2
      brightness = 0.5
    }
    label {
      monitor =
      text = $TIME
      font_family = ${font} Bold
      font_size = 64
      color = rgb(${p.amber})
      position = 0, 110
      halign = center
      valign = center
    }
    label {
      monitor =
      text = ${lib.toUpper host} // AUTHORIZED USE ONLY
      font_family = ${font}
      font_size = 13
      color = rgb(${p.subtext})
      position = 0, 30
      halign = center
      valign = center
    }
    input-field {
      monitor =
      size = 320, 48
      rounding = 0
      outline_thickness = 2
      outer_color = rgb(${p.cyan})
      inner_color = rgb(${p.base})
      font_color = rgb(${p.text})
      check_color = rgb(${p.blue})
      fail_color = rgb(${p.red})
      placeholder_text =
      fade_on_empty = false
      position = 0, -50
      halign = center
      valign = center
    }
  '';

  # --- Bar --------------------------------------------------------------------
  # One per monitor, each listing only its own monitor's workspaces.
  waybarConfig = pkgs.writeText "waybar-config" (
    builtins.toJSON {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 0;
      modules-left = [
        "custom/logo"
        "hyprland/workspaces"
        "hyprland/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "network"
        "wireplumber"
        "backlight"
        "battery"
      ];
      "custom/logo" = {
        format = i.nixos;
        tooltip = false;
        on-click = "launcher";
      };
      "hyprland/workspaces" = {
        format = "{id}";
        all-outputs = false;
      };
      "hyprland/window" = {
        max-length = 60;
        separate-outputs = true;
      };
      clock = {
        format = "{:%H:%M  %a %d}";
        tooltip-format = "{:%A %B %d %Y}";
      };
      tray.spacing = 8;
      network = {
        format-wifi = "${i.wifi} {signalStrength}";
        format-ethernet = "${i.ethernet} {ipaddr}";
        format-disconnected = "${i.offline} off";
        tooltip-format = "{ifname}: {essid} {ipaddr}";
      };
      wireplumber = {
        format = "{icon} {volume}";
        format-muted = "${i.volOff} --";
        format-icons = [
          i.volOff
          i.volLow
          i.volHigh
        ];
      };
      backlight.format = "${i.sun} {percent}";
      battery = {
        format = "{icon} {capacity}";
        format-charging = "${i.bolt} {capacity}";
        format-icons = i.battery;
        states = {
          warning = 20;
          critical = 10;
        };
      };
    }
  );

  waybarStyle = pkgs.writeText "waybar-style.css" ''
    * {
      font-family: "${font}", monospace;
      font-size: 13px;
      min-height: 0;
      border: none;
      border-radius: 0;
    }
    window#waybar {
      background: alpha(#${p.void}, 0.85);
      color: #${p.text};
      border-bottom: 1px solid alpha(#${p.cyan}, 0.35);
    }
    #custom-logo { color: #${p.cyan}; padding: 0 10px 0 12px; font-size: 15px; }
    #workspaces button {
      padding: 0 9px;
      color: #${p.overlay};
      background: transparent;
    }
    #workspaces button.visible { color: #${p.text}; }
    #workspaces button.active { background: #${p.cyan}; color: #${p.void}; font-weight: bold; }
    #workspaces button.urgent { background: #${p.magenta}; color: #${p.void}; }
    #workspaces button:hover { background: #${p.surface}; box-shadow: none; }
    #window { color: #${p.subtext}; padding: 0 12px; }
    #clock { color: #${p.amber}; font-weight: bold; letter-spacing: 1px; }
    #tray, #network, #wireplumber, #backlight, #battery { padding: 0 9px; }
    #network { color: #${p.cyan}; }
    #network.disconnected { color: #${p.overlay}; }
    #wireplumber { color: #${p.magenta}; }
    #wireplumber.muted { color: #${p.overlay}; }
    #backlight { color: #${p.amber}; }
    #battery { color: #${p.green}; padding-right: 12px; }
    #battery.warning { color: #${p.amber}; }
    #battery.critical { color: #${p.void}; background: #${p.red}; }
  '';

  makoConfig = pkgs.writeText "mako-config" ''
    font=${font} 11
    background-color=#${p.base}f2
    text-color=#${p.text}
    border-color=#${p.cyan}
    border-size=2
    border-radius=0
    padding=10,12
    margin=12
    width=360
    height=160
    icons=1
    max-icon-size=40
    default-timeout=5000
    format=<b><span foreground="#${p.cyan}">%s</span></b>\n%b

    [urgency=low]
    border-color=#${p.overlay}

    [urgency=critical]
    border-color=#${p.magenta}
    format=<b><span foreground="#${p.magenta}">%s</span></b>\n%b
    default-timeout=0
  '';

  screenshot = pkgs.writeShellScript "hypr-screenshot" ''
    ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.wl-clipboard}/bin/wl-copy
  '';

  # The PocketTerm's menu is 78% of a 640px panel; here it gets a fixed width.
  launcher = pkgs.writeShellScript "hypr-launcher" ''
    ${pkgs.procps}/bin/pkill -x rofi && exit 0
    exec rofi -config /etc/rofi/config.rasi -show drun -display-drun apps \
      -theme-str 'window { width: 640px; }'
  '';

  autostart = [
    # Lets portals and other D-Bus-activated services find the session.
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE"
    "${pkgs.swaybg}/bin/swaybg -i ${wallpaper} -m fill"
    "${pkgs.waybar}/bin/waybar -c ${waybarConfig} -s ${waybarStyle}"
    "${pkgs.mako}/bin/mako -c ${makoConfig}"
    "${pkgs.hypridle}/bin/hypridle -c ${hypridleConfig}"
    "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
    "nm-applet --indicator"
  ];
in
{
  # GTK apps on Wayland take their theme from these keys, where Cinnamon
  # pushes its own over XSETTINGS.
  dconf.settings."org/gnome/desktop/interface" = {
    gtk-theme = "Cyberdeck";
    icon-theme = "Papirus-Dark";
    cursor-theme = "Bibata-Modern-Classic";
    cursor-size = 24;
    color-scheme = "prefer-dark";
  };

  xdg.configFile."hypr/hyprland.lua".text = ''
    -- Generated by home/boboysdadda/hyprland.nix.

    ---- Monitors ----
    -- The laptop panel on the left; anything plugged in goes to its right, at
    -- the same 1x scale it has under Cinnamon.
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

    hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")

    hl.on("hyprland.start", function()
    ${lib.concatMapStringsSep "\n" (cmd: "  hl.exec_cmd(${builtins.toJSON cmd})") autostart}
    end)

    ---- Look ----
    hl.config({
      general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
          active_border = { colors = { "rgba(${p.cyan}ee)", "rgba(${p.magenta}ee)" }, angle = 45 },
          inactive_border = "rgba(${p.surface}ff)",
        },
        resize_on_border = true,
        layout = "dwindle",
      },
      decoration = {
        rounding = 6,
        shadow = { enabled = true, range = 12, render_power = 3, color = "rgba(${p.cyan}40)", color_inactive = "rgba(00000060)" },
        blur = { enabled = true, size = 5, passes = 2 },
      },
      animations = { enabled = true },
      dwindle = { preserve_split = true },
      misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = "rgb(${p.void})",
        focus_on_activate = true,
        key_press_enables_dpms = true,
        -- 0: a new window leaves a fullscreen one alone (the default takes
        -- it out of fullscreen). The window.open handler below finds the new
        -- window a workspace of its own.
        on_focus_under_fullscreen = 0,
        mouse_move_enables_dpms = true,
      },
      input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = true, tap_to_click = true },
      },
    })

    hl.curve("deck", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
    hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "deck", style = "popin 90%" })
    hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "deck" })
    hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "deck" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "deck", style = "slide" })

    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

    hl.window_rule({
      name = "suppress-maximize-events",
      match = { class = ".*" },
      suppress_event = "maximize",
    })

    ---- Spaces ----
    -- Workspaces belong to the monitor they were made on, and the keys below
    -- only ever act on the monitor that has focus, so the two screens switch
    -- independently.

    -- The lowest workspace number nothing is using. A workspace made by
    -- number opens on the focused monitor.
    local function free_workspace()
      local used = {}
      for _, ws in ipairs(hl.get_workspaces()) do
        used[ws.id] = true
      end
      local id = 1
      while used[id] do
        id = id + 1
      end
      return id
    end

    -- Super+F, as fullscreen-spaces does on Cinnamon: a window that shares
    -- its workspace goes fullscreen on a new one of its own, on the same
    -- monitor, and comes back to where it was when it leaves fullscreen.
    local origins = {} -- window address -> the workspace it came from

    local function toggle_space()
      local window = hl.get_active_window()
      if not window then
        return
      end
      if window.fullscreen ~= 0 then
        local origin = origins[window.address]
        origins[window.address] = nil
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset", window = window }))
        if origin then
          hl.dispatch(hl.dsp.window.move({ workspace = origin, window = window }))
        end
        return
      end
      local workspace = window.workspace
      if workspace and workspace.windows > 1 then
        origins[window.address] = workspace.id
        hl.dispatch(hl.dsp.window.move({ workspace = free_workspace(), window = window }))
      end
      hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set", window = window }))
    end

    -- Event handlers run unattended, so a failure shows up on screen instead
    -- of vanishing.
    local function guarded(name, handler)
      return function(...)
        local ok, err = pcall(handler, ...)
        if not ok then
          hl.notification.create({ text = name .. ": " .. tostring(err), timeout = 8000 })
        end
      end
    end

    -- An app launched while a fullscreen window has the workspace would tile
    -- unseen behind it. It opens on a new workspace instead, on the same
    -- monitor. Floating windows stay: they are the fullscreen app's dialogs.
    hl.on("window.open", guarded("window.open", function(window)
      local workspace = window.workspace
      if window.floating or not workspace then
        return
      end
      local fullscreen = workspace.fullscreen_window
      if not fullscreen or fullscreen.address == window.address then
        return
      end
      hl.dispatch(hl.dsp.window.move({ workspace = free_workspace(), window = window }))
      hl.dispatch(hl.dsp.focus({ window = window }))
    end))

    -- Closing a window in its own space would leave an empty workspace on
    -- screen; go back to the one it came from.
    hl.on("window.close", guarded("window.close", function(window)
      local origin = origins[window.address]
      if not origin then
        return
      end
      origins[window.address] = nil
      local space = window.workspace
      local active = hl.get_active_workspace()
      if space and active and space.id == active.id then
        hl.dispatch(hl.dsp.focus({ workspace = origin }))
      end
    end))

    local function other_monitor()
      local current = hl.get_active_monitor()
      for _, monitor in ipairs(hl.get_monitors()) do
        if current and monitor.id ~= current.id then
          return monitor
        end
      end
    end

    ---- Keys ----
    local mod = "SUPER"

    hl.bind(mod .. " + F", toggle_space)
    hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }))
    hl.bind(mod .. " + N", function()
      hl.dispatch(hl.dsp.focus({ workspace = free_workspace() }))
    end)

    -- The same keys as Cinnamon. m+1 and m-1 step through the workspaces of
    -- the focused monitor only.
    for _, keys in ipairs({ "CTRL", "CTRL + ALT", "CTRL + SUPER" }) do
      hl.bind(keys .. " + left", hl.dsp.focus({ workspace = "m-1" }))
      hl.bind(keys .. " + right", hl.dsp.focus({ workspace = "m+1" }))
    end
    hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
    hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "m-1" }))
    hl.bind(mod .. " + SHIFT + CTRL + left", hl.dsp.window.move({ workspace = "m-1" }))
    hl.bind(mod .. " + SHIFT + CTRL + right", hl.dsp.window.move({ workspace = "m+1" }))

    -- The other screen: focus it, or send the window to it.
    hl.bind(mod .. " + O", function()
      local monitor = other_monitor()
      if monitor then
        hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
      end
    end)
    hl.bind(mod .. " + SHIFT + O", function()
      local monitor = other_monitor()
      if monitor and monitor.active_workspace then
        hl.dispatch(hl.dsp.window.move({ workspace = monitor.active_workspace.id }))
      end
    end)

    hl.bind(mod .. " + Return", hl.dsp.exec_cmd("gnome-terminal"))
    hl.bind(mod .. " + D", hl.dsp.exec_cmd("${launcher}"))
    hl.bind(mod .. " + E", hl.dsp.exec_cmd("nemo"))
    hl.bind(mod .. " + Q", hl.dsp.window.close())
    hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
    hl.bind(mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
    hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
    hl.bind("Print", hl.dsp.exec_cmd("${screenshot}"))

    for _, direction in ipairs({ "left", "right", "up", "down" }) do
      hl.bind(mod .. " + " .. direction, hl.dsp.focus({ direction = direction }))
      hl.bind(mod .. " + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }))
    end

    hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    local held = { locked = true, repeating = true }
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), held)
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), held)
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${pkgs.brightnessctl}/bin/brightnessctl -e4 -n2 set 5%+"), held)
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${pkgs.brightnessctl}/bin/brightnessctl -e4 -n2 set 5%-"), held)
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl next"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl previous"), { locked = true })
  '';
}
