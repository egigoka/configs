function get_monday_iso8601 --description "Get ISO 8601 timestamp for last Monday midnight"
    set os (uname)

    if test "$os" = "Darwin"
        set ts (date -v-mon -v0H -v0M '+%Y-%m-%dT%H:%M:%S')
        set tz (date +%z)  # e.g., "-0700"
        set tz_formatted (string sub -l 3 -- $tz):(string sub -s 4 -- $tz)
        echo "$ts$tz_formatted"
    else
        set dow (date +%u)             # Day of week: 1..7, Mon=1
        set offset (math $dow - 1)     # Days to subtract to get Monday
        # Format ISO 8601 with timezone
        date -d (date -d "$offset days ago" '+%Y-%m-%d') '+%Y-%m-%dT00:00:00%:z'
    end
end
