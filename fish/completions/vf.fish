function __vfcompletion_needs_command
    set -l cmd (commandline -opc)
    test (count $cmd) -eq 1; and test "$cmd[1]" = vf
end

function __vfcompletion_using_command
    set -l cmd (commandline -opc)
    test (count $cmd) -gt 1; and test "$argv[1]" = "$cmd[2]"
end

for subcommand in (functions -a | string match '__vf_*' | string replace '__vf_' '')
    set -l definition (functions "__vf_$subcommand")
    set -l helptext (string match -r "^function.*'(.*)'.*" -- $definition | string replace -r "^function.*'(.*)'.*" '$1' | head -n 1)
    complete -x -c vf -n '__vfcompletion_needs_command' -a $subcommand -d "$helptext"
end

complete -x -c vf -n '__vfcompletion_using_command activate' -a "(vf ls)"
complete -x -c vf -n '__vfcompletion_using_command connect' -a "(vf ls)"
complete -x -c vf -n '__vfcompletion_using_command rm' -a "(vf ls)"
complete -x -c vf -n '__vfcompletion_using_command upgrade' -a "(vf ls)"
