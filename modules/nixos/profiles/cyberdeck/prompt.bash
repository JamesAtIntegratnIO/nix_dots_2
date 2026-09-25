# Cyberdeck bash prompt: one line to save vertical space on the 640x480 panel.
#   [user@host ]~/some/dir branch ❯
# user@host only over SSH; the arrow turns red after a failed command and
# becomes "#" for root. Colors are ANSI slots, so foot/console palettes apply.
__deck_prompt() {
  local status=$?
  local r='\[\e[0m\]' cyan='\[\e[36m\]' magenta='\[\e[35m\]' green='\[\e[32m\]'
  local red='\[\e[31m\]' amber='\[\e[33m\]'
  local host="" branch arrow

  [ -n "$SSH_CONNECTION" ] && host="${amber}\u@\h${r} "
  branch=$(git symbolic-ref --short -q HEAD 2>/dev/null) && branch=" ${magenta}${branch}${r}"

  if [ "$EUID" -eq 0 ]; then
    arrow="${red}#"
  elif [ "$status" -ne 0 ]; then
    arrow="${red}❯"
  else
    arrow="${green}❯"
  fi

  PS1="${host}${cyan}\w${r}${branch} ${arrow}${r} "
}

PROMPT_DIRTRIM=2
PROMPT_COMMAND="__deck_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
