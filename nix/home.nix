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
  t3codeAppImage = "${homeDirectory}/.local/share/t3code/T3-Code-nightly-x86_64.AppImage";
  t3code = pkgs.writeShellScriptBin "t3code" ''
    if [ ! -x "${t3codeAppImage}" ]; then
      echo "t3code: nightly AppImage missing; run home-manager switch" >&2
      exit 1
    fi
    export PATH="${homeDirectory}/.opencode/bin:$PATH"
    exec "${t3codeAppImage}" "$@"
  '';
  plasmaKeyboardDesktop = "org.kde.plasma.keyboard.${plasma-keyboard.version}.desktop";
  heliumWithDebug = pkgs.symlinkJoin {
    name = "helium";
    paths = [ helium ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/helium \
        --add-flags "--remote-debugging-port=9222" \
        --add-flags "--load-extension=${homeDirectory}/.local/share/helium-kde-theme"
    '';
  };
  qbittorrentPatched = pkgs.qbittorrent.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/base/utils/misc.h \
        --replace-fail 'TimeResolution resolution = TimeResolution::Minutes' \
          'TimeResolution resolution = TimeResolution::Seconds'
    '';
  });
  qbittorrentThemed = pkgs.symlinkJoin {
    name = "qbittorrent";
    paths = [ qbittorrentPatched ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/qbittorrent \
        --set QT_QPA_PLATFORMTHEME kde \
        --set-default QT_STYLE_OVERRIDE Windows \
        --prefix QT_PLUGIN_PATH : "${pkgs.kdePackages.plasma-integration}/${pkgs.kdePackages.qtbase.qtPluginPrefix}" \
        --prefix XDG_DATA_DIRS : "${pkgs.kdePackages.plasma-integration}/share:${pkgs.kdePackages.kconfig}/share:${pkgs.kdePackages.kcolorscheme}/share" \
        --suffix XDG_DATA_DIRS : "/usr/local/share:/usr/share"
    '';
  };
  makemkvFixed = pkgs.makemkv.overrideAttrs (old: {
    srcs = [
      (pkgs.fetchurl {
        url = "https://www.makemkv.com/download/old/makemkv-bin-${old.version}.tar.gz";
        curlOptsList = [ "--http1.1" ];
        hash = "sha256-we5yCukbJ2p8ib6GEUbFuTRjGDHo1sj0U0BkNXJOkr0=";
      })
      (pkgs.fetchurl {
        url = "https://www.makemkv.com/download/old/makemkv-oss-${old.version}.tar.gz";
        curlOptsList = [ "--http1.1" ];
        hash = "sha256-vIuwhK46q81QPVu5PvwnPgRuT9RmPTmpg2zgwEf+6CM=";
      })
    ];
  });
  tdarrNode = pkgs.tdarr-node.overrideAttrs (old: rec {
    version = "2.84.01";
    src = pkgs.fetchzip {
      url = "https://storage.tdarr.io/versions/${version}/linux_x64/Tdarr_Node.zip";
      hash = "sha256-SU4yGJSxe11vQoToSPmaL+u/nbAIFPWxik8jBnD/Vfk=";
      stripRoot = false;
    };
    buildInputs = old.buildInputs ++ [ pkgs.openssl ];
  });
  tdarrCurrent = pkgs.tdarr.override { tdarr-node = tdarrNode; };
  configureTdarrNode = pkgs.writeShellScript "configure-tdarr-node" ''
    set -eu
    _tdarr_dir="${homeDirectory}/.local/share/tdarr/node/configs"
    _tdarr_config="$_tdarr_dir/Tdarr_Node_Config.json"
    ${pkgs.coreutils}/bin/mkdir -p "$_tdarr_dir" "${homeDirectory}/.cache/tdarr"
    _tdarr_tmp=$(${pkgs.coreutils}/bin/mktemp "$_tdarr_dir/.config-XXXXXX")

    if [ -f "$_tdarr_config" ]; then
      ${pkgs.jq}/bin/jq '
        del(.handbrakePath, .ffmpegPath, .ffprobePath, .mkvpropeditPath)
        + {
            nodeName: "steamdeck",
            serverURL: "http://192.168.1.97:8266",
            serverIP: "192.168.1.97",
            serverPort: "8266",
            ccextractorPath: "${pkgs.ccextractor}/bin/ccextractor",
            pathTranslators: [
              { server: "/mnt/btr", node: "${homeDirectory}/btr" },
              { server: "/temp", node: "${homeDirectory}/.cache/tdarr" }
            ]
          }
      ' "$_tdarr_config" > "$_tdarr_tmp"
    else
      ${pkgs.jq}/bin/jq -n '{
        nodeName: "steamdeck",
        serverURL: "http://192.168.1.97:8266",
        serverIP: "192.168.1.97",
        serverPort: "8266",
        ccextractorPath: "${pkgs.ccextractor}/bin/ccextractor",
        pathTranslators: [
          { server: "/mnt/btr", node: "${homeDirectory}/btr" },
          { server: "/temp", node: "${homeDirectory}/.cache/tdarr" }
        ]
      }' > "$_tdarr_tmp"
    fi

    ${pkgs.coreutils}/bin/chmod 600 "$_tdarr_tmp"
    ${pkgs.coreutils}/bin/mv "$_tdarr_tmp" "$_tdarr_config"
  '';
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
    t3code
    autojump      
    bat           
    lsd
    gdu
    btrfs-assistant
    difftastic    # difft
    gh            
    git-filter-repo
    uv
    starship      
    pstree        # used by fish SSH-detection in config.fish
    gping
    aria2
    rclone
    tdarrCurrent
    xdelta        # xdelta3 binary
    deno
    nodejs        # provides node/npm/npx
    android-studio
    android-tools # provides adb for mobile-mcp
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

    curl-impersonate
    # Built from the egigoka fork. KWin is pointed at a versioned desktop file
    # below so it does not reuse stale cached input-method service metadata.
    plasma-keyboard
    heliumWithDebug
    qbittorrentThemed
    mkvtoolnix   # provides mkvmerge, mkvinfo, mkvextract, etc.
    makemkvFixed # provides makemkvcon
    lsdvd
    kdotool      # xdotool-like window control for KWin/Wayland
  ];

  home.file.".local/share/applications/btrfs-assistant.desktop".text = ''
    [Desktop Entry]
    Name=Btrfs Assistant
    Comment=Manage Btrfs snapshots and Snapper
    Exec=${pkgs.btrfs-assistant}/bin/btrfs-assistant-launcher
    Terminal=false
    Type=Application
    Icon=btrfs-assistant
    Categories=System;Filesystem;
    NoDisplay=false
    StartupNotify=true
  '';

  home.file.".local/share/applications/t3code.desktop".text = ''
    [Desktop Entry]
    Name=T3 Code (Nightly)
    Comment=T3 Code desktop build
    Exec=${t3code}/bin/t3code --no-sandbox %U
    Terminal=false
    Type=Application
    Icon=${homeDirectory}/.local/share/t3code/t3code.png
    Categories=Development;
    StartupWMClass=t3code
  '';

  home.file.".local/share/applications/app.magicpods.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=MagicPods
    Comment=The control center for your Bluetooth headphones
    Exec=${homeDirectory}/.local/share/Steam/steamapps/common/MagicPods/magicpods.sh
    Icon=${homeDirectory}/.local/share/icons/magicpods.png
    Terminal=false
    Categories=AudioVideo;Audio;
    StartupWMClass=MagicPods
  '';

  home.file.".config/autostart/app.magicpods.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=MagicPods
    Comment=The control center for your Bluetooth headphones
    Exec=${homeDirectory}/.local/share/Steam/steamapps/common/MagicPods/magicpods.sh
    Icon=${homeDirectory}/.local/share/icons/magicpods.png
    Terminal=false
    Categories=AudioVideo;Audio;
    StartupWMClass=MagicPods
  '';

  home.activation.heliumThemeColor = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _gtk_colors="${homeDirectory}/.config/gtk-3.0/colors.css"
    _theme_dir="${homeDirectory}/.local/share/helium-kde-theme"
    _helium_hex=

    if [ -f "$_gtk_colors" ]; then
      while IFS= read -r _line; do
        if [[ $_line =~ ^@define-color\ theme_header_background_[A-Za-z0-9-]+\ \#([0-9A-Fa-f]{6})\;$ ]]; then
          _helium_hex="''${BASH_REMATCH[1]}"
          break
        fi
      done < "$_gtk_colors"

      if [ -z "$_helium_hex" ]; then
        while IFS= read -r _line; do
          if [[ $_line =~ ^@define-color\ theme_bg_color_[A-Za-z0-9-]+\ \#([0-9A-Fa-f]{6})\;$ ]]; then
            _helium_hex="''${BASH_REMATCH[1]}"
            break
          fi
        done < "$_gtk_colors"
      fi
    fi

    if [ -n "$_helium_hex" ]; then
      _r=$((16#''${_helium_hex:0:2}))
      _g=$((16#''${_helium_hex:2:2}))
      _b=$((16#''${_helium_hex:4:2}))
      _lum=$(( (_r * 299 + _g * 587 + _b * 114) / 1000 ))
      if [ "$_lum" -gt 128 ]; then
        _text='[0,0,0]'
        _text_muted='[60,60,60]'
      else
        _text='[255,255,255]'
        _text_muted='[255,255,255]'
      fi

      ${pkgs.coreutils}/bin/mkdir -p "$_theme_dir"
      ${pkgs.jq}/bin/jq -n \
        --argjson r "$_r" --argjson g "$_g" --argjson b "$_b" \
        --argjson text "$_text" --argjson text_muted "$_text_muted" \
        '{
          "manifest_version": 3,
          "name": "KDE Panel Theme",
          "version": "1.0",
          "key": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA7MS5ENdgy1rRTjQEZyVIOWZ0COYp+kOy90txuPiJ2aVw3GspaOOdmjtJtdGUzLuQu9VDrEeYH1aMtEbgvph2qy1JZNDOyspmOaOBBR8Hh/dhqoHLazBH5JFQH+9HOycfTRftEt4fNlxZdQceq9bfL0++Gx78HAhPFEn8B3GnbKKBTyHB/+GlQ/LkwX9etbuOS8irKrsfd7U3XsQs4+Jgu3T7IEsB9yrIDX9HeKJsZSt6RmXxsxtW7cW7z3WEBDzbHDZnfWCMWjZ5rryjEjMIxuougIdQdxaUu6lIXLs1IDlF2QzAlCMdQnz/Wbz2xNtD213EhCcgWnuTHoYiz9e34wIDAQAB",
          "theme": {
            "colors": {
              "frame": [$r, $g, $b],
              "frame_inactive": [$r, $g, $b],
              "toolbar": [$r, $g, $b],
              "background_tab": [100, 114, 90],
              "background_tab_inactive": [100, 114, 90],
              "tab_text": $text,
              "tab_background_text": $text_muted,
              "toolbar_text": $text,
              "bookmark_text": $text,
              "toolbar_button_icon": $text,
              "ntp_background": [100, 114, 90],
              "ntp_header": [$r, $g, $b],
              "ntp_link": $text,
              "ntp_text": $text,
              "button_background": [$r, $g, $b],
              "omnibox_background": [100, 114, 90],
              "omnibox_text": $text
            }
          }
        }' > "$_theme_dir/manifest.json"

      _helium_prefs="${homeDirectory}/.config/net.imput.helium/Default/Preferences"
      if [ -f "$_helium_prefs" ]; then
        _helium_color=$(( (255 << 24) + (_r << 16) + (_g << 8) + _b - 4294967296 ))
        _tmp=$(${pkgs.coreutils}/bin/mktemp)
        ${pkgs.jq}/bin/jq -c \
          --argjson color "$_helium_color" \
          '.browser.theme.user_color2 = $color | .browser.theme.color_variant2 = 2' \
          "$_helium_prefs" > "$_tmp" && \
          ${pkgs.coreutils}/bin/mv "$_tmp" "$_helium_prefs" || \
          ${pkgs.coreutils}/bin/rm -f "$_tmp"
      fi
    fi
  '';

  home.activation.plasmaKeyboardInputMethod = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc --group Wayland --key InputMethod \
      "${homeDirectory}/.nix-profile/share/applications/${plasmaKeyboardDesktop}"
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled true
    command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    command -v qdbus6 >/dev/null 2>&1 && qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  '';

  home.activation.btrMountpoint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "${homeDirectory}/btr"
  '';

  home.activation.t3codeNightly = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _t3code_dir="${homeDirectory}/.local/share/t3code"
    _t3code_app="${t3codeAppImage}"
    _t3code_icon="$_t3code_dir/t3code.png"
    _t3code_url_file="$_t3code_dir/.installed-url"
    _t3code_api="https://api.github.com/repos/pingdotgg/t3code/releases?per_page=10"

    if _t3code_releases=$(${pkgs.curl}/bin/curl -sfL \
      -H "Accept: application/vnd.github+json" "$_t3code_api" 2>/dev/null); then
      _t3code_asset=$(printf '%s' "$_t3code_releases" | ${pkgs.jq}/bin/jq -r '
        [.[]
          | select(.prerelease and (.tag_name | contains("-nightly.")))
          | { tag: .tag_name,
              asset: (.assets[] | select(.name | endswith("-x86_64.AppImage"))) }]
        | first
        | [.tag, .asset.browser_download_url, (.asset.digest // "")]
        | @tsv
      ')
      IFS=$'\t' read -r _t3code_tag _t3code_url _t3code_digest <<< "$_t3code_asset"

      if [ -n "$_t3code_url" ] && \
         { [ ! -x "$_t3code_app" ] || [ ! -f "$_t3code_url_file" ] || \
           [ "$(<"$_t3code_url_file")" != "$_t3code_url" ]; }; then
        echo "t3code: installing $_t3code_tag..."
        ${pkgs.coreutils}/bin/mkdir -p "$_t3code_dir"
        _t3code_tmp=$(${pkgs.coreutils}/bin/mktemp "$_t3code_dir/.download-XXXXXX.AppImage")
        if ${pkgs.curl}/bin/curl -fL "$_t3code_url" -o "$_t3code_tmp"; then
          _t3code_valid=true
          if [[ $_t3code_digest == sha256:* ]]; then
            _t3code_sha256="''${_t3code_digest#sha256:}"
            printf '%s  %s\n' "$_t3code_sha256" "$_t3code_tmp" \
              | ${pkgs.coreutils}/bin/sha256sum -c - >/dev/null || _t3code_valid=false
          fi
          if $_t3code_valid; then
            ${pkgs.coreutils}/bin/chmod +x "$_t3code_tmp"
            ${pkgs.coreutils}/bin/mv "$_t3code_tmp" "$_t3code_app"
            printf '%s\n' "$_t3code_url" > "$_t3code_url_file"
          else
            echo "t3code: checksum verification failed" >&2
            ${pkgs.coreutils}/bin/rm -f "$_t3code_tmp"
          fi
        else
          echo "t3code: download failed" >&2
          ${pkgs.coreutils}/bin/rm -f "$_t3code_tmp"
        fi
      fi
    else
      echo "t3code: failed to fetch GitHub releases" >&2
    fi

    if [ -x "$_t3code_app" ] && { [ ! -s "$_t3code_icon" ] || [ "$_t3code_app" -nt "$_t3code_icon" ]; }; then
      _t3code_icon_tmp=$(${pkgs.coreutils}/bin/mktemp "$_t3code_dir/.icon-XXXXXX.png")
      if ${pkgs.p7zip}/bin/7z x -so "$_t3code_app" \
        usr/share/icons/hicolor/256x256/apps/t3code.png > "$_t3code_icon_tmp" && \
        [ -s "$_t3code_icon_tmp" ]; then
        ${pkgs.coreutils}/bin/mv "$_t3code_icon_tmp" "$_t3code_icon"
      else
        echo "t3code: failed to extract icon" >&2
        ${pkgs.coreutils}/bin/rm -f "$_t3code_icon_tmp"
      fi
    fi
  '';

  home.activation.braveOrigin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _brave_base="https://brave-browser-apt-release.s3.brave.com"
    if _brave_packages=$(${pkgs.curl}/bin/curl -sfL "$_brave_base/dists/stable/main/binary-amd64/Packages" 2>/dev/null); then
      _brave_version=$(printf '%s' "$_brave_packages" | grep -A10 "^Package: brave-origin$" | grep "^Version:" | head -1 | cut -d' ' -f2)
      _brave_filename=$(printf '%s' "$_brave_packages" | grep -A20 "^Package: brave-origin$" | grep "^Filename:" | head -1 | cut -d' ' -f2)
      _brave_target="${homeDirectory}/.local/share/brave-origin"
      _brave_version_file="$_brave_target/.installed-version"
      _brave_app="$_brave_target/root/opt/brave.com/brave-origin/brave-origin"
      if [ -f "$_brave_app" ] && grep -Fq -- '--remote-debugging-port=9223' "$_brave_app"; then
        echo "brave-origin: restoring launcher overwritten through old symlink..."
        rm -f "$_brave_version_file"
      fi
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
      if [ -x "$_brave_app" ]; then
        mkdir -p "${homeDirectory}/.local/bin" "${homeDirectory}/.local/share/applications" "${homeDirectory}/.local/share/icons"
        for _brave_bin in brave-origin brave-origin-stable; do
          _brave_wrapper="${homeDirectory}/.local/bin/$_brave_bin"
          rm -f "$_brave_wrapper"
          {
            printf '%s\n' '#!/bin/sh'
            printf 'exec "%s" --remote-debugging-port=9223 "$@"\n' "$_brave_app"
          } > "$_brave_wrapper"
          chmod +x "$_brave_wrapper"
        done
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

  systemd.user.services.brave-origin-tabs-backup = {
    Unit.Description = "Backup open Brave Origin tabs";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${homeDirectory}/configs/scripts/brave-origin-tabs-backup.py";
    };
  };

  systemd.user.timers.brave-origin-tabs-backup = {
    Unit.Description = "Backup Brave Origin tabs hourly";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.firefox-tabs-backup = {
    Unit.Description = "Backup open Firefox tabs";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${homeDirectory}/configs/scripts/firefox-tabs-backup.py";
    };
  };

  systemd.user.timers.firefox-tabs-backup = {
    Unit.Description = "Backup Firefox tabs hourly";
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

  systemd.user.services.btr-smb = {
    Unit = {
      Description = "Mount btr SMB share";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "notify";
      ExecStart = "${pkgs.rclone}/bin/rclone mount btr-smb:btr ${homeDirectory}/btr --config ${homeDirectory}/.config/rclone/rclone.conf --vfs-cache-mode writes --vfs-cache-max-size 100Gi --vfs-cache-max-age 24h --vfs-cache-min-free-space 10Gi";
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u ${homeDirectory}/btr";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.tdarr-node = {
    Unit = {
      Description = "Tdarr transcode node";
      Requires = [ "btr-smb.service" ];
      After = [ "network-online.target" "btr-smb.service" ];
    };

    Service = {
      ExecStartPre = [
        "${pkgs.util-linux}/bin/mountpoint -q ${homeDirectory}/btr"
        configureTdarrNode
      ];
      ExecStart = "${tdarrNode}/bin/tdarr-node";
      Restart = "on-failure";
      RestartSec = 10;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
