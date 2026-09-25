# Quick menus

rofi menus, single-tap to pick. Same hotkey again closes the menu. Also on the
Waybar widgets. Each is a command too (`netmenu`, `btmenu`, `volmenu`,
`powermenu`, `toolmenu`).

| Keys | Menu |
|------|------|
| `Super+w` | Wi-Fi: join / disconnect / rescan / radio toggle / nmtui |
| `Super+b` | Bluetooth: power / scan / pair / connect / trust / remove |
| `Super+v` | Volume: mute / levels / output device / mic mute |
| `Super+Shift+e` | Power: lock / log out / reboot / off / battery saver |
| `Super+t` | Field tools (opens in a terminal) |

## Wi-Fi from the shell

    nmcli device wifi list                          # scan
    nmcli --ask device wifi connect "SSID"          # join (prompts password)
    nmcli device wifi connect "SSID" password "PW"  # join non-interactively
    nmcli connection show --active                  # what's connected
    nmcli device disconnect wld0                    # drop the built-in radio
    nmcli connection delete "SSID"                  # forget a network
    nmcli radio wifi off                            # kill / restore the radio
    nmtui                                           # full-screen TUI

## Bluetooth from the shell

    bluetoothctl power on
    bluetoothctl scan on            # let it run a few seconds, Ctrl-C to stop
    bluetoothctl devices            # list seen devices + MACs
    bluetoothctl pair    AA:BB:CC:DD:EE:FF
    bluetoothctl trust   AA:BB:CC:DD:EE:FF
    bluetoothctl connect AA:BB:CC:DD:EE:FF
    bluetoothctl remove  AA:BB:CC:DD:EE:FF

## Volume from the shell

    wpctl status                                    # list sinks / sources
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 40%
    wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle
    wpctl set-default <id>                          # switch output (id from status)
    pavucontrol                                     # full mixer GUI
