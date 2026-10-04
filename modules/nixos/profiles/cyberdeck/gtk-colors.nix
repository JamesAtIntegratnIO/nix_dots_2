# libadwaita's named colors in the cyberdeck palette. adw-gtk3 (GTK3) and
# libadwaita (GTK4) both draw everything from these, so redefining them is the
# whole recolor.
p: ''
  @define-color accent_color #${p.cyan};
  @define-color accent_bg_color #${p.cyan};
  @define-color accent_fg_color #${p.void};
  @define-color destructive_color #${p.red};
  @define-color destructive_bg_color #${p.red};
  @define-color success_color #${p.green};
  @define-color warning_color #${p.amber};
  @define-color error_color #${p.red};
  @define-color window_bg_color #${p.base};
  @define-color window_fg_color #${p.text};
  @define-color view_bg_color #${p.void};
  @define-color view_fg_color #${p.text};
  @define-color headerbar_bg_color #${p.mantle};
  @define-color headerbar_fg_color #${p.text};
  @define-color headerbar_backdrop_color #${p.base};
  @define-color sidebar_bg_color #${p.mantle};
  @define-color sidebar_fg_color #${p.text};
  @define-color card_bg_color #${p.mantle};
  @define-color card_fg_color #${p.text};
  @define-color popover_bg_color #${p.mantle};
  @define-color popover_fg_color #${p.text};
  @define-color dialog_bg_color #${p.mantle};
  @define-color dialog_fg_color #${p.text};
''
