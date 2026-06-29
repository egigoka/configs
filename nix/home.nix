{ pkgs, username, homeDirectory, plasma-keyboard, helium, ... }:

let
  py = pkgs.python3Packages;
  fetchLatestGitHub = repo: builtins.fetchGit {
    url = "https://github.com/egigoka/${repo}";
    ref = "master";
    shallow = true;
  };
  commandsPackage = py.buildPythonPackage {
    pname = "commands";
    version = "unstable";
    pyproject = true;
    src = fetchLatestGitHub "commands";
    build-system = with py; [ setuptools wheel ];
    dependencies = with py; [
      chardet
      moviepy
      mutagen
      paramiko
      ping3
      psutil
      pyperclip
      requests
      termcolor
      wcwidth
    ];
    doCheck = false;
  };
  telegramePackage = py.buildPythonPackage {
    pname = "telegrame";
    version = "unstable";
    pyproject = true;
    src = fetchLatestGitHub "telegrame";
    build-system = with py; [ setuptools wheel ];
    dependencies = with py; [ pytelegrambotapi requests ];
    doCheck = false;
  };
  batteryPython = pkgs.python3.withPackages (_: [
    commandsPackage
    telegramePackage
    py.pytelegrambotapi
    py.xkbcommon
  ]);
  batteryScriptDir = "${homeDirectory}/Developer/py/telegram_bots";
  batteryDevice = "/org/freedesktop/UPower/devices/battery_BAT1";
in
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
    batteryPython
    autojump      
    bat           
    lsd
    gdu
    difftastic    # difft
    gh            
    uv
    starship      
    pstree        # used by fish SSH-detection in config.fish
    gping
    aria2
    xdelta        # xdelta3 binary
    deno
    nodejs        # provides node/npm/npx
    rustup        
    gcc           
    clang-tools   # provides clang-format
    cmake         
    kdePackages.extra-cmake-modules
    kdePackages.kcodecs
    kdePackages.kcodecs.dev
    kdePackages.kcolorscheme
    kdePackages.kcolorscheme.dev
    kdePackages.kcoreaddons
    kdePackages.kcoreaddons.dev
    kdePackages.ki18n
    kdePackages.ki18n.dev
    kdePackages.kcmutils
    kdePackages.kcmutils.dev
    kdePackages.kconfig
    kdePackages.kconfig.dev
    kdePackages.kconfigwidgets
    kdePackages.kconfigwidgets.dev
    kdePackages.kcrash
    kdePackages.kcrash.dev
    kdePackages.kwidgetsaddons
    kdePackages.kwidgetsaddons.dev
    kdePackages.qtbase  # provides qtpaths6
    kdePackages.qtdeclarative  # provides Qt6Qml
    kdePackages.qtvirtualkeyboard  # provides Qt6VirtualKeyboard
    libglvnd      # OpenGL libraries for CMake
    libglvnd.dev  # OpenGL headers for CMake
    libxkbcommon  # keyboard handling libraries
    libxkbcommon.dev  # headers/pkg-config files
    pkg-config    # helps CMake find Wayland via pkg-config
    vulkan-headers # provides VulkanHeaders for WrapVulkanHeaders
    wayland       # Wayland libraries for Qt6WaylandClient
    wayland.dev   # Wayland headers/pkg-config files
    wayland-protocols
    wayland-scanner.out # provides wayland.xml
    wayland-scanner.bin # provides wayland-scanner
    wayland-scanner.dev # provides wayland-scanner.pc
    ninja         
    gnumake       
    nix-index     # provides `nix-locate` (find which pkg ships a file); `nix search` is built into nix
    google-authenticator  # wired into /etc/pam.d/sshd by setup.sh

    decky-loader
    curl-impersonate
    # (built from the egigoka fork). Wire it up as KWin's input method via
    # kwinrc [Wayland] InputMethod -> ~/.nix-profile/share/applications/org.kde.plasma.keyboard.desktop
    plasma-keyboard
    helium
    mkvtoolnix   # provides mkvmerge, mkvinfo, mkvextract, etc.
    kdotool      # xdotool-like window control for KWin/Wayland
  ];

  systemd.user.services.telegram-battery = {
    Unit = {
      Description = "Telegram battery bot";
    };

    Service = {
      WorkingDirectory = batteryScriptDir;
      ExecStart = "${batteryPython}/bin/python ./battery.py ${batteryDevice}";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
