function shh
    if test (count $argv) -lt 2
        echo "Usage: shh <secret_to_replace> <replacement_text>"
        return 1
    end

    set secret $argv[1]
    set replacement $argv[2]

    # Escape @ in both arguments for sed delimiter safety
    set escaped_secret (string replace -a '@' '\@' -- "$secret")
    set escaped_replacement (string replace -a '@' '\@' -- "$replacement")

    read --function --null stdin_content
    echo $stdin_content

    printf "$stdin_content" | sed "s@$escaped_secret@$escaped_replacement@g"
end
