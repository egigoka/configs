function zellij --wraps zellij
    if test (count $argv) -eq 3; and test "$argv[1]" = action; and test "$argv[2]" = rename-session; and set -q ZELLIJ_SESSION_NAME
        set -q __zellij_session_name; or set -g __zellij_session_name $ZELLIJ_SESSION_NAME

        command zellij --session $__zellij_session_name action rename-session $argv[3]
        set -l rename_status $status

        if test $rename_status -eq 0
            set -g __zellij_session_name $argv[3]
            set -gx ZELLIJ_SESSION_NAME $argv[3]
        end

        return $rename_status
    end

    command zellij $argv
end
