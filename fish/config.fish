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
  alias targzip="tar -czvf"
  alias targunzip="tar -xzvf"
  alias untargz=targunzip
  alias targzls="tar -tzvf" # list files

  # docker
  alias d="docker"
  alias dps="docker ps --format \"table {{.ID}}   {{.Status}}     {{.Names}}      {{.Image}}      {{.Ports}}\""
  alias dip="docker inspect -f '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}'"
  alias dnwls="docker network ls"
  alias d-="docker stop"
  alias d+="docker start"
  alias drm="d rm"
  # alias dprune="d builder prune -a; d container prune; d image prune -a; d network prune; d volume prune"
  alias dprune="d system prune -a --volumes"

  # screen
  alias screen+="screen -S"
  alias screenc="screen -Rd"
  alias screencc="screen -x"
  alias screendaemon="screen -dmS"
  alias screenls="screen -list"

  # micro
  alias m="micro"

  # find
  alias findne="find 2>/dev/null"

  # python
  alias py="python3"
  alias pip="pip3"
  alias pyvenva="source venv/bin/activate"
  alias pyvenvd="deactivate"

  # screen
  alias screen+="screen -S"
  alias screenc="screen -Rd"
  alias screencc="screen -x"
  alias screendaemon="screen -dmS"
  alias screenls="screen -list"

  # micro
  alias m="micro"

  # find
  alias findne="find 2>/dev/null"

  # python
  alias py="python3"
  alias pip="pip3"
  alias pyvenva="source venv/bin/activate"
  alias pyvenvd="deactivate"
  
  # cd
  alias cd..="cd .."
  
  # xattr
  alias attributesread="xattr -l"

  # downloaders
  alias down="axel -a -n"
  alias aria16="aria2c -j 16 -x 16"
  alias ariaipfsrelay=" aria2c -j 1 -x 1 --file-allocation=none --allow-overwrite --no-file-allocation=100000M --auto-file-renaming=false"
  alias aria16torrent="aria16 --split=16 --enable-dht=true --bt-enable-lpd=true --bt-max-open-files=100 "
  alias aria16noseed="aria16torrent --seed-time=0"

  # disk management
  alias listdisks="lsblk -io NAME,TYPE,SIZE,MOUNTPOINT,FSTYPE,MODEL"
  alias alldisks="listdisks"
  alias freespace="df -kh ."
  alias freespaceall="df -kh"

  alias btr="btrfs"
  alias btrusage="btr filesystem usage"
  alias btrqgroup="btr qgroup show -r"
  alias btrusagebysnapshot="btr filesystem du -s"
  alias btrqgrouprescan="btrfs quota rescan /mnt/btr"
  alias btrqgrouprescanstatus="btrfs quota rescan -s /mnt/btr"
  alias btrremovesnapshot="btrfs subvolume delete --commit-after"

  # systemd
  alias sc="systemctl"
  alias scdr="sc daemon-reload"
  alias scrd="scdr"
  alias sc+="sc start"
  alias sc++="sc enable"
  alias sc+++="sc enable --now"
  alias sc-="sc stop"
  alias sc--="sc disable"
  alias sc---="sc disable --now"
  alias scr="sc restart"
  alias scs="sc status -l"
  alias scls="systemctl list-units --type=service --state=running"
  alias scfailed="sc list-units --state=failed"

  # idk im stupid
  alias zshconfig="micro ~/.zshrc"
  alias copy="cp"
  alias move="mv"
  alias q="exit"
  alias lll="ll -p | grep -v /"
  alias cpr='rsync -a --info=progress2'
  # alias mvv in function

  # git
  alias gs="git status"
  alias gpl="git pull"
  alias gdownloadreleases="dra download"
  # alias gcommitstoday in function
  # alias gcommitsweek in function
  
  # protonvpn
  alias protonvpnfastest="curl -s https://api.protonmail.ch/vpn/logicals | jq '[.LogicalServers[]|select(.Name|contains(\"$1\"))|select(.Tier==2)|{ServerName: .Name, ServerLoad: (.Load|tonumber),EntryIP: .Servers[].EntryIP}] | sort_by(.ServerLoad)' | jq -r '.[0:7]'"

  # https://github.com/dweinstein/google-translate-cli
  alias trl="trans"
  alias переведи="trans"
  
  # yd-dlp
  alias ytdl-audio="yt-dlp -f 'ba' -x"
  alias ytdl-video="yt-dlp --embed-subs --sub-langs all --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mp4 -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).197B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
  alias ytdl-video-meta="yt-dlp --write-info-json --write-comments --add-metadata --parse-metadata '%(title)s:%(meta_title)s' --parse-metadata '%(uploader)s:%(meta_artist)s' --write-description --write-thumbnail --embed-thumbnail --write-annotations --write-playlist-metafiles --write-all-thumbnails --write-url-link --embed-subs --sub-langs all --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mp4 -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).197B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
  alias ytdl-list="yt-dlp --flat-playlist --print id"
  alias twitch-download=" yt-dlp --downloader aria2c --downloader-args aria2c:'-c -j 32 -s 32 -x 16 --file-allocation=none --optimize-concurrent-downloads=true --http-accept-gzip=true'"
  alias soundcloud-download="yt-dlp --match-filter 'format_id !*= preview'"
  
  # fastfetch
  alias neofetch="fastfetch"

  # zellij
  # alias z in function
  alias zls='zellij ls | grep -v "attach to resurrect"'
  alias zd="zellij action new-pane --direction down"
  alias zr="zellij action new-pane --direction right"
  # alias z- in funtcion
  # alias z-- in funtcion
  # alias zc in function

  # mpv
  alias mpvcli="mpv --no-config --vo=tct --really-quiet --profile=sw-fast --vo-tct-algo=half-blocks"

  # btop
  alias bntop="btop --config ~/configs/btop/bntop.conf -p 1"
  
  # macosspecific
  if string match -q "darwin*" -- $OSTYPE
    # networksetup
    alias listnetworkinterfaces="networksetup -listnetworkserviceorder"
    alias setroutes="sudo networksetup -setadditionalroutes " # name from listnetworinterfaces, ip, mask, router; multiple routes should be set through use of space between

    # gatekeeper
    alias gatekeeper-disable="sudo spctl --master-disable"
    alias gatekeeper-enable="sudo spctl --master-enable"

    # power
    alias macossafereboot="sudo fdesetup authrestart"
    alias macossaferebootlater="sudo fdesetup authrestart -delayminutes -1"
    alias macossleep="pmset sleepnow"

    # keychain
    alias macosunlockkeychain="security unlock-keychain"

    # gdu homebrew
    alias gdu="gdu-go"

    # dircolors homebrew
    alias dircolors="gdircolors"

    # yt-dlp
    alias yt-dlp="yt-dlp --ffmpeg-location /usr/bin/ffmpeg"

    #For compilers to find openssl@3 you may need to set:
    set -x LDFLAGS "-L/opt/homebrew/opt/openssl@3/lib"
    set -x CPPFLAGS "-I/opt/homebrew/opt/openssl@3/include"

    #For pkg-config to find openssl@3 you may need to set:
    set -x PKG_CONFIG_PATH "/opt/homebrew/opt/openssl@3/lib/pkgconfig"
  end

  # sudo
  if test (id -u) -eq 0
    # root
    alias unmount="umount"
    alias iotop="sysctl kernel.task_delayacct=1; iotop; sysctl kernel.task_delayacct=0"
  else
    # not root
    alias unmount="sudo umount"
    alias mount="sudo mount"
    alias zypper="sudo zypper"
    alias snap="sudo snap"
    alias yast="sudo yast"
    alias reboot="sudo systemctl --force reboot"
    alias shutdown="sudo /usr/sbin/shutdown now"
    alias systemctl="sudo systemctl"
    alias useradd="sudo useradd"
    alias userdel="sudo userdel"
    alias groupadd="sudo groupadd"
    alias usermod="sudo usermod"
    alias btrfs="sudo btrfs"
    alias mkfs.btrfs="sudo mkfs.btrfs"
    alias openvpn="sudo openvpn"
    alias iotop="sudo sysctl kernel.task_delayacct=1; sudo iotop; sudo sysctl kernel.task_delayacct=0"
    alias iftop="sudo iftop"
    alias smbstatus="sudo smbstatus"
    alias apt="sudo apt"
    alias pacman="sudo pacman"
  end

  # easy packet management
  switch (uname -s)
    case Linux
      # lunix
      if test -f /etc/os-release
        set -l os_id (grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
        switch $os_id
          case rocky
            alias updateall="dnf clean all && dnf makecache && dnf upgrade -y && fisher update"
            alias install="dnf install -y"
            alias uninstall="dnf remove -y"
          case arch
            alias updateall='yay -Syu --devel --timeupdate; yay -Sc && fisher update --all'
            alias install="yay -S"
            alias uninstall="yay -Rns"
            alias updatemirrors="cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak; rate-mirrors arch | sudo tee /etc/pacman.d/mirrorlist; sudo pacman -Syy"
          case debian ubuntu droidian
            alias updateall='apt update && apt upgrade && apt dist-upgrade && fisher update'
            alias install="apt install"
            alias uninstall="apt -y remove"
          case opensuse-tumbleweed opensuse-leap
            alias updateall='zypper refresh && zypper dup && fisher update --all'
            alias install="zypper -n install"
            alias uninstall="zypper -n remove"
          case alpine
            alias updateall='apk upgrade --available && fisher update --all'
            alias install='apk add'
            alias uninstall='apk del'
          case *
            alias updateall='echo "Unknown Linux distribution"'
            alias install='echo "Unknown Linux distribution"'
            alias uninstall='echo "Unknown Linux distribution"'
        end
      else
        alias updateall='echo "Unknown Linux distribution"'
        alias install='echo "Unknown Linux distribution"'
        alias uninstall='echo "Unknown Linux distribution"'
      end
    case Darwin
      # mAcos
      alias updateall='brew update; brew upgrade --no-quarantine --greedy; brew cleanup --prune=all && fisher update'
      alias install='brew install --no-quarantine'
      alias uninstall='brew remove'
    case *
      # unsupported
      alias updateall='echo "Unknown operating system"'
      alias install='echo "Unknown operating system"'
      alias uninstall='echo "Unknown operating system"'
  end

  ### FISH SPECIFIC
  # add back !!, !$ (as !!!) and r as in classic shells
  abbr --add !! --position anywhere --function __last_command
  abbr --add !!! --position anywhere --function __last_argument
  abbr --add r --position command --function __last_command


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
  end
  
  starship init fish | source
  # enable_transience  # enabling transient shell in starship
end
