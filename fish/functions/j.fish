function j
    set new_path (autojump $argv)
 
    if test -d "$new_path"
        echo $new_path
        cd "$new_path"
    else
        echo "autojump: directory '$argv' not found"
        echo "Try \`autojump --help\` for more information."
        false
    end
end
