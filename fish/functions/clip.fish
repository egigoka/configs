function clip
    read --function --null input
    set encoded (echo -n $input | base64 | tr -d '\n')
    printf "\033]52;c;%s\a" $encoded
end
