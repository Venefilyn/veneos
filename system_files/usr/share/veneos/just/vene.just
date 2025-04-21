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
  mkdir -p "${HOME}/.bashrc.d" "${HOME}/.zshrc.d"

  echo "Adding bling to shells..."
  echo '[ -f "/usr/share/veneos/bling/bling.sh" ] && . "/usr/share/veneos/bling/bling.sh"' | tee \
    "${HOME}/.bashrc.d/bling.bashrc" \
    "${HOME}/.zshrc.d/bling.zshrc" >/dev/null

  echo "Configure shell rc files"
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
