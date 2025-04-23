#!/usr/bin/env sh

# Determine shell and prevent double-sourcing
[ -z "$BASH_VERSION" ] && [ -z "$ZSH_VERSION" ] && [ -z "$FISH_VERSION" ] && return
[ -n "$BASH_VERSION" ] && shell="bash" && [ "${BASH_BLING_SOURCED:-0}" -eq 1 ] && return || BASH_BLING_SOURCED=1
[ -n "$ZSH_VERSION" ] && shell="zsh" && [ "${ZSH_BLING_SOURCED:-0}" -eq 1 ] && return || ZSH_BLING_SOURCED=1

# Setup editor in order of priority
for cmd in nvim vim vi nano ; do
  command -v "$cmd" >/dev/null && {
    export EDITOR=$cmd
    break
  }
done

# Shell-specific configurations
case "$shell" in
bash)
  [ -f "/usr/share/bash-prexec" ] && . "/usr/share/bash-prexec"
  ;;
zsh)
  [ -f "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && . "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ;;
esac

# Start fish if we're in zsh
# That way we can set fish as default shell while still POSIX-compliant
case "$shell" in
zsh)
  command -v "$cmd" >/dev/null && {
      if [[ $(ps -o command= -p "$PPID" | awk '{print $1}') != 'fish' ]]
      then
          exec fish -l
      fi
  }
  ;;
esac
