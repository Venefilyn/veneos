[private]
default:
    @just --list

# Install all VeneOS apps
[group('Install')]
vene-install: vene-install-flatpaks

# Install Flatpaks
[group('Install')]
vene-install-flatpaks:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "Installing Flatpaks..."
  xargs -a <(curl --retry 3 -sL https://raw.githubusercontent.com/Venefilyn/veneos/main/repo_files/flatpaks) flatpak --system -y install
  echo "Flatpaks installation complete."

# Setup Git
[group('Setup')]
vene-setup-git:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ ! -f "${HOME}/.ssh/id_ed25519.pub" ]; then
    # Generate SSH key
    echo "SSH key not found"
  fi

  echo "Setting up Git config..."

  # Ask for Git username and email
  read -p "Enter your Git username: " git_username
  read -p "Enter your Git email: " git_email

  # Configure Git
  git config --global color.ui true
  git config --global user.name "$git_username"
  git config --global user.email "$git_email"

  if [ ! -f "${HOME}/.ssh/id_ed25519.pub" ]; then
    # Generate SSH key
    echo "SSH key not found"
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "$git_email"

    # Display the public key
    echo "Your SSH public key:"
    cat ${HOME}/.ssh/id_ed25519.pub
  else
    echo "Using existing SSH key ~/.ssh/id_ed25519.pub"
    # TODO: Improve this
    echo "Manually verify that your email $git_email matches SSH key"
  fi

  echo "Setup GPG to use SSH key"
  git config --global gpg.format ssh;
  # Make SSH key inline, this allows us to use containers much easier with ssh
  git config --global user.signingkey "key::$(cat ${HOME}/.ssh/id_ed25519.pub)";
  git config --global commit.gpgSign true


  echo "Setup aliases"
  git config --global alias.add-nowhitespace '!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -';
  git config --global alias.graph 'log --decorate --oneline --graph';
  git config --global alias.ll 'log --oneline';
  git config --global alias.prune-all '!git remote | xargs -n 1 git remote prune';
  git config --global alias.pullr 'pull --rebase';
  git config --global alias.pushall '!git remote | xargs -L1 git push --all';
  git config --global alias.pushfwl 'push --force-with-lease';

  echo "Various QoL configs"
  # Improve git for big repos (makes older libgit2 not work correctly)
  git config --global feature.manyFiles true;
  git config --global init.defaultBranch main;

  echo "Create global .gitignore"

  git config --global core.excludesFile '~/.gitignore'

# Setup VeneOS terminal configs
[group('Setup')]
vene-setup-cli:
  #!/usr/bin/env bash
  set -euo pipefail

  # Create config directories
  mkdir -p "${HOME}/.bashrc.d" \
    "${HOME}/.zshrc.d" \
    "${HOME}/.config/fish/completions" \
    "${HOME}/.config/fish/conf.d" \
    "${HOME}/.config/fish/functions"

  echo "Shell configuration"

  echo "Adding aliases..."
  echo '[ -f "/usr/share/veneos/bling/aliases.sh" ]; bass source /usr/share/veneos/bling/aliases.sh'| tee \
    "${HOME}/.config/fish/conf.d/veneos-aliases.fish" >/dev/null

  echo '[ -f "/usr/share/veneos/bling/aliases.sh" ] && . "/usr/share/veneos/bling/aliases.sh"'| tee \
    "${HOME}/.bashrc.d/veneos-aliases.bashrc" \
    "${HOME}/.zshrc.d/veneos-aliases.zshrc" >/dev/null

  echo "Adding shell defaults..."
  echo '[ -f "/usr/share/veneos/bling/defaults.fish" ]; source /usr/share/veneos/bling/defaults.fish'| tee \
    "${HOME}/.config/fish/conf.d/veneos-defaults.fish" >/dev/null

  echo '[ -f "/usr/share/veneos/bling/defaults.sh" ] && . "/usr/share/veneos/bling/defaults.sh"' | tee \
    "${HOME}/.bashrc.d/veneos-defaults.bashrc" \
    "${HOME}/.zshrc.d/veneos-defaults.zshrc" >/dev/null

  echo "Adding plugins..."
  echo '[ -f "/usr/share/veneos/bling/plugins.sh" ] && . "/usr/share/veneos/bling/plugins.sh"' | tee \
    "${HOME}/.bashrc.d/veneos-plugins.bashrc" \
    "${HOME}/.zshrc.d/veneos-plugins.zshrc" >/dev/null


  echo "Adding fish plugins..."
  wget -q https://github.com/edc/bass/raw/7296c6e70cf577a08a2a7d0e919e428509640e0f/functions/__bass.py -O "${HOME}/.config/fish/functions/__bass.py"
  wget -q https://github.com/edc/bass/raw/7296c6e70cf577a08a2a7d0e919e428509640e0f/functions/bass.fish -O "${HOME}/.config/fish/functions/bass.fish"
  wget -q https://github.com/garabik/grc/raw/4e1e9d7fdc9965c129f27d89c493d07f4b8307bb/grc.fish -O "${HOME}/.config/fish/conf.d/grc.fish"

  echo "Setting up tools for fish"
  echo "[ -f "${HOME}/.cargo/env.fish" ] && source \"${HOME}/.cargo/env.fish\"" | tee \
    "${HOME}/.config/fish/conf.d/cargo-env.fish" >/dev/null

  ATUIN_INIT_FLAGS=${ATUIN_INIT_FLAGS:-"--disable-up-arrow"}
  for tool in starship atuin zoxide thefuck direnv; do
    command -v "$tool" >/dev/null && {
      case "$tool" in
      atuin)
        $tool init fish $ATUIN_INIT_FLAGS > "${HOME}/.config/fish/conf.d/${tool}.fish"
        ;;
      starship | zoxide)
        $tool init fish > "${HOME}/.config/fish/conf.d/${tool}.fish"
        ;;
      thefuck)
        $tool --alias > "${HOME}/.config/fish/functions/${tool}.fish"
        ;;
      direnv)
        $tool hook fish > "${HOME}/.config/fish/conf.d/${tool}.fish"
      esac
    }
  done

  echo "Configure sh rc files"
  for shell in bash zsh; do
    echo ".. configuring $shell"
    rc_file="${HOME}/.${shell}rc"
    rc_dir=".${shell}rc.d"

    snippet="# User specific aliases and functions
  if [ -d ~/${rc_dir} ]; then
    for rc in ~/${rc_dir}/*; do
      if [ -f \"\$rc\" ]; then
        . \"\$rc\"
      fi
    done
  fi
  unset rc"

    if [ -f "$rc_file" ]; then
      if ! grep -q "${rc_dir}/\*" "$rc_file"; then
        echo -e "\n${snippet}" >>"$rc_file"
      fi
    else
      echo "${snippet}" >"$rc_file"
    fi
  done

  echo "Terminal setup complete."

# TODO: Need to figure this one out
# # Setup VeneOS recommended settings for VSCode
# vene-setup-editors:
#   #!/usr/bin/env bash
#   set -euo pipefail

#   for editor in "Code"; do
#     echo "Setting up $editor configuration..."
#     config_dir="${HOME}/.config/${editor}/User"
#     mkdir -p "$config_dir"
#     cp -f "/etc/skel/.config/${editor}/User/settings.json" "$config_dir/settings.json"
#     echo "$editor setup complete."
#   done
