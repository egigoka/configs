{ pkgs, username, homeDirectory, ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;

  # Don't change this without reading the home-manager release notes.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Console packages installed by setup.sh on SteamOS (and any nix host).
  # Keep this list in sync with the non-nix `install_if_missing` calls in setup.sh.
  home.packages = with pkgs; [
    fish          # shell
    pay-respects  # command correction (replaces thefuck)
    fzf           # fuzzy finder
    coreutils     # provides dircolors
    python3
    autojump      # `j` directory jumping
    bat           # cat with syntax highlighting
    lsd           # modern ls
    difftastic    # structural diff (difft)
    gh            # GitHub CLI
    uv            # python tooling (used for virtualfish)
    starship      # prompt
    pstree        # used by fish SSH-detection in config.fish
    rustup        # rust toolchain installer/manager (rustc, cargo via `rustup default stable`)
    gcc           # C compiler; provides `cc` (used by cargo/rustc as the linker)
    gnumake       # GNU make (`make`)
  ];
}
