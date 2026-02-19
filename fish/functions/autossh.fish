function autossh --description "SSH with auto-reconnect and 10s timeout"
    if test (count $argv) -eq 0
        echo "Usage: autossh [ssh arguments]"
        return 1
    end

    while true
        ssh -o ConnectTimeout=10 -o ConnectionAttempts=1 $argv
        set -l exit_code $status

        if test $exit_code -eq 0
            echo "SSH session ended."
            break
        end

        echo "Connection failed (exit $exit_code). Retrying in 1s..."
        sleep 1
    end
end
