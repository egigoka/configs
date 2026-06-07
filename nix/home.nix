{ pkgs, username, homeDirectory, plasma-keyboard, ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;

  # Don't change this without reading the home-manager release notes.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Keep this list in sync with the non-nix `install_if_missing` calls in setup.sh.
  home.packages = with pkgs; [
    fish          
    pay-respects  
    fzf           
    micro         
    python3
    autojump      
    bat           
    lsd           
    difftastic    # difft
    gh            
    uv            # python tooling (used for virtualfish)
    starship      
    pstree        # used by fish SSH-detection in config.fish
    gping         # ping with a graph
    rustup        
    gcc           
    gnumake       
    nix-index     # provides `nix-locate` (find which pkg ships a file); `nix search` is built into nix
    google-authenticator  # wired into /etc/pam.d/sshd by setup.sh

    # GUI: Qt Virtual Keyboard based on-screen keyboard for Plasma Desktop Mode
    # (built from the egigoka fork). Wire it up as KWin's input method via
    # kwinrc [Wayland] InputMethod -> ~/.nix-profile/share/applications/org.kde.plasma.keyboard.desktop
    plasma-keyboard
  ];
}
