function tlog
    $argv | while read -l line
        echo (date "+%H:%M:%S.%3N")" $line"
    end
end
