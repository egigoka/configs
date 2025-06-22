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
	contains $PATH /opt/homebrew/bin || export PATH=/opt/homebrew/bin:$PATH
	contains $PATH /home/egigoka/.local/bin || export PATH=$PATH:/home/egigoka/.local/bin
	contains $PATH /etc/pycharm-2020.2.1/bin/ || export PATH=$PATH:/etc/pycharm-2020.2.1/bin/
	contains $PATH /home/egigoka/go/bin/ || export PATH=$PATH:/home/egigoka/go/bin/
	contains $PATH /home/egigoka/.cargo/bin || export PATH=$PATH:/home/egigoka/.cargo/bin  # rust
	contains $PATH /home/egorov/.local/bin || export PATH=$PATH:/home/egorov/.local/bin
	contains $PATH /var/mobile/.local/bin || export PATH=$PATH:/var/mobile/.local/bin
	contains $PATH /opt/homebrew/opt/llvm/bin || export PATH=/opt/homebrew/opt/llvm/bin:$PATH
	contains $PATH /usr/sbin || export PATH=$PATH:/usr/sbin
	contains $PATH ~/.local/bin/ || export PATH=$PATH:~/.local/bin/
	contains $PATH /usr/games || export PATH=$PATH:/usr/games
	contains $PATH ~/go/bin || export PATH=$PATH:~/go/bin
	contains $PATH ~/.cargo/bin || export PATH=$PATH:~/.cargo/bin
	contains $PATH /home/linuxbrew/.linuxbrew/bin/ || export PATH=$PATH:/home/linuxbrew/.linuxbrew/bin/

### aliases
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

	# screen
	alias screen+="screen -S"
	alias screenc="screen -Rd"
	alias screendaemon="screen -dmS"
	alias screenls="screen -list"
	alias screencc="screen -x"

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

	if [[ "$OSTYPE" == "darwin"* ]]; then
	    # networksetup
	    alias listnetworkinterfaces="networksetup -listnetworkserviceorder"
	    alias setroutes="sudo networksetup -setadditionalroutes " # name from listnetworinterfaces, ip, mask, router; multiple routes should be set through use of space between

	    # gatekeeper
	    alias gatekeeper-disable="sudo spctl --master-disable"
	    alias gatekeeper-enable="sudo spctl --master-enable"
	fi
	
	# macosspecific
	alias macossafereboot="sudo fdesetup authrestart"
	alias macossaferebootlater="sudo fdesetup authrestart -delayminutes -1"
	alias macossleep="pmset sleepnow"
	alias macosunlockkeychain="security unlock-keychain"

	# sudo
	if [[ $UID == 0 || $EUID == 0 ]]; then
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
	fi

	# easy packet management
	case "$(uname -s)" in
        Linux)
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case "$ID" in
                	rocky)
                		alias updateall="dnf clean all && dnf makecache && dnf upgrade -y"
                		alias install="dnf install -y"
                		alias uninstall="dnf remove -y"
                		;;
                    arch)
                        alias updateall='yay -Syu --devel --timeupdate; yay -Sc'
                        alias install="yay -S"
                        alias uninstall="yay -Rns"
                        alias updatemirrors="cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak; rate-mirrors arch | sudo tee /etc/pacman.d/mirrorlist; sudo pacman -Syy"
                        ;;
                    debian|ubuntu|droidian)
                        alias updateall='apt update && apt upgrade && apt dist-upgrade'
                        alias install="apt install"
                        alias uninstall="apt -y remove"
                        ;;
                    opensuse-tumbleweed|opensuse-leap)
                        alias updateall='zypper refresh && zypper dup'
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
            alias uninstall='brew remove'
            ;;
        *)
            alias updateall='echo "Unknown operating system"'
            alias install='echo "Unknown operating system"'
            alias uninstall='echo "Unknown operating system"'
            ;;
    esac


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

	alias diskusage="ncdu"

	# systemd
	alias sc="systemctl"
	alias scdr="sc daemon-reload"
	alias scrd="scdr"
	alias sc+="sc start"
	alias sc-="sc stop"
	alias scr="sc restart"
	alias scs="sc status -l"
	alias sc--="sc disable"
	alias sc++="sc enable"
	alias scls="systemctl list-units --type=service --state=running"
	alias scfailed="sc list-units --state=failed"

	# idk im stupid
	alias zshconfig="micro ~/.zshrc"
	alias copy="cp"
	alias move="mv"
	alias q="exit"
	alias lll="ll -p | grep -v /"
	alias mvv='rsync -a --remove-source-files --info=progress2'
	alias cpr='rsync -a --info=progress2'

	# git
	alias gs="git status"
	alias gpl="git pull"
	alias gcommitstoday=" (git log --since=midnight --until=now --pretty=format:\"%h - %ar - %an: %s\"; echo)"
	alias gdownloadreleases="dra download"

	# protonvpn
	alias protonvpnfastest="curl -s https://api.protonmail.ch/vpn/logicals | jq '[.LogicalServers[]|select(.Name|contains(\"$1\"))|select(.Tier==2)|{ServerName: .Name, ServerLoad: (.Load|tonumber),EntryIP: .Servers[].EntryIP}] | sort_by(.ServerLoad)' | jq -r '.[0:7]'"

	# https://github.com/dweinstein/google-translate-cli
	alias trl="trans"
	alias переведи="trans"

	# yd-dlp
	alias ytdl-audio="yt-dlp -f 'ba' -x --audio-format mp3"
	alias ytdl-video="yt-dlp --embed-subs --sub-langs all --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mkv -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).197B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
	alias ytdl-video-meta="yt-dlp --write-info-json --write-comments --add-metadata --parse-metadata '%(title)s:%(meta_title)s' --parse-metadata '%(uploader)s:%(meta_artist)s' --write-description --write-thumbnail --embed-thumbnail --write-annotations --write-playlist-metafiles --write-all-thumbnails --write-url-link --embed-subs --sub-langs all --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mkv -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).197B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
	alias twitch-download=" yt-dlp --downloader aria2c --downloader-args aria2c:'-c -j 32 -s 32 -x 16 --file-allocation=none --optimize-concurrent-downloads=true --http-accept-gzip=true'"
	alias ytdl-list="yt-dlp --flat-playlist --print id"
	alias soundcloud-download="yt-dlp --match-filter 'format_id !*= preview'"

	# fastfetch
	alias fastfetchdeps="install fastfetch chafa dbus dconf ddcutil directx-headers glib2 imagemagick libnm libpulse mesa libxrandr ocl-icd hwdata vulkan-icd-loader xfconf zlib libdrm || echo chafa dbus dconf ddcutil directx-headers glib2 imagemagick libnm libpulse mesa libxrandr ocl-icd hwdata vulkan-icd-loader xfconf zlib libdrm"
	alias neofetch="fastfetch"

	# zellij
	z() {
	    if [ "$#" -eq 0 ]; then
	        echo "Error: session should have name."
	        return 1
	    else
	        session_name="$*"
	        zellij --session "$session_name" || zellij_attach "$session_name"
	        if [ "$(zellij list-sessions --no-formatting | grep -E \"^$session_name\s+EXITED\" | wc -l)" -eq 1 ]; then
	            zellij delete-session "$session_name"
	        fi
	    fi
	}
	alias zls='zellij ls | grep -v "attach to resurrect"'
	alias zd="zellij action new-pane --direction down"
	alias zr="zellij action new-pane --direction right"
	
	zc() {
		if [ "$#" -eq 0 ]; then
		    sessions=$(zellij list-sessions --reverse --no-formatting | grep -v "(EXITED" | awk '{printf "\033[1;36m%-20s\033[0m %s\n", $1, $3}')
		    selected_session=$(echo "$sessions" | fzf --height ${FZF_TMUX_HEIGHT:-20%} --ansi | awk '{print $1}')
		    if [ -n "$selected_session" ]; then
		        zellij_attach "$selected_session"
		    else
		        echo "No session selected."
		    fi
		else
	        zellij_attach "$*"
	    fi
	}

	z-() {
		if [ "$#" -eq 0 ]; then
		    sessions=$(zellij list-sessions --reverse --no-formatting | grep -v "(EXITED" | awk '{printf "\033[1;36m%-20s\033[0m %s\n", $1, $3}')
		    selected_session=$(echo "$sessions" | fzf --height ${FZF_TMUX_HEIGHT:-20%} --ansi | awk '{print $1}')
		    if [ -n "$selected_session" ]; then
		        zellij_kill_session "$selected_session"
		    else
		        echo "No session selected."
		    fi
		else
	        zellij_kill_session "$*"
	    fi
	}

	z--() {
		if [ "$#" -eq 0 ]; then
		    sessions=$(zellij list-sessions --reverse --no-formatting | grep -v "(EXITED" | awk '{printf "\033[1;36m%-20s\033[0m %s\n", $1, $3}')
		    selected_session=$(echo "$sessions" | fzf --height ${FZF_TMUX_HEIGHT:-20%} --ansi | awk '{print $1}')
		    if [ -n "$selected_session" ]; then
		        zellij_delete_session "$selected_session"
		    else
		        echo "No session selected."
		    fi
		else
	        zellij_delete_session "$*"
	    fi
	}
	
### functions
	clip() {
	    local input
	    input=$(cat)
	    printf "\033]52;c;$(echo -n "$input" | base64 | tr -d '\n')\a"
	}
	
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
	
	zellij_attach() {
        zellij attach "$*"
    }
    
    zellij_kill_session() {
    	zellij kill-session "$*"
    }

    zellij_delete_session() {
    	zellij delete-session "$*"
    }

	shh () {
	    local secret="$1"
	    local replacement="$2"
	    
	    if [[ -z "$secret" || -z "$replacement" ]]; then
	        echo "Usage: shh <secret_to_replace> <replacement_text>"
	        return 1
	    fi
	    
	    #sed "s/$secret/$replacement/g"
	    sed -e "s@${secret//@/\\@}@${replacement//@/\\@}@g"
	}

### zellij
	export ZELLIJ_CONFIG_FILE="$HOME/configs/zellij.kdl"

### you-should-use
	export YSU_MESSAGE_FORMAT="$(tput setaf 1)Hey! I found %alias_type for \"%command\": \"%alias\"$(tput sgr0)"
	export YSU_MESSAGE_POSITION="after"
	export YSU_IGNORED_ALIASES=("g" "bi" "cd..")

### oh-my-zsh

	# Path to your oh-my-zsh installation.
	export ZSH="$HOME/.oh-my-zsh"
	export ZSH_CUSTOM="$HOME/configs/ZSH_CUSTOM"

	# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
	# ZSH_THEME="agnoster"
	ZSH_THEME="powerlevel10k/powerlevel10k"

	ZLE_RPROMPT_INDENT=0

	HYPHEN_INSENSITIVE="true"

	HIST_STAMPS="%Y.%m.%d %T"

	ET_NO_TELEMETRY="fuck telemetry"

	export UPDATE_ZSH_DAYS=13

	ENABLE_CORRECTION="false" # correction conflicts with colored-man-pages_mod

	COMPLETION_WAITING_DOTS="true"

	ZSH_COLORIZE_TOOL=chroma
	ZSH_COLORIZE_STYLE="colorful"
	ZSH_COLORIZE_CHROMA_FORMATTER=terminal256

	# Which plugins would you like to load?
	# Standard plugins can be found in $ZSH/plugins/
	# Custom plugins may be added to $ZSH_CUSTOM/plugins/
	# Add wisely, as too many plugins slow down shell startup.
	plugins=(git python compleat autojump colorize zsh-syntax-highlighting zsh-autosuggestions docker docker-compose command-not-found macos autoupdate colored-man-pages_mod omz-homebrew last-working-dir uvenv you-should-use)

	source $ZSH/oh-my-zsh.sh

### external aliases
	#eval $(thefuck --alias)
	eval "$(pay-respects zsh --alias fuck)"
	eval "$(fzf --zsh)"

### systemd configs
	export SYSTEMD_PAGER=
	export SYSTEMD_LESS=

### aider configs
	export AIDER_AUTO_COMMITS=False

### default editor
	if [[ -n $SSH_CONNECTION ]]; then
	  export EDITOR='micro'
	else
	  export EDITOR='micro'
	fi

### ls configs
	if [[ "$OSTYPE" == "darwin"* ]]; then
		alias dircolors="gdircolors"
	fi
	eval `dircolors $ZSH_CUSTOM/dircolors-solarized/dircolors.ansi-light`

### show current directory items when changing directories
	list_dir() {
		la;
	}
	
	#list_dir
	chpwd_functions+=(list_dir)

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
export THEOS=~/theos


# filen-cli
PATH=$PATH:~/.filen-cli/bin
