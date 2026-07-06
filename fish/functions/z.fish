function z
    if test (count $argv) -eq 0
        echo "Error: session should have name."
        return 1
    end

    set session_name $argv
    set escaped_session_name (string escape --style=regex -- $session_name)

    if zellij list-sessions --no-formatting 2>/dev/null | string match -qr "^$escaped_session_name\s"
        zellij attach $session_name
    else
        zellij --session $session_name
    end

    set exited_sessions (zellij list-sessions --no-formatting 2>/dev/null| \
        string match -r "^$escaped_session_name\s+EXITED")

    if test (count $exited_sessions) -eq 1
        zellij delete-session $session_name
    end
end
