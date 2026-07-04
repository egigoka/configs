{ lib, pkgs, username, homeDirectory, plasma-keyboard, helium, ... }:

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
  plasmaKeyboardDesktop = "org.kde.plasma.keyboard.${plasma-keyboard.version}.desktop";
  heliumWithDebug = pkgs.symlinkJoin {
    name = "helium";
    paths = [ helium ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/helium \
        --add-flags "--remote-debugging-port=9222"
    '';
  };
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
    git-filter-repo
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
    # Built from the egigoka fork. KWin is pointed at a versioned desktop file
    # below so it does not reuse stale cached input-method service metadata.
    plasma-keyboard
    heliumWithDebug
    mkvtoolnix   # provides mkvmerge, mkvinfo, mkvextract, etc.
    kdotool      # xdotool-like window control for KWin/Wayland
  ];

  home.activation.plasmaKeyboardInputMethod = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc --group Wayland --key InputMethod \
      "${homeDirectory}/.nix-profile/share/applications/${plasmaKeyboardDesktop}"
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled true
    command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    command -v qdbus6 >/dev/null 2>&1 && qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  '';

  home.activation.braveOrigin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _brave_base="https://brave-browser-apt-release.s3.brave.com"
    if _brave_packages=$(${pkgs.curl}/bin/curl -sfL "$_brave_base/dists/stable/main/binary-amd64/Packages" 2>/dev/null); then
      _brave_version=$(printf '%s' "$_brave_packages" | grep -A10 "^Package: brave-origin$" | grep "^Version:" | head -1 | cut -d' ' -f2)
      _brave_filename=$(printf '%s' "$_brave_packages" | grep -A20 "^Package: brave-origin$" | grep "^Filename:" | head -1 | cut -d' ' -f2)
      _brave_target="${homeDirectory}/.local/share/brave-origin"
      _brave_version_file="$_brave_target/.installed-version"
      if [ -n "$_brave_version" ] && [ -n "$_brave_filename" ] && \
         { [ ! -f "$_brave_version_file" ] || [ "$(cat "$_brave_version_file")" != "$_brave_version" ]; }; then
        echo "brave-origin: installing version $_brave_version..."
        rm -rf "$_brave_target/root"
        mkdir -p "$_brave_target"
        _brave_tmp=$(mktemp /tmp/brave-origin-XXXXXX.deb)
        if ${pkgs.curl}/bin/curl -sfL "$_brave_base/$_brave_filename" -o "$_brave_tmp"; then
          ${pkgs.dpkg}/bin/dpkg-deb --extract "$_brave_tmp" "$_brave_target/root"
          echo "$_brave_version" > "$_brave_version_file"
        else
          echo "brave-origin: download failed" >&2
        fi
        rm -f "$_brave_tmp"
      fi
      if [ -x "$_brave_target/root/opt/brave.com/brave-origin/brave-origin" ]; then
        mkdir -p "${homeDirectory}/.local/bin" "${homeDirectory}/.local/share/applications" "${homeDirectory}/.local/share/icons"
        ln -sf "$_brave_target/root/opt/brave.com/brave-origin/brave-origin" "${homeDirectory}/.local/bin/brave-origin"
        ln -sf "$_brave_target/root/opt/brave.com/brave-origin/brave-origin" "${homeDirectory}/.local/bin/brave-origin-stable"
        if [ -d "$_brave_target/root/usr/share/icons" ]; then
          cp -r "$_brave_target/root/usr/share/icons/." "${homeDirectory}/.local/share/icons/"
        fi
        _brave_desktop="$_brave_target/root/usr/share/applications/brave-origin.desktop"
        if [ -f "$_brave_desktop" ]; then
          sed \
            -e "s|Exec=/usr/bin/brave-origin-stable|Exec=${homeDirectory}/.local/bin/brave-origin-stable|g" \
            -e "s|^Icon=.*|Icon=$_brave_target/root/opt/brave.com/brave-origin/product_logo_256.png|g" \
            "$_brave_desktop" > "${homeDirectory}/.local/share/applications/brave-origin.desktop"
        fi
      fi
    else
      echo "brave-origin: failed to fetch Packages index" >&2
    fi
  '';

  systemd.user.services.helium-tabs-backup = {
    Unit.Description = "Backup open Helium tabs";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${homeDirectory}/configs/scripts/helium-tabs-backup.py";
    };
  };

  systemd.user.timers.helium-tabs-backup = {
    Unit.Description = "Backup Helium tabs hourly";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

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
