function __last_command
    echo -n (history --max=1 | string trim)
end
