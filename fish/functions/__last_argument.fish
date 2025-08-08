function __last_argument
    echo "$history[1]" | read --array --tokenize result
    echo (string escape --style=script -- $result[-1])
end
