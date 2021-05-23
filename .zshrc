typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet  # to fix error because of output in chpwd
# partially fixed, error does'n appear only on first zsh process

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
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
plugins=(thefuck git python compleat autojump colorize zsh-syntax-highlighting zsh-autosuggestions docker docker-compose command-not-found osx autoupdate colored-man-pages_mod omz-homebrew last-working-dir uvenv)

source $ZSH/oh-my-zsh.sh

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

# docker
alias d="docker"
alias dps="docker ps --format \"table {{.ID}}\t{{.Status}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}\""
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

# sudo
alias unmount="sudo umount"
alias mount="sudo mount"
alias zypper="sudo zypper"
alias snap="sudo snap"
alias yast="sudo yast"
alias reboot="sudo reboot"
alias systemctl="sudo systemctl"
alias useradd="sudo useradd"
alias userdel="sudo userdel"
alias groupadd="sudo groupadd"
alias usermod="sudo usermod"
alias btrfs="sudo btrfs"
alias mkfs.btrfs="sudo mkfs.btrfs"
alias openvpn="sudo openvpn"
alias iotop="sudo iotop"

# easy packet management
alias install="sudo zypper -n install"
alias uninstall="sudo zypper -n remove"
alias updateall="zypper ref; zypper list-updates --all; zypper update"

# outdated commands
alias ipconfig="ip a"
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

# git
alias gs="git status"

# gatekeeper
alias gatekeeper-disable="sudo spctl --master-disable"
alias gatekeeper-enable="sudo spctl --master-enable"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
