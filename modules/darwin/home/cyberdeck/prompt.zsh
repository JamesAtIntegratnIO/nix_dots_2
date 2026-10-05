# Cyberdeck zsh prompt, the deck's bash prompt (cyberdeck/prompt.bash) in zsh:
#   [user@host ]some/dir branch ❯
# user@host only over SSH; the arrow turns red after a failed command and
# becomes "#" for root. Colors are ANSI slots, so the terminal's palette applies.
__deck_prompt() {
  local st=$? host="" branch arrow

  [[ -n $SSH_CONNECTION ]] && host="%F{yellow}%n@%m%f "
  branch=$(git symbolic-ref --short -q HEAD 2>/dev/null) && branch=" %F{magenta}${branch//\%/%%}%f"

  if (( EUID == 0 )); then
    arrow="%F{red}#"
  elif (( st != 0 )); then
    arrow="%F{red}❯"
  else
    arrow="%F{green}❯"
  fi

  PROMPT="${host}%F{cyan}%2~%f${branch} ${arrow}%f "
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd __deck_prompt
