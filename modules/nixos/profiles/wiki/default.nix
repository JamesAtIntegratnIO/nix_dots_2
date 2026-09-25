# On-the-go offline reference for the PocketTerm35, rendered in the terminal.
#
# Pages are plain Markdown under ./pages, baked into the read-only Nix store at
# build time -- so there is NO server, NO daemon and NO container sitting idle
# draining the battery. `wiki` just reads store files with glow + fzf. Add or
# edit a page in ./pages and redeploy; the first `# Heading` is its title and
# the numeric filename prefix sets the order.
{ pkgs, ... }:

let
  pages = ./pages;

  wiki = pkgs.writeShellApplication {
    name = "wiki";
    runtimeInputs = with pkgs; [
      glow
      fzf
      ripgrep
      coreutils
      gnused
    ];
    text = ''
      wiki_dir=${pages}

      usage() {
        cat <<'EOF'
      pocketterm wiki -- offline reference

        wiki            browse every topic (type to filter, Enter reads, q quits)
        wiki <query>    open topics whose text matches <query>
        wiki ls         list topics
        wiki -h         this help
      EOF
      }

      # Emit "<title>\t<file>" for each given page, in argument order.
      index() {
        local f title
        for f in "$@"; do
          title=$(sed -n 's/^# //p' "$f" | head -1)
          printf '%s\t%s\n' "''${title:-$(basename "$f" .md)}" "$f"
        done
      }

      # Full-screen read with glow's built-in pager (auto-detects width).
      read_page() { glow -s dark -p "$1"; }

      # fzf picker over the given pages; Enter opens the choice.
      browse() {
        local sel
        # FZF_PREVIEW_COLUMNS is expanded by fzf inside the preview, not by us.
        # shellcheck disable=SC2016
        sel=$(index "$@" | fzf \
          --delimiter='\t' --with-nth=1 --no-multi --cycle \
          --prompt='wiki ❯ ' \
          --preview 'glow -s dark -w "''${FZF_PREVIEW_COLUMNS}" {2}' \
          --preview-window='up:55%:wrap') || return 0
        [ -n "$sel" ] || return 0
        read_page "$(printf '%s' "$sel" | cut -f2)"
      }

      case "''${1:-}" in
        "") browse "$wiki_dir"/*.md ;;
        ls) index "$wiki_dir"/*.md | cut -f1 ;;
        -h | --help | help) usage ;;
        *)
          mapfile -t hits < <(rg -ilF -- "$*" "$wiki_dir"/*.md 2>/dev/null || true)
          if [ "''${#hits[@]}" -eq 0 ]; then
            echo "wiki: nothing matches: $*  (try: wiki ls)" >&2
            exit 1
          elif [ "''${#hits[@]}" -eq 1 ]; then
            read_page "''${hits[0]}"
          else
            browse "''${hits[@]}"
          fi
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ wiki ];
}
