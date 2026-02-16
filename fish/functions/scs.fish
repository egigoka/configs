function scs --description "Service status: launchctl print + logs on macOS, systemctl status on Linux"
    if test (count $argv) -eq 0
        echo "Usage: scs <service-name>"
        echo "  macOS: scs com.egigoka.firefox-backup"
        echo "  Linux: scs nginx"
        return 1
    end

    if string match -q "Darwin*" -- (uname)
        set -l target $argv[1]

        # if no domain prefix given, try to find the service automatically
        if not string match -q "*/*" -- $target
            set -l uid (id -u)
            if launchctl print gui/$uid/$target &>/dev/null
                set target gui/$uid/$target
            else if launchctl print system/$target &>/dev/null
                set target system/$target
            else
                echo "Service '$argv[1]' not found in gui/$uid/ or system/"
                return 1
            end
        end

        echo "=== Service Info ==="
        launchctl print $target
        echo ""

        # find plist path from launchctl print output
        set -l service_name (string split "/" -- $target)[-1]
        set -l plist_path ""
        for p in ~/Library/LaunchAgents/$service_name.plist /Library/LaunchAgents/$service_name.plist /Library/LaunchDaemons/$service_name.plist
            if test -f $p
                set plist_path $p
                break
            end
        end

        echo "=== Recent Logs ==="
        set -l found_logs 0

        if test -n "$plist_path"
            # check for StandardOutPath and StandardErrorPath in plist
            set -l stdout_path (/usr/libexec/PlistBuddy -c "Print :StandardOutPath" $plist_path 2>/dev/null)
            set -l stderr_path (/usr/libexec/PlistBuddy -c "Print :StandardErrorPath" $plist_path 2>/dev/null)

            if test -n "$stdout_path" -a -f "$stdout_path"
                echo "--- stdout ($stdout_path) ---"
                tail -n 20 $stdout_path
                set found_logs 1
            end

            if test -n "$stderr_path" -a "$stderr_path" != "$stdout_path" -a -f "$stderr_path"
                echo "--- stderr ($stderr_path) ---"
                tail -n 20 $stderr_path
                set found_logs 1
            end
        end

        if test $found_logs -eq 0
            # fallback to unified log
            set -l predicate "eventMessage CONTAINS '$service_name'"
            log show --predicate $predicate --last 1d --style compact 2>/dev/null | tail -n 20
        end
    else
        sudo systemctl status -l $argv
    end
end
