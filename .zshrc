# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="agnoster"

HYPHEN_INSENSITIVE="true"

export UPDATE_ZSH_DAYS=13

ENABLE_CORRECTION="true"

COMPLETION_WAITING_DOTS="true"

HIST_STAMPS="yyyy.mm.dd"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Add wisely, as too many plugins slow down shell startup.
plugins=(git python)

source $ZSH/oh-my-zsh.sh

export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='micro'
else
  export EDITOR='micro'
fi

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
	sudo -u "$USER" zsh -i -c "$args"
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

# add some folders to PATH
contains $PATH /snap/bin || export PATH=$PATH:/snap/bin 
contains $PATH /home/egigoka/.local/bin || export PATH=$PATH:/home/egigoka/.local/bin
contains $PATH /etc/pycharm-2020.2.1/bin/ || export PATH=$PATH:/etc/pycharm-2020.2.1/bin/

# add plex home var
export PLEX_HOME='/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/'

# Aliases
alias py="python3"
alias pip="pip3"

# sudo aliases
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

# easy packet management
alias install="sudo zypper -n install"
alias uninstall="sudo zypper -n remove"

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

# idk im stupid
alias zshconfig="micro ~/.zshrc"
