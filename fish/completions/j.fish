function __j_autojump_complete
    set -l token (commandline -ct)
    autojump --complete $token | string replace -r '^.*__[0-9]+__' ''
end

complete -e -c j
complete -k -x -c j -a '(__j_autojump_complete)' -d 'autojump directory'
