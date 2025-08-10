function change_extension
    if test (count $argv) -lt 2
        echo "Usage: change_extension <filename> <new_extension>"
        return 1
    end

    set filename $argv[1]
    set new_extension $argv[2]

    # Get directory and filename without extension
    set dir (dirname -- "$filename")
    set file (basename -- "$filename")

    # Remove the last extension (after final dot)
    set name_only (string replace -r '\.[^.]*$' '' "$file")

    # Combine everything into the new path
    set new_filename "$dir/$name_only.$new_extension"

    mv -- "$filename" "$new_filename"
end
