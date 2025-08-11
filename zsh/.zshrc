### powerlevel10k
	# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
	# Initialization code that may require console input (password prompts, [y/n]
	# confirmations, etc.) must go above this block; everything else may go below.
	if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
	  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
	fi

	# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
	[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

### INIT
	if [[ ! -f ~/configs/.init ]] then
		git config --global core.pager ""
		touch ~/configs/.init
	fi

### PATH
	contains $PATH ~/bin || export PATH=$PATH:~/bin
	contains $PATH ~/go/bin/ || export PATH=$PATH:~/go/bin/
	contains $PATH ~/.cargo/bin || export PATH=$PATH:~/.cargo/bin  # rust
	contains $PATH ~/.local/bin/ || export PATH=$PATH:~/.local/bin/
	contains $PATH ~/.filen-cli/bin || export PATH=$PATH:~/.filen-cli/bin
	contains $PATH /opt/homebrew/bin || export PATH=/opt/homebrew/bin:$PATH
	contains $PATH /opt/homebrew/opt/llvm/bin || export PATH=/opt/homebrew/opt/llvm/bin:$PATH
	contains $PATH /usr/local/sbin || export PATH=$PATH:/usr/local/sbin
	contains $PATH /usr/local/bin || export PATH=$PATH:/usr/local/bin
	contains $PATH /usr/games || export PATH=$PATH:/usr/games
	contains $PATH /usr/sbin || export PATH=$PATH:/usr/sbin
	contains $PATH /usr/bin || export PATH=$PATH:/usr/bin
	contains $PATH /sbin || export PATH=$PATH:/sbin
	contains $PATH /bin || export PATH=$PATH:/bin
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

	# macosspecific
	if [[ "$OSTYPE" == "darwin"* ]]; then
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
	fi

	if [[ "$OSTYPE" == "linux-gnu" ]]; then
		alias resetgraphics="sudo systemctl isolate multi-user.target; sleep 30; sudo systemctl start graphical.target"
	fi

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
                    alpine)
                    	alias updateall='apk upgrade --available'
                    	alias install='apk add'
                    	alias uninstall='apk del'
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

	if [[ "$OSTYPE" == "darwin"* ]]; then
		alias gdu="gdu-go"
	fi

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
	mvv() {
	  if (( $# < 2 )); then
	    print -u2 "Usage: mvv <source>... <destination>"
	    return 1
	  fi
	
	  typeset -a sources
	  sources=( "${(@)argv[1,-2]}" )
	  local dest=$argv[-1]
	
	  typeset -a rsync_opts
	  rsync_opts=( -a --remove-source-files --info=progress2 )
	
	  local need_trailing_slash=false
	  if (( ${#sources[@]} == 1 )) && [[ ! -e $dest ]] && [[ -d ${sources[1]} ]]; then
	    need_trailing_slash=true
	  fi
	
	  typeset -a rsync_srcs
	  for src in "${sources[@]}"; do
	    if $need_trailing_slash; then
	      # copy CONTENTS of src/ → dest
	      rsync_srcs+=( "${src}/" )
	    else
	      rsync_srcs+=( "$src" )
	    fi
	  done
	
	  rsync "${rsync_opts[@]}" "${rsync_srcs[@]}" "$dest" || return $?
	
	  for src in "${sources[@]}"; do
	    [[ -d $src ]] || continue
	    find "$src" -depth -type d -empty -exec rmdir {} \;
	  done
	}

	# git
	alias gs="git status"
	alias gpl="git pull"
	alias gdownloadreleases="dra download"
	alias gcommitstoday="(git log --since=midnight --until=now --pretty=format:\"%h - %ar - %an: %s\"; echo)"
	get_monday_iso8601() {
	  if [[ "${OSTYPE}" == darwin* ]]; then
	    local ts=$(date -v-mon -v0H -v0M '+%Y-%m-%dT%H:%M:%S')
	    local tz=$(date +%z)        # e.g. "-0700"
	    tz="${tz:0:3}:${tz:3}"      # -> "-07:00"
	    printf '%s%s\n' "$ts" "$tz"
	  else
	    local dow offset
        dow=$(date +%u)                       # 1..7, Mon=1
        offset=$(( dow - 1 ))                 # 0 for Mon, 1 for Tue, …
        # date -d "YYYY-MM-DD -N days" gives midnight minus N days
        date -d "$(date +%Y-%m-%d) -${offset} days" \
          '+%Y-%m-%dT%H:%M:%S%:z'
	  fi
	}
	
	gcommitsweek() {
	  local since
	  since=$(get_monday_iso8601)
	  git log \
	    --since="$since" \
	    --until=now \
	    --pretty=format:"%h - %ar - %an: %s" \
	    "$@"
	  
	}

	# protonvpn
	alias protonvpnfastest="curl -s https://api.protonmail.ch/vpn/logicals | jq '[.LogicalServers[]|select(.Name|contains(\"$1\"))|select(.Tier==2)|{ServerName: .Name, ServerLoad: (.Load|tonumber),EntryIP: .Servers[].EntryIP}] | sort_by(.ServerLoad)' | jq -r '.[0:7]'"

	# https://github.com/dweinstein/google-translate-cli
	alias trl="trans"
	alias переведи="trans"

	# yd-dlp
    alias ytdl-audio="yt-dlp -f 'ba' -x"
    alias ytdl-video="yt-dlp --embed-subs --sub-langs all --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mp4 -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).197B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
    alias ytdl-video-meta="yt-dlp --write-info-json --write-comments --add-metadata --parse-metadata '%(title)s:%(meta_title)s' --parse-metadata '%(uploader)s:%(meta_artist)s' --write-description --write-thumbnail --embed-thumbnail --write-annotations --write-playlist-metafiles --write-all-thumbnails --write-url-link --embed-subs --sub-langs all --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mp4 -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).197B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
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

	# mpv
	alias mpvcli="mpv --no-config --vo=tct --really-quiet --profile=sw-fast --vo-tct-algo=half-blocks"

	# btop
	alias bntop="btop --config ~/configs/btop/bntop.conf -p 1"

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
	export ZELLIJ_CONFIG_FILE="$HOME/configs/zellij/zellij.kdl"

### you-should-use
	export YSU_MESSAGE_FORMAT="$(tput setaf 1)Hey! I found %alias_type for \"%command\": \"%alias\"$(tput sgr0)"
	export YSU_MESSAGE_POSITION="after"
	export YSU_IGNORED_ALIASES=("g" "bi" "cd.." "sc")

### oh-my-zsh

	# Path to your oh-my-zsh installation.
	export ZSH="$HOME/.oh-my-zsh"
	export ZSH_CUSTOM="$HOME/configs/zsh/ZSH_CUSTOM"

	# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
	# ZSH_THEME="agnoster"
	ZSH_THEME="powerlevel10k/powerlevel10k"

	ZLE_RPROMPT_INDENT=0

	HYPHEN_INSENSITIVE="true"

	HIST_STAMPS="%Y.%m.%d %T"

	ET_NO_TELEMETRY="fuck telemetry"

	export UPDATE_ZSH_DAYS=90

	ENABLE_CORRECTION="false" # correction conflicts with colored-man-pages_mod

	COMPLETION_WAITING_DOTS="true"

	ZSH_COLORIZE_TOOL=chroma
	ZSH_COLORIZE_STYLE="colorful"
	ZSH_COLORIZE_CHROMA_FORMATTER=terminal256

	# Which plugins would you like to load?
	# Standard plugins can be found in $ZSH/plugins/
	# Custom plugins may be added to $ZSH_CUSTOM/plugins/
	# Add wisely, as too many plugins slow down shell startup.
	# debug
	plugins=(git python autojump colorize zsh-syntax-highlighting zsh-autosuggestions docker docker-compose command-not-found autoupdate colored-man-pages_mod omz-homebrew last-working-dir uvenv you-should-use)

	if [[ "$OSTYPE" == "darwin"* ]]; then
		plugins+=("macos")
	fi

	#fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
	#autoload -U compinit && compinit
	source $ZSH/oh-my-zsh.sh

### external aliases
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

### Alpine bs
	# 1) Fix up $USER if empty
	if [ -z "$USER" ]; then
	  if command -v id >/dev/null 2>&1; then
	    USER=$(id -un)
	  elif command -v whoami >/dev/null 2>&1; then
	    USER=$(whoami)
	  else
	    USER="unknown"
	  fi
	  export USER
	fi

	# 2) Fix up $SHELL if empty
	if [ -z "$SHELL" ]; then
	  # Make sure we have a username to look up
	  : "${USER:=$(id -un 2>/dev/null || echo "")}"

	  # Try getent (Linux)
	  if command -v getent >/dev/null 2>&1; then
	    SHELL=$(getent passwd "$USER" | cut -d: -f7)
	  else
	    # Fallback: parse /etc/passwd
	    SHELL=$(awk -F: -v u="$USER" '$1==u{print $NF}' /etc/passwd 2>/dev/null)
	  fi

	  # Final fallback
	  SHELL=${SHELL:-/bin/sh}
	  export SHELL
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

export THEOS=~/theos
