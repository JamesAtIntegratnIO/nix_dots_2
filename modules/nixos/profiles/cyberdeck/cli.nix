# The cyberdeck look for command-line tools, as plain values shared by every
# host: ../../../home/cyberdeck.nix applies them through Home Manager (the Mac
# and the laptop) and ./terminal.nix system-wide (the PocketTerm, which has no
# Home Manager). Everything here names the 16 ANSI slots, and each terminal
# maps those to ./palette.nix, so nothing below hardcodes hex.
let
  join = builtins.concatStringsSep;

  # One LS_COLORS entry per extension.
  exts = code: names: map (e: "*.${e}=${code}") names;
in
rec {
  # fzf: Ctrl-R history, Ctrl-T files, Alt-C dirs; compact, no box.
  fzfOptions = [
    "--height=60% --layout=reverse --info=inline-right --no-scrollbar"
    "--prompt='❯ ' --pointer='▌' --marker='+'"
    "--color=fg:7,bg:-1,hl:6,fg+:15,bg+:0,hl+:14"
    "--color=info:8,prompt:2,pointer:6,marker:5,spinner:5,header:4,border:8,gutter:-1"
  ];

  # man pages through less with color: bold -> cyan, underline -> magenta.
  manpager = "less -R --use-color -Dd+c -Du+m";

  # One-line tmux status bar; statusRight is what sits left of the clock.
  tmuxLook = statusRight: ''
    set -g status-position bottom
    set -g status-style "bg=default,fg=colour8"
    set -g status-left "#[fg=colour0,bg=colour6,bold] #S #[default] "
    set -g status-left-length 20
    set -g status-right "${statusRight}#[fg=colour3]%H:%M"
    set -g window-status-format "#[fg=colour8] #I:#W "
    set -g window-status-current-format "#[fg=colour6,bold] #I:#W "
    set -g pane-border-style "fg=colour0"
    set -g pane-active-border-style "fg=colour6"
    set -g message-style "fg=colour2,bg=default"
    set -g mode-style "fg=colour0,bg=colour6"
  '';

  # File listings, read by GNU ls and eza alike: directories cyan, links
  # magenta, executables green, as in the prompt. Sticky and world-writable
  # directories stay plain cyan instead of ls's default green blocks.
  lsColors = join ":" (
    [
      "di=36"
      "ln=35"
      "or=31"
      "mi=31"
      "ex=32"
      "so=33"
      "pi=33"
      "bd=33"
      "cd=33"
      "su=31"
      "sg=31"
      "st=36"
      "tw=36"
      "ow=36"
    ]
    # archives and images of disks
    ++ exts "33" [
      "tar"
      "tgz"
      "gz"
      "bz2"
      "xz"
      "zst"
      "zip"
      "7z"
      "rar"
      "iso"
      "img"
      "dmg"
    ]
    # pictures, audio, video
    ++ exts "95" [
      "png"
      "jpg"
      "jpeg"
      "gif"
      "webp"
      "svg"
      "ico"
      "mp3"
      "flac"
      "ogg"
      "wav"
      "mp4"
      "mkv"
      "webm"
      "mov"
    ]
    # configuration and data
    ++ exts "94" [
      "nix"
      "json"
      "yaml"
      "yml"
      "toml"
      "ini"
      "conf"
      "lock"
    ]
    # prose
    ++ exts "37" [
      "md"
      "txt"
      "pdf"
    ]
    # leftovers
    ++ exts "90" [
      "bak"
      "tmp"
      "swp"
      "orig"
      "log"
    ]
  );

  # The columns only eza draws: permissions, size, owner, date, git status.
  # Metadata is dim so the names carry the color.
  ezaColors = join ":" [
    "ur=37:uw=37:ux=32:ue=32"
    "gr=90:gw=90:gx=90:tr=90:tw=90:tx=90"
    "sn=36:sb=90"
    "uu=90:uR=31:un=33:gu=90:gR=31:gn=33"
    "da=90:in=90:bl=90:lc=90:xx=90:hd=4;90"
    "lp=35"
    "ga=32:gm=33:gd=31:gv=36:gt=35"
  ];

  # The prompt is starship on every host. The Mac and the laptop get all of
  # its modules (language versions, git status, command duration, ...) with
  # the deck's colors on the parts the hosts share. Starship calls ANSI
  # magenta "purple".
  starship = {
    username = {
      style_user = "yellow";
      style_root = "red";
    };
    hostname.style = "yellow";
    directory.style = "cyan";
    git_branch.style = "purple";
    character = {
      success_symbol = "[❯](green)";
      error_symbol = "[❯](red)";
    };
  };

  # The PocketTerm's 640x480 panel is 64 columns wide, so its prompt is cut
  # down to one short line:
  #   [user@host ]some/dir[ branch] ❯
  # user@host only over SSH (and "root" whenever it is root); the arrow turns
  # red after a failed command.
  starshipCompact = {
    add_newline = false;
    format = "($username$hostname )$directory$git_branch$character";
    username = starship.username // {
      format = "[$user]($style)";
    };
    hostname = starship.hostname // {
      ssh_only = true;
      format = "[@$hostname]($style)";
    };
    directory = starship.directory // {
      format = "[$path]($style)";
      truncation_length = 2;
      truncate_to_repo = false;
    };
    git_branch = starship.git_branch // {
      format = " [$branch]($style)";
    };
    character = starship.character // {
      format = " $symbol ";
    };
  };
}
