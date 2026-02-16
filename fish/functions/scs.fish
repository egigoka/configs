function scs --description "Service status: launchctl print + logs on macOS, systemctl status on Linux"
    if test (count $argv) -eq 0
        echo "Usage: scs <service-target>"
        echo "  macOS: scs system/com.apple.ftp-proxy"
        echo "  Linux: scs nginx"
        return 1
    end

    if string match -q "Darwin*" -- (uname)
        echo "=== Service Info ==="
        launchctl print $argv
        echo ""
        echo "=== Recent Logs ==="
        set -l service_name (string split "/" -- $argv[1])[-1]
        log show --predicate "subsystem == '$service_name' OR composedMessage CONTAINS '$service_name'" --last 5m --style compact 2>/dev/null | tail -n 20
    else
        sudo systemctl status -l $argv
    end
end
