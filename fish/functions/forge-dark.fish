function forge-dark --description "Open Forge in iTerm2 Dark profile"
    set -l dir (pwd)

    osascript \
        -e 'tell application "iTerm"' \
        -e 'if (count of windows) = 0 then' \
        -e 'set new_window to create window with profile "Dark"' \
        -e 'tell current session of new_window to write text "cd " & quoted form of "'"$dir"'" & " && forge"' \
        -e 'else' \
        -e 'tell current window' \
        -e 'set new_tab to create tab with profile "Dark"' \
        -e 'tell current session of new_tab to write text "cd " & quoted form of "'"$dir"'" & " && forge"' \
        -e 'end tell' \
        -e 'end if' \
        -e 'end tell'
end
