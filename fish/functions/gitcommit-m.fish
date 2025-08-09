function gitcommit-m
    # Check if user passed any arguments
    if test (count $argv) -eq 0
        echo "Usage: gitcommit-m <commit message>"
        echo "Example: gitcommit-m bugfix"
        return 1
    end

    # Join all arguments into one string
    set commit_message (string join " " -- $argv)

    # Run git commit with the message
    git commit -m "$commit_message"
end
