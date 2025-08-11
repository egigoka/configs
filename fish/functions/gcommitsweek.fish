function gcommitsweek --description "Show commits since last Monday"
    set since (get_monday_iso8601)
    git log --since="$since" --until=now --pretty=format:"%h - %ar - %an: %s" $argv
    echo
end
