typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet  # to fix error because of output in chpwd
# partially fixed, error does'n appear only on first zsh process

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

if [[ "$OSTYPE" == "darwin21.0"* ]]; then
  # Fig pre block. Keep at the top of this file.
  export PATH="${PATH}:${HOME}/.local/bin"
  eval "$(fig init zsh pre)"
fi


# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export ZSH_CUSTOM="$HOME/configs/ZSH_CUSTOM"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="agnoster"
ZSH_THEME="powerlevel10k/powerlevel10k"

ZLE_RPROMPT_INDENT=0

HYPHEN_INSENSITIVE="true"

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
plugins=(thefuck git python compleat autojump colorize zsh-syntax-highlighting zsh-autosuggestions docker docker-compose command-not-found macos autoupdate colored-man-pages_mod omz-homebrew last-working-dir uvenv)

source $ZSH/oh-my-zsh.sh

# fix fucking ls utf8 decoding
export LC_COLLATE=C
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
export LANGUAGE=en_US.UTF-8
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

if [[ "$OSTYPE" == "darwin21.0"* ]]; then
	#For compilers to find openssl@3 you may need to set:
	export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib"
	export CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include"

	#For pkg-config to find openssl@3 you may need to set:
	export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig"
fi

# docker
alias d="docker"
alias dps="docker ps --format \"table {{.ID}}	{{.Status}}	{{.Names}}	{{.Image}}	{{.Ports}}\""
alias dip="docker inspect -f '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}'"
alias dnwls="docker network ls"
alias d-="docker stop"
alias d+="docker start"
alias drm="d rm"

# micro
alias m="micro"

# python
alias py="python3"
alias pip="pip3"

# youtube-dl
alias ydl="youtube-dl"

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
		alias sudo="doas"
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
		alias ipconfig="ip a"
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

# youtube-dl
alias ytd="youtube-dl"

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

# git
alias gs="git status"

# protonvpn
alias protonvpnfastest="curl -s https://api.protonmail.ch/vpn/logicals | jq '[.LogicalServers[]|select(.Name|contains(\"$1\"))|select(.Tier==2)|{ServerName: .Name, ServerLoad: (.Load|tonumber),EntryIP: .Servers[].EntryIP}] | sort_by(.ServerLoad)' | jq -r '.[0:7]'"

# https://github.com/dweinstein/google-translate-cli
alias trl="trans"
alias переведи="trans"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


if [[ "$OSTYPE" == "darwin21.0"* ]]; then
  # Fig post block. Keep at the bottom of this file.
  eval "$(fig init zsh post)"
  
fi
