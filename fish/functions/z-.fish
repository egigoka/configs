function z-
    if test (count $argv) -eq 0
        set sessions (zellij list-sessions --reverse --no-formatting | grep -v "(EXITED" | awk '{printf "\033[1;36m%-20s\033[0m %s\n", $1, $3}')
        
        if set -q FZF_TMUX_HEIGHT
            set height $FZF_TMUX_HEIGHT
        else
            set height "20%"
        end

        set selected_session (echo "$sessions" | fzf --height=$height --ansi | awk '{print $1}')
        
        if test -n "$selected_session"
            zellij_kill_session "$selected_session"
        else
            echo "No session selected."
        end
    else
        zellij_kill_session $argv
    end
end
