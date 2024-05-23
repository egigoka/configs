### powerlevel10k
	# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
	# Initialization code that may require console input (password prompts, [y/n]
	# confirmations, etc.) must go above this block; everything else may go below.
	if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
	fi

	# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
	[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

### PATH
	contains $PATH . || export PATH=$PATH:.
	contains $PATH /home/egigoka/.local/bin || export PATH=$PATH:/home/egigoka/.local/bin
	contains $PATH /etc/pycharm-2020.2.1/bin/ || export PATH=$PATH:/etc/pycharm-2020.2.1/bin/
	contains $PATH /home/egigoka/go/bin/ || export PATH=$PATH:/home/egigoka/go/bin/
	contains $PATH /home/egigoka/.cargo/bin || export PATH=$PATH:/home/egigoka/.cargo/bin  # rust
	contains $PATH /home/egorov/.local/bin || export PATH=$PATH:/home/egorov/.local/bin
	contains $PATH /var/mobile/.local/bin || export PATH=$PATH:/var/mobile/.local/bin
	contains $PATH /opt/homebrew/opt/llvm/bin || export PATH=/opt/homebrew/opt/llvm/bin:$PATH
	contains $PATH /opt/homebrew/opt/llvm/bin || export PATH=$PATH:/opt/homebrew/opt/llvm/bin
	contains $PATH /usr/sbin || export PATH=$PATH:/usr/sbin
	contains $PATH ~/.local/bin/ || export PATH=$PATH:~/.local/bin/
	contains $PATH /usr/games || export PATH=$PATH:/usr/games

### aliases
	# docker
	alias d="docker"
	alias dps="docker ps --format \"table {{.ID}}   {{.Status}}     {{.Names}}      {{.Image}}      {{.Ports}}\""
	alias dip="docker inspect -f '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}'"
	alias dnwls="docker network ls"
	alias d-="docker stop"
	alias d+="docker start"
	alias drm="d rm"

	# screen
	alias screen+="screen -S"
	alias screenc="screen -Rd"
	alias screendaemon="screen -dmS"
	alias screenls="screen -list"
	alias screencc="screen -x"

	# micro
	alias m="micro"

	# python
	alias py="python3"
	alias pip="pip3"
	alias pyvenva="source venv/bin/activate"
	alias pyvenvd="deactivate"

	# cd
	alias cd..="cd .."

	# downloaders
	alias down="axel -a -n"
	alias aria16="aria2c -j 16 -x 16"

	if [[ "$OSTYPE" == "darwin"* ]]; then
	    # networksetup
	    alias listnetworkinterfaces="networksetup -listnetworkserviceorder"
	    alias setroutes="sudo networksetup -setadditionalroutes " # name from listnetworinterfaces, ip, mask, router; multiple routes should be set through use of space between

	    # gatekeeper
	    alias gatekeeper-disable="sudo spctl --master-disable"
	    alias gatekeeper-enable="sudo spctl --master-enable"
	fi
	
	# sudo and doas
	alias sudo="doas"

	alias saferebootmacos="sudo fdesetup authrestart"
	alias saferebootmacoslater="sudo fdesetup authrestart -delayminutes -1"
	alias sleepmacos="pmset sleepnow"
	alias macosunlockkeychain="security unlock-keychain"

	if [[ $UID == 0 || $EUID == 0 ]]; then
	   # root
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
	   alias iotop="sudo iotop"
	   alias iftop="sudo iftop"
	   alias smbstatus="sudo smbstatus"
	   alias apt="sudo apt"
	   alias yay="sudo yay"
	   alias pacman="sudo pacman"
	fi

	# easy packet management
	case "$(uname -s)" in
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                    arch)
                        alias updateall='yay -Syu --devel --timeupdate'
                        alias install="yay -S"
                        alias uninstall="yay -Rns"
                        ;;
                    debian|ubuntu)
                        alias updateall='apt update && apt upgrade -y'
                        alias install="apt install"
                        alias uninstall="apt -y remove"
                        ;;
                    opensuse)
                        alias updateall='zypper refresh;zypper dup'
                        alias install="zypper -n install"
                        alias uninstall="zypper -n remove"
                        ;;
                    *)
                        alias updateall='echo "Unknown Linux distribution"'
                        alias install='echo "Unknown Linux distribution"'
                        alias uninstall='echo "Unknown Linux distribution"'
                        ;;
                esac
            else
                alias updateall='echo "Unknown Linux distribution"'
                alias install='echo "Unknown Linux distribution"'
                alias uninstall='echo "Unknown Linux distribution"'
            fi
            ;;
        Darwin)
            alias updateall='brew update; brew upgrade --no-quarantine --greedy; brew cleanup --prune=all'
            alias install='brew install --no-quarantine'
            alias uninstall='brew remove --no-quarantine'
            ;;
        *)
            alias updateall='echo "Unknown operating system"'
            alias install='echo "Unknown operating system"'
            alias uninstall='echo "Unknown operating system"'
            ;;
    esac

	# outdated commands
	if ! [[ "$OSTYPE" == "darwin"* ]]; then
	  alias ipconfig="ip a"
	  alias ifconfig="ipconfig"
	fi


	# disk management
	alias listdisks="lsblk -io NAME,TYPE,SIZE,MOUNTPOINT,FSTYPE,MODEL"
	alias alldisks="listdisks"
	alias freespace="df -kh ."
	alias freespaceall="df -kh"
	alias listdisks="lsblk"
	alias btr="btrfs"
	alias btrusage="btr filesystem usage"
	alias diskusage="ncdu"

	# systemd
	alias sc="systemctl"  # anyway I hate vim
	alias scdr="sc daemon-reload"
	alias scrd="scdr"
	alias sc+="sc start"
	alias sc-="sc stop"
	alias scr="sc restart"
	alias scs="sc status -l"
	alias sc--="sc disable"
	alias sc++="sc enable"
	alias scls="systemctl list-units --type=service --state=running"

	# idk im stupid
	alias zshconfig="micro ~/.zshrc"
	alias copy="cp"
	alias move="mv"
	alias q="exit"
	alias lll="ll -p | grep -v /"

	# git
	alias gs="git status"
	alias gpl="git pull"

	# protonvpn
	alias protonvpnfastest="curl -s https://api.protonmail.ch/vpn/logicals | jq '[.LogicalServers[]|select(.Name|contains(\"$1\"))|select(.Tier==2)|{ServerName: .Name, ServerLoad: (.Load|tonumber),EntryIP: .Servers[].EntryIP}] | sort_by(.ServerLoad)' | jq -r '.[0:7]'"

	# https://github.com/dweinstein/google-translate-cli
	alias trl="trans"
	alias переведи="trans"

	# yd-dlp
	alias ytdl-audio="yt-dlp -f 'ba' -x --audio-format mp3"
	alias ytdl-video="yt-dlp --embed-subs --sub-langs all --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mkv -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).197B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
	alias ytdl-video-meta="yt-dlp --write-info-json --write-comments --add-metadata --parse-metadata '%(title)s:%(meta_title)s' --parse-metadata '%(uploader)s:%(meta_artist)s' --write-description --write-thumbnail --embed-thumbnail --write-annotations --write-playlist-metafiles --write-all-thumbnails --write-url-link --embed-subs --sub-langs all --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mkv -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).197B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
	alias twitch-download=" yt-dlp --downloader aria2c --downloader-args aria2c:'-c -j 32 -s 32 -x 16 --file-allocation=none --optimize-concurrent-downloads=true --http-accept-gzip=true"
	alias ytdl-list="yt-dlp --flat-playlist --print id"

	# fastfetch
	alias fastfetchdeps="install fastfetch chafa dbus dconf ddcutil directx-headers glib2 imagemagick libnm libpulse mesa libxrandr ocl-icd hwdata vulkan-icd-loader xfconf zlib libdrm || echo chafa dbus dconf ddcutil directx-headers glib2 imagemagick libnm libpulse mesa libxrandr ocl-icd hwdata vulkan-icd-loader xfconf zlib libdrm"
	alias neofetch="fastfetch"

	# zellij
	alias z="zellij"
	alias zd="zellij action new-pane --direction down"
	alias zr="zellij action new-pane --direction right"

### functions
	contains()
	        {
	        string="$1"
	        substring="$2"
	        if test "${string#*$substring}" != "$string"
	        then
	                return 0    # $substring is in $string
	        else
	                return 1    # $substring is not in $string
	        fi
	        }

	function sudoz ()
	        {
	        args="$@"
	        sudo zsh -i -c "$args"
	        }

	function time_dotted()
	        {
	        return date +"%Y.%m.%d_at_%H.%M.%S.%N"
	        }

	change_extension() {
	  if [ $# -lt 2 ]; then
	    echo "Usage: change_extension <filename> <new_extension>"
	    return 1
	  fi

	  local filename="$1"
	  local new_extension="$2"

	  local base_filename=$(basename "$filename" .${filename##*.})
	  local new_filename="$base_filename.$new_extension"

	  mv "$filename" "$new_filename"
	}

	btrsnap() {
	    args = "$@"
	    if [ "$1" != "" ]
	    then
	        time = time_dotted()
	        sudo btrfs subvolume snapshot / /snap/time
	    else

	    fi
	}

### zellij
	export ZELLIJ_CONFIG_FILE="$HOME/configs/zellij.kdl"

### you-should-use
	Found existing alias for "docker". You should use: "d"
	export YSU_MESSAGE_FORMAT="$(tput setaf 1)Hey! I found %alias_type for \"%command\": \"%alias$\"(tput sgr0)"
	export YSU_MESSAGE_POSITION="after"

### oh-my-zsh

	# Path to your oh-my-zsh installation.
	export ZSH="$HOME/.oh-my-zsh"
	export ZSH_CUSTOM="$HOME/configs/ZSH_CUSTOM"

	# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
	# ZSH_THEME="agnoster"
	ZSH_THEME="powerlevel10k/powerlevel10k"

	ZLE_RPROMPT_INDENT=0

	HYPHEN_INSENSITIVE="true"

	ET_NO_TELEMETRY="fuck telemetry"

	export UPDATE_ZSH_DAYS=13

	ENABLE_CORRECTION="false" # correction conflicts with colored-man-pages_mod

	COMPLETION_WAITING_DOTS="true"

	HIST_STAMPS="yyyy.mm.dd"

	ZSH_COLORIZE_TOOL=chroma
	ZSH_COLORIZE_STYLE="colorful"
	ZSH_COLORIZE_CHROMA_FORMATTER=terminal256

	# Which plugins would you like to load?
	# Standard plugins can be found in $ZSH/plugins/
	# Custom plugins may be added to $ZSH_CUSTOM/plugins/
	# Add wisely, as too many plugins slow down shell startup.
	plugins=(thefuck git python compleat autojump colorize zsh-syntax-highlighting zsh-autosuggestions docker docker-compose command-not-found macos autoupdate colored-man-pages_mod omz-homebrew last-working-dir uvenv you-should-use)

	source $ZSH/oh-my-zsh.sh

### external aliases
	eval $(thefuck --alias)
	eval "$(fzf --zsh)"

### systemd configs
	export SYSTEMD_PAGER=

### default editor
	if [[ -n $SSH_CONNECTION ]]; then
	  export EDITOR='micro'
	else
	  export EDITOR='micro'
	fi

### show current directory items when changing directories
	autoload -U add-zsh-hook
	add-zsh-hook -Uz chpwd ()
	        {
	        # this hooks into chpwd (function to change working directory)
	        la;
	        }

### macos fixes
	if [[ "$OSTYPE" == "darwin"* ]]; then
	        #For compilers to find openssl@3 you may need to set:
	        export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib"
	        export CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include"

	        #For pkg-config to find openssl@3 you may need to set:
	        export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig"
	fi

	if [[ "$OSTYPE" == "darwin" ]]; then
	  alias yt-dlp="yt-dlp --ffmpeg-location /usr/bin/ffmpeg";
	fi

### encodings fix
	export LC_COLLATE=C
	export LANGUAGE=en_US.UTF-8
	export LC_CTYPE=en_US.UTF-8
	export LANG=en_US.UTF-8

### rust configs
	export RUST_BACKTRACE=full

### conda
	# >>> conda initialize >>>
	# !! Contents within this block are managed by 'conda init' !!
	__conda_setup="$('/Users/egigoka/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
	if [ $? -eq 0 ]; then
	    eval "$__conda_setup"
	else
	    if [ -f "/Users/egigoka/miniconda3/etc/profile.d/conda.sh" ]; then
	        . "/Users/egigoka/miniconda3/etc/profile.d/conda.sh"
	    else
	        export PATH="/Users/egigoka/miniconda3/bin:$PATH"
	    fi
	fi
	unset __conda_setup
	# <<< conda initialize <<<
