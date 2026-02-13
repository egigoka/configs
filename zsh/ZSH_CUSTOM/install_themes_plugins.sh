clone_if_missing() {
  local repo=$1 dest=$2
  if [ -d "$dest" ]; then
    echo "$(basename "$dest") already exists, skipping"
  else
    git clone "$repo" "$dest"
  fi
}

clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
clone_if_missing https://github.com/TamCore/autoupdate-oh-my-zsh-plugins.git $ZSH_CUSTOM/plugins/autoupdate
clone_if_missing https://github.com/zuxfoucault/colored-man-pages_mod $ZSH_CUSTOM/plugins/colored-man-pages_mod
clone_if_missing https://github.com/digitalraven/omz-homebrew $ZSH_CUSTOM/plugins/omz-homebrew
clone_if_missing https://github.com/mdumitru/last-working-dir $ZSH_CUSTOM/plugins/last-working-dir
clone_if_missing https://github.com/vincentto13/uvenv.plugin.zsh $ZSH_CUSTOM/plugins/uvenv
clone_if_missing https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
clone_if_missing https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
clone_if_missing https://github.com/seebi/dircolors-solarized $ZSH_CUSTOM/dircolors-solarized
clone_if_missing https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions
