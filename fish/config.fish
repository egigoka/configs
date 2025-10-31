if status is-interactive
  # Commands to run in interactive sessions can go here

  ### PATH
  ensure_path ~/go/bin
  ensure_path ~/.cargo/bin
  ensure_path ~/.local/bin
  ensure_path ~/.filen-cli/bin
  ensure_path /opt/homebrew/bin
  ensure_path /opt/homebrew/opt/llvm/bin
  ensure_path /usr/games
  ensure_path /usr/sbin
  ensure_path /usr/local/bin
  ensure_path /home/linuxbrew/.linuxbrew/bin

  ### ALIASES
  # tar
  abbr --add targzip   --position command tar -czvf
  abbr --add targunzip --position command tar -xzvf
  abbr --add untargz   --position command targunzip
  abbr --add targzls   --position command tar -tzvf  # list files

  # docker
  abbr --add d      --position command docker
  abbr --add dexec  --position command docker exec -it
  abbr --add dps    --position command docker ps --format "table {{.ID}}   {{.Status}}     {{.Names}}      {{.Image}}      {{.Ports}}"
  abbr --add dip    --position command docker inspect -f '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}'
  abbr --add dnls   --position command docker network ls
  abbr --add d-     --position command docker stop
  abbr --add d+     --position command docker start
  abbr --add drm    --position command docker rm
  abbr --add dc     --position command docker compose
  abbr --add dc+    --position command docker compose up
  abbr --add dc-    --position command docker compose down
  abbr --add dprune --position command d system prune -a --volumes

  # micro
  abbr --add m --position command micro

  # find
  abbr --add findne --position command find 2\>/dev/null

  # fd
  abbr --add findd --position command fd --hidden --ignore-case --glob

  # screen
  abbr --add screen+      --position command screen -S
  abbr --add screenc      --position command screen -Rd
  abbr --add screencc     --position command screen -x
  abbr --add screendaemon --position command screen -dmS
  abbr --add screenls     --position command screen -list

  # python
  abbr --add py  --position command python3
  abbr --add pip --position command python3 -m pip
  abbr --add pyvenva --position command source venv/bin/activate
  abbr --add pyvenvd --position command deactivate
  
  # cd
  abbr --add cd.. --position command cd ..
  
  # xattr
  abbr --add attributesread --position command xattr -l

  # downloaders
  abbr --add down --position command axel -a -n
  abbr --add aria16        --position command aria2c -j 16 -x 16
  abbr --add ariaipfsrelay --position command aria2c -j 1 -x 1 --file-allocation=none --allow-overwrite --no-file-allocation=100000M --auto-file-renaming=false
  abbr --add aria16torrent --position command aria2c -j 16 -x 16 --split=16 --enable-dht=true --bt-enable-lpd=true --bt-max-open-files=100
  abbr --add aria16noseed  --position command aria2c -j 16 -x 16 --split=16 --enable-dht=true --bt-enable-lpd=true --bt-max-open-files=100 --seed-time=0

  # disk management
  abbr --add listdisks --position command lsblk -io NAME,TYPE,SIZE,MOUNTPOINT,FSTYPE,MODEL
  abbr --add alldisks --position command listdisks
  
  abbr --add freespace    --position command df -kh .
  abbr --add freespaceall --position command df -kh

  abbr --add btr                   --position command btrfs
  abbr --add btrusage              --position command btrfs filesystem usage
  abbr --add btrqgroup             --position command btrfs qgroup show -r
  abbr --add btrusagebysnapshot    --position command btrfs filesystem du -s
  abbr --add btrqgrouprescan       --position command btrfs quota rescan /mnt/btr
  abbr --add btrqgrouprescanstatus --position command btrfs quota rescan -s /mnt/btr
  abbr --add btrremovesnapshot     --position command btrfs subvolume delete --commit-after

  # systemd
  abbr --add sc       --position command systemctl
  abbr --add scdr     --position command systemctl daemon-reload
  abbr --add scrd     --position command systemctl daemon-reload
  abbr --add sc+      --position command systemctl start
  abbr --add sc++     --position command systemctl enable
  abbr --add sc+++    --position command systemctl enable --now
  abbr --add sc-      --position command systemctl stop
  abbr --add sc--     --position command systemctl disable
  abbr --add sc---    --position command systemctl disable --now
  abbr --add scr      --position command systemctl restart
  abbr --add scs      --position command systemctl status -l
  abbr --add scls     --position command systemctl list-units --type=service --state=running
  abbr --add scfailed --position command systemctl list-units --state=failed

  # idk im stupid
  abbr --add zshconfig  --position command micro ~/.zshrc
  abbr --add fishconfig --position command micro ~/.config/fish/config.fish
  abbr --add copy --position command cp
  abbr --add move --position command mv
  abbr --add q --position command exit
  abbr --add lll --position command ll -p \| grep -v /
  abbr --add cpr --position command rsync -a --info=progress2
  abbr --add md --position command mkdir -p
  abbr --add rd --position command rmdir
  abbr --add c --position command clear
  # alias mvv in function

  # git
  abbr --add gs --position command git status
  abbr --add gpl --position command git pull
  abbr --add gc --position command git commit
  abbr --add gcm --position command --set-cursor git commit -m \"%\"
  abbr --add git-download-releases --position command dra download
  abbr --add ga. --position command git add .
  abbr --add gcommitstoday --position command begin\; git log --since=midnight --until=now --pretty=format:\"%h - %ar - %an: %s\"\;echo \"\"\; end
  abbr --add gcommitsweek --position command begin\; git log --since=$(get_monday_iso8601) --until=now --pretty=format:\"%h - %ar - %an: %s\"\;echo \"\"\; end
  
  # https://github.com/dweinstein/google-translate-cli
  abbr --add trl --position command trans
  abbr --add переведи --position command trans
  
  # yd-dlp
  abbr --add ytdl-audio --position command yt-dlp -f \'ba\' -x
  abbr --add ytdl-video --position command yt-dlp --embed-subs --sub-langs all --ppa \'EmbedSubtitle:-disposition:s:0 0\' -f \'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best\' --prefer-ffmpeg --merge-output-format mp4 -o \'Videos/%\(upload_date\>%Y-%m-%d\)s - %\(title\).197B \[\%\(id\)s\].%\(ext\)s\' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive \'archive.ytdlp\'
  abbr --add ytdl-video-meta --position command yt-dlp --write-info-json --write-comments --add-metadata --parse-metadata \'\%\(title\)s:%\(meta_title\)s\' --parse-metadata \'\%\(uploader\)s\:\%\(meta_artist\)s\' --write-description --write-thumbnail --embed-thumbnail --write-annotations --write-playlist-metafiles --write-all-thumbnails --write-url-link --embed-subs --sub-langs all --ppa \'EmbedSubtitle\:\-disposition\:s\:0\ 0\' -f \'bv\[ext=mp4\] +ba\[ext=m4a\]/best\[ext=mp4\]/best\' --prefer-ffmpeg --merge-output-format mp4 -o \'Videos/\%\(upload_date\>%Y-%m-%d\)s - \%\(title\).197B \[\%\(id\)s\].\%\(ext\)s\' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive \'archive.ytdlp\'
  abbr --add ytdl-list --position command yt-dlp --flat-playlist --print id
  abbr --add twitch-download --position command yt-dlp --downloader aria2c --downloader-args aria2c\:\'-c -j 32 -s 32 -x 16 --file-allocation=none --optimize-concurrent-downloads=true --http-accept-gzip=true\'
  abbr --add soundcloud-download --position command yt-dlp --match-filter \'format_id \!\*\= preview\'
  
  # fastfetch
  abbr --add neofetch --position command fastfetch

  # zellij
  # alias z in function
  abbr --add zls --position command zellij ls | grep -v "attach to resurrect"
  abbr --add zd  --position command zellij action new-pane --direction down
  abbr --add zr  --position command zellij action new-pane --direction right
  abbr --add z-  --position command zellij kill-session
  abbr --add z-- --position command zellij delete-session
  abbr --add zc  --position command zellij attach

  # mpv
  abbr --add mpvcli --position command mpv --no-config --vo=tct --really-quiet --profile=sw-fast --vo-tct-algo=half-blocks

  # btop
  abbr --add bntop --position command btop --config ~/configs/btop/bntop.conf -p 1

  # lsd
  abbr --add ls --position command lsd
  abbr --add la --position command lsd -lAhg
  abbr --add tree --position command lsd --tree

  # bat
  abbr --add bat --position command bat --paging=never
  
  # macosspecific
  if string match -q "Darwin*" -- (uname)
    # networksetup
    abbr --add listnetworkinterfaces --position command networksetup -listnetworkserviceorder
    abbr --add setroutes        --position command sudo networksetup -setadditionalroutes # name from listnetworinterfaces, ip, mask, router; multiple routes should be set through use of space between

    # gatekeeper
    abbr --add gatekeeper-disable --position command sudo spctl --master-disable
    abbr --add gatekeeper-enable  --position command sudo spctl --master-enable

    # power
    abbr --add macossafereboot      --position command sudo fdesetup authrestart
    abbr --add macossaferebootlater --position command sudo fdesetup authrestart -delayminutes -1
    abbr --add macossleep --position command pmset sleepnow

    # keychain
    abbr --add macosunlockkeychain --position command security unlock-keychain

    # gdu homebrew
    alias gdu=gdu-go

    # dircolors homebrew
    alias dircolors=gdircolors

    # yt-dlp
    alias yt-dlp="yt-dlp --ffmpeg-location /opt/homebrew/bin/ffmpeg"

    #For compilers to find openssl@3 you may need to set:
    set -x LDFLAGS "-L/opt/homebrew/opt/openssl@3/lib"
    set -x CPPFLAGS "-I/opt/homebrew/opt/openssl@3/include"

    #For pkg-config to find openssl@3 you may need to set:
    set -x PKG_CONFIG_PATH "/opt/homebrew/opt/openssl@3/lib/pkgconfig"

    # orbstack
    source ~/.orbstack/shell/init2.fish 2>/dev/null || :
  end

  # sudo
  if test (id -u) -eq 0
    # root
    abbr --add unmount --position command umount
    abbr --add iotop --position command sysctl kernel.task_delayacct=1 \&\& iotop \&\& sysctl kernel.task_delayacct=0
  else
    # not root
    abbr --add iotop --position command sudo sysctl kernel.task_delayacct=1 \&\& sudo iotop \&\& sudo sysctl kernel.task_delayacct=0
    abbr --add unmount --position command sudo umount
    abbr --add mount --position command sudo mount
    abbr --add zypper --position command sudo zypper
    abbr --add snap --position command sudo snap
    abbr --add yast --position command sudo yast
    abbr --add reboot --position command sudo systemctl --force reboot
    abbr --add shutdown --position command sudo /usr/sbin/shutdown now
    abbr --add systemctl --position command sudo systemctl
    abbr --add useradd --position command sudo useradd
    abbr --add userdel --position command sudo userdel
    abbr --add groupadd --position command sudo groupadd
    abbr --add usermod --position command sudo usermod
    abbr --add btrfs --position command sudo btrfs
    abbr --add mkfs.btrfs --position command sudo mkfs.btrfs
    abbr --add openvpn --position command sudo openvpn
    abbr --add iftop --position command sudo iftop
    abbr --add smbstatus --position command sudo smbstatus
    abbr --add apt --position command sudo apt
    abbr --add pacman --position command sudo pacman
  end

  # easy packet management
  switch (uname -s)
    case Linux
      # lunix
      if test -f /etc/os-release
        set -l os_id (grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        switch $os_id
          case rocky
            abbr --add updateall --position command sudo dnf clean all \&\& sudo dnf makecache \&\& sudo dnf upgrade -y \&\& fisher update
            abbr --add install   --position command sudo dnf install -y
            abbr --add uninstall --position command sudo dnf remove -y
          case arch
            abbr --add updateall --position command yay -Syu --devel --timeupdate \&\& yay -Sc \&\& fisher update
            abbr --add install   --position command yay -S
            abbr --add uninstall --position command yay -Rns
            abbr --add updatemirrors --position command cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak \&\& rate-mirrors arch \| sudo tee /etc/pacman.d/mirrorlist \&\& sudo pacman -Syy
          case debian ubuntu droidian
            abbr --add updateall --position command sudo apt update \&\& sudo apt upgrade \&\& sudo apt dist-upgrade \&\& fisher update
            abbr --add install   --position command sudo apt install
            abbr --add uninstall --position command sudo apt -y remove
          case opensuse-tumbleweed opensuse-leap
            abbr --add updateall --position command sudo zypper refresh \&\& sudo zypper dup \&\& fisher update
            abbr --add install   --position command sudo zypper -n install
            abbr --add uninstall --position command sudo zypper -n remove
          case alpine
            abbr --add updateall --position command apk upgrade --available \&\& fisher update
            abbr --add install   --position command apk add
            abbr --add uninstall --position command apk del
          case *
            abbr --add updateall --position command echo "Unknown Linux distribution"
            abbr --add install   --position command echo "Unknown Linux distribution"
            abbr --add uninstall --position command echo "Unknown Linux distribution"
        end
      else
        abbr --add updateall --position command echo "Unknown Linux distribution"
        abbr --add install   --position command echo "Unknown Linux distribution"
        abbr --add uninstall --position command echo "Unknown Linux distribution"
      end
    case Darwin
      # mAcos
      abbr --add updateall --position command brew update \&\& brew upgrade --no-quarantine --greedy \&\& brew cleanup --prune=all \&\& fisher update
      abbr --add install   --position command brew install --no-quarantine
      abbr --add uninstall --position command brew remove
    case *
      # unsupported
      abbr --add updateall --position command echo "Unknown operating system"
      abbr --add install   --position command echo "Unknown operating system"
      abbr --add uninstall --position command echo "Unknown operating system"
  end

  ### FISH SPECIFIC
  # add back !!, !$ (as !!!) and r as in classic shells
  abbr --add !! --position anywhere --function __last_command
  abbr --add !!! --position anywhere --function __last_argument
  abbr --add r --position command --function __last_command
  abbr --add where --position command whereis

  ### ENVIRONMENT
  # zellij
  set -x ZELLIJ_CONFIG_FILE "$HOME/configs/zellij/zellij.kdl"

  # you-should-use
  set -x YSU__MESSAGE_POSITION "after"
  set -x YSU__HARDCORE_MODE false
  set -x YSU__IGNORED_GLOBAL_ALIASES 'neofetch|cd\.\.|g|bi|sc'
    
  # telemetry
  # TODO: check up https://github.com/beatcracker/toptout/tree/master/examples
  set -x ET_NO_TELEMETRY "no telemetry"

  # systemd
  set -x SYSTEMD_PAGER ""
  set -x SYSTEMD_LESS ""

  # aider
  set -x AIDER_AUTO_COMMITS False

  # default editor
  if set -q SSH_CONNECTION
    set -x EDITOR micro
  else
    set -x EDITOR micro
  end

  # dircolors
  
  eval (dircolors -c "$HOME/configs/zsh/ZSH_CUSTOM/dircolors-solarized/dircolors.ansi-light" | string collect)
  # TODO: separate from zsh configs

  # pisces
  set -x pisces_only_insert_at_eol 1

  # sponge
  set -x sponge_purge_only_on_exit true

  # rust
  set -x RUST_BACKTRACE full

  # theos
  set -x THEOS ~/theos

  # Alpine bs
  if not set -q USER
    if type -q id
      set -x USER (id -un)
    else if type -q whoami
      set -x USER (whoami)
    else
      set -x USER unknown
    end
  end
  if not set -q SHELL
    if not set -q USER
      set USER (id -un ^/dev/null)
    end

    if type -q getent
      set -x SHELL (getent passwd $USER | cut -d: -f7)
    else
      set -x SHELL (awk -F: -v u="$USER" '$1==u{print $NF}' /etc/passwd ^/dev/null)
    end
  
    if test -z "$SHELL"
      set -x SHELL /bin/sh
    end
  end

  ### NO STUPID ENCODINGS
  set -x LC_COLLATE C
  set -x LANGUAGE en_US.UTF-8
  set -x LC_CTYPE en_US.UTF-8
  set -x LANG en_US.UTF-8

  ### INIT
  if not test -f ~/configs/.init
    git config --global core.pager ""
    touch ~/configs/.init
  end

  ### EXTERNAL PROGRAMS INIT
  #zoxide init fish | source
  pay-respects fish --alias fuck | source
  fzf --fish | source
  if test -f $HOME/.autojump/share/autojump/autojump.fish
    source $HOME/.autojump/share/autojump/autojump.fish
  else if test -f /usr/share/autojump/autojump.fish
    source /usr/share/autojump/autojump.fish
  else if test -f /opt/homebrew/share/autojump/autojump.fish
    source /opt/homebrew/share/autojump/autojump.fish
  end
  
  starship init fish | source
  # enable_transience  # enabling transient shell in starship
end
