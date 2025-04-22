# Setup editor in order of priority
for cmd in nvim vim vi nano ;
  command -v "$cmd" >/dev/null; begin;
    set -gx EDITOR=$cmd
    break
  end;
end;

# Shell-specific configurations
set fish_greeting # Disable greeting
# if cargo env file exists, source that too
[ -f "$HOME/.cargo/env.fish" ] && source "$HOME/.cargo/env.fish"
