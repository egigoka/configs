function z
    if test (count $argv) -eq 0
        echo "Error: session should have name."
        return 1
    end

    set session_name $argv

    zellij --session $session_name; or zellij_attach $session_name

    set exited_sessions (zellij list-sessions --no-formatting 2>/dev/null| \
        string match -r "^$session_name\s+EXITED")

    if test (count $exited_sessions) -eq 1
        zellij delete-session $session_name
    end
end
