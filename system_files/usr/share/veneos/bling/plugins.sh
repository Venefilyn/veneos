#!/usr/bin/env sh

# Determine shell and prevent double-sourcing
[ -z "$BASH_VERSION" ] && [ -z "$ZSH_VERSION" ] && [ -z "$FISH_VERSION" ] && return
[ -n "$BASH_VERSION" ] && shell="bash" && [ "${BASH_BLING_SOURCED:-0}" -eq 1 ] && return || BASH_BLING_SOURCED=1
[ -n "$ZSH_VERSION" ] && shell="zsh" && [ "${ZSH_BLING_SOURCED:-0}" -eq 1 ] && return || ZSH_BLING_SOURCED=1

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
