{ pkgs, username, homeDirectory, plasma-keyboard, ... }:

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
    # NOTE: do NOT add `coreutils` here. nixpkgs coreutils is built against a
    # newer glibc than SteamOS; putting it on PATH makes Steam's launch scripts
    # (dirname/basename/env/...) fail with "GLIBC_2.xx not found" and crash in
    # Desktop Mode. The system provides dircolors and the rest under /usr/bin.
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
    nix-index     # provides `nix-locate` (find which pkg ships a file); `nix search` is built into nix

    # GUI: Qt Virtual Keyboard based on-screen keyboard for Plasma Desktop Mode
    # (built from the egigoka fork). Wire it up as KWin's input method via
    # kwinrc [Wayland] InputMethod -> ~/.nix-profile/share/applications/org.kde.plasma.keyboard.desktop
    plasma-keyboard
  ];
}
