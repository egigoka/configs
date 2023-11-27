# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet  # to fix error because of output in chpwd
# partially fixed, error does'n appear only on first zsh process

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ "$OSTYPE" == "darwin21.0"* ]] \
	|| [[ "$OSTYPE" == "darwin22.0"* ]]; then
  # Fig pre block. Keep at the top of this file.
  # export PATH="$HOMEBREW_PREFIX/opt/python@3.10/libexec/bin:$PATH"
  export TDLIB_PATH="/opt/homebrew/opt/tdlib"
  export PATH="${PATH}:${HOME}/.local/bin:~/.fig/bin"
  eval "$(fig init zsh pre)"
  "$HOME/.fig/shell/zshrc.pre.zsh"
fi

if [[ "$OSTYPE" == "linux-android"* ]]; then
  export PATH=/data/data/com.termux/files/usr/bin:$PATH:/system/bin:/system/xbin:/system/sbin:/data/adb/modules/ssh/usr/bin
  export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib:$LD_LIBRARY_PATH
  #/data/data/com.termux/files/usr/bin/zsh
  export SHELL=/data/data/com.termux/files/usr/bin/zsh
  
  # termux
  export ANDROID_ART_ROOT="/apex/com.android.art"
  export ANDROID_DATA="/data"
  export ANDROID_I18N_ROOT="/apex/com.android.i18n"
  export ANDROID_ROOT="/system"
  export ANDROID_TZDATA_ROOT="/apex/com.android.tzdata"
  export BOOTCLASSPATH="/apex/com.android.art/javalib/core-oj.jar:/apex/com.android.art/javalib/core-libart.jar:/apex/com.android.art/javalib/okhttp.jar:/apex/com.android.art/javalib/bouncycastle.jar:/apex/com.android.art/javalib/apache-xml.jar:/system/framework/framework.jar:/system/framework/framework-graphics.jar:/system/framework/ext.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/ims-common.jar:/apex/com.android.i18n/javalib/core-icu4j.jar:/apex/com.android.appsearch/javalib/framework-appsearch.jar:/apex/com.android.conscrypt/javalib/conscrypt.jar:/apex/com.android.ipsec/javalib/android.net.ipsec.ike.jar:/apex/com.android.media/javalib/updatable-media.jar:/apex/com.android.mediaprovider/javalib/framework-mediaprovider.jar:/apex/com.android.os.statsd/javalib/framework-statsd.jar:/apex/com.android.permission/javalib/framework-permission.jar:/apex/com.android.permission/javalib/framework-permission-s.jar:/apex/com.android.scheduling/javalib/framework-scheduling.jar:/apex/com.android.sdkext/javalib/framework-sdkextensions.jar:/apex/com.android.tethering/javalib/framework-connectivity.jar:/apex/com.android.tethering/javalib/framework-tethering.jar:/apex/com.android.wifi/javalib/framework-wifi.jar"
  export COLORTERM="truecolor"
  export DEX2OATBOOTCLASSPATH="/apex/com.android.art/javalib/core-oj.jar:/apex/com.android.art/javalib/core-libart.jar:/apex/com.android.art/javalib/okhttp.jar:/apex/com.android.art/javalib/bouncycastle.jar:/apex/com.android.art/javalib/apache-xml.jar:/system/framework/framework.jar:/system/framework/framework-graphics.jar:/system/framework/ext.jar:/system/framework/telephony-common.jar:/system/framework/voip-common.jar:/system/framework/ims-common.jar:/apex/com.android.i18n/javalib/core-icu4j.jar"
  export EXTERNAL_STORAGE="/sdcard"
  export HISTCONTROL="ignoreboth"
  export LANG="en_US.UTF-8"
  export LD_PRELOAD="/data/data/com.termux/files/usr/lib/libtermux-exec.so"
  export OLDPWD="/data/data/com.termux/files"
  export PREFIX="/data/data/com.termux/files/usr"
  export PWD="/data/data/com.termux/files/usr"
  export SHELL="/data/data/com.termux/files/usr/bin/bash"
  export SHLVL="1"
  export TERM="xterm-256color"
  export TERMUX_API_VERSION="0.50.1"
  export TERMUX_APK_RELEASE="F_DROID"
  export TERMUX_APP_PID="11781"
  export TERMUX_IS_DEBUGGABLE_BUILD="0"
  export TERMUX_MAIN_PACKAGE_FORMAT="debian"
  export TERMUX_VERSION="0.118.0"
  export TMPDIR="/data/data/com.termux/files/usr/tmp"

  function pkg-as-shell {
    /data/data/com.termux/files/usr/bin/sudo -u u0_a170 env "PATH=$PATH" pkg $*
  }
fi


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
if [[ "$OSTYPE" == "linux-android"* ]]; then
  plugins=(git python compleat autojump colorize zsh-syntax-highlighting zsh-autosuggestions docker docker-compose command-not-found macos autoupdate colored-man-pages_mod omz-homebrew last-working-dir uvenv)
else
  plugins=(thefuck git python compleat autojump colorize zsh-syntax-highlighting zsh-autosuggestions docker docker-compose command-not-found macos autoupdate colored-man-pages_mod omz-homebrew last-working-dir uvenv)
fi
  
source $ZSH/oh-my-zsh.sh

if [[ "$OSTYPE" == "linux-android"* ]]; then
else
  eval $(thefuck --alias)
fi

# fix fucking ls utf8 decoding
export LC_COLLATE=C
export LANGUAGE=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='micro'
else
  export EDITOR='micro'
fi

autoload -U add-zsh-hook
add-zsh-hook -Uz chpwd ()
	{
	# this hooks into chpwd (function to change working directory)
	la;
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

# rust
export RUST_BACKTRACE=full

# add some folders to PATH
contains $PATH . || export PATH=$PATH:.
contains $PATH /home/egigoka/.local/bin || export PATH=$PATH:/home/egigoka/.local/bin
contains $PATH /etc/pycharm-2020.2.1/bin/ || export PATH=$PATH:/etc/pycharm-2020.2.1/bin/
contains $PATH /home/egigoka/go/bin/ || export PATH=$PATH:/home/egigoka/go/bin/
contains $PATH /home/egigoka/.cargo/bin || export PATH=$PATH:/home/egigoka/.cargo/bin  # rust
contains $PATH /home/egorov/.local/bin || export PATH=$PATH:/home/egorov/.local/bin
contains $PATH /var/mobile/.local/bin || export PATH=$PATH:/var/mobile/.local/bin

if [[ "$OSTYPE" == "darwin21.0"* ]]; then
	#For compilers to find openssl@3 you may need to set:
	export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib"
	export CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include"

	#For pkg-config to find openssl@3 you may need to set:
	export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig"
fi

if [[ "$OSTYPE" == "darwin" ]]; then                                                         
  alias yt-dlp="yt-dlp --ffmpeg-location /usr/bin/ffmpeg";
fi

# docker
alias d="docker"
alias dps="docker ps --format \"table {{.ID}}	{{.Status}}	{{.Names}}	{{.Image}}	{{.Ports}}\""
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

# youtube-dl
alias ydl="youtube-dl"

# cd
alias cd..="cd .."

# downloaders
alias down="axel -a -n"

# fig
alias figdoctor="cp ~/configs/.zshrc ~/configs/.zshrc_bak; fig doctor; mv ~/configs/.zshrc_bak ~/configs/.zshr"

if [[ "$OSTYPE" == "darwin21.0"* ]]; then
	# networksetup
	alias listnetworkinterfaces="networksetup -listnetworkserviceorder"
	alias setroutes="sudo networksetup -setadditionalroutes " # name from listnetworinterfaces, ip, mask, router; multiple routes should be set through use of space between 
	
	# gatekeeper
	alias gatekeeper-disable="sudo spctl --master-disable"
	alias gatekeeper-enable="sudo spctl --master-enable"
fi

# sudo and doas
if ! [[ "$OSTYPE" == "darwin20.0"* ]]; then
	if ! [[ "$OSTYPE" == "darwin21.0"* ]]; then
		if ! [[ "$OSTYPE" == "darwin22.0"* ]]; then
			if ! [[ "$OSTYPE" == "linux-android" ]]; then
				alias sudo="doas"
			fi
		fi
	fi
fi

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
fi

# easy packet management
alias install="zypper -n install"
alias uninstall="zypper -n remove"
# alias updateall="zypper ref; zypper list-updates --all; zypper update"
alias updateall="zypper refresh;zypper dup";

# outdated commands
if ! [[ "$OSTYPE" == "darwin20.0"* ]]; then
	if ! [[ "$OSTYPE" == "darwin21.0"* ]]; then
		if ! [[ "$OSTYPE" == "darwin22.0"* ]]; then
			alias ipconfig="ip a"
		fi
	fi
fi
alias ifconfig="ipconfig"
		

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
alias scs="sc status"

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

#yd-dlp
alias ytdl-audio="yt-dlp -f 'ba' -x --audio-format mp3"
alias ytdl-video="yt-dlp --embed-subs --sub-langs all --convert-subs srt --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mkv -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).205B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
alias ytdl-video-meta="yt-dlp --write-info-json --write-comments --add-metadata --parse-metadata '%(title)s:%(meta_title)s' --parse-metadata '%(uploader)s:%(meta_artist)s' --write-description --write-thumbnail --embed-thumbnail --write-annotations --write-playlist-metafiles --write-all-thumbnails --write-url-link --embed-subs --sub-langs all --convert-subs srt --ppa 'EmbedSubtitle:-disposition:s:0 0' -f 'bv[ext=mp4] +ba[ext=m4a]/best[ext=mp4]/best' --prefer-ffmpeg --merge-output-format mkv -o 'Videos/%(upload_date>%Y-%m-%d)s - %(title).205B [%(id)s].%(ext)s' --retries 100000 --fragment-retries 100000 --file-access-retries 100000 --extractor-retries 100000 --limit-rate 40M --retry-sleep fragment:exp=1:8 --sponsorblock-mark default --download-archive 'archive.ytdlp'"
alias twitch-download="yt-dlp --downloader aria2c --downloader-args aria2c:'-c -j 32 -s 32 -x 16 --file-allocation=none --optimize-concurrent-downloads=true --http-accept-gzip=true"
alias ytdl-list="yt-dlp --flat-playlist --print id"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


if [[ "$OSTYPE" == "darwin21.0"* ]] \
	|| [[ "$OSTYPE" == "darwin22.0"* ]]; then
  # Fig post block. Keep at the bottom of this file.
  . "$HOME/.fig/shell/zshrc.post.zsh"
  eval "$(fig init zsh post)"
fi

export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

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

export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

alias infusedocs="~/Containers/Data/Application/9D783797-4F41-4C0C-9628-35FA8C8E949C/Documents"
alias downloaderdocs="/private/var/mobile/Containers/Data/Application/A24D92C9-7F80-4129-8D06-880E107FA9D9/Documents"

if [[ "$OSTYPE" == "linux-android"* ]]; then
else
  eval $(thefuck --alias)
fi

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/zshrc.post.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.post.zsh"
