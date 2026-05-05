function __z_sessions
    zellij list-sessions --no-formatting 2>/dev/null | \
        string replace -r '\s+\[.*$' ''
end

complete -c z -f -a '(__z_sessions)' -d 'zellij session'
