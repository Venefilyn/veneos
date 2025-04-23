#!/usr/bin/env sh

# Determine shell
[ -n "$BASH_VERSION" ] && shell="bash"
[ -n "$ZSH_VERSION" ] && shell="zsh"

# Common tool initialization
ATUIN_INIT_FLAGS=${ATUIN_INIT_FLAGS:-"--disable-up-arrow"}
for tool in starship atuin zoxide thefuck; do
  command -v "$tool" >/dev/null && {
    case "$tool" in
    atuin)
      eval "$($tool init $shell $ATUIN_INIT_FLAGS)"
      ;;
    starship | zoxide)
      eval "$($tool init $shell)"
      ;;
    thefuck)
      eval "$(thefuck --alias)"
      ;;
    esac
  }
done
