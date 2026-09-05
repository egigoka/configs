function __cached_command_init --description 'Cache generated Fish integration scripts'
    if test (count $argv) -lt 3
        return 2
    end

    set -l cache_name $argv[1]
    set -l command_name $argv[2]
    set -l generator_args $argv[3..-1]
    set -l executable (command -s $command_name)
    test -n "$executable"; or return 127

    set -l cache_base $XDG_CACHE_HOME
    if test -z "$cache_base"
        set cache_base "$HOME/.cache"
    end
    set -l cache_root "$cache_base/fish/generated-init"
    set -l cache_file "$cache_root/v1-$cache_name-$version.fish"

    if not test -s "$cache_file"; or test "$executable" -nt "$cache_file"
        command mkdir -p "$cache_root"; or return
        set -l temporary (command mktemp "$cache_root/$cache_name.XXXXXX"); or return
        if command "$executable" $generator_args >"$temporary"; and fish -n "$temporary"
            command mv -f "$temporary" "$cache_file"; or return
        else
            command rm -f "$temporary"
            test -s "$cache_file"; or return 1
        end
    end

    source $cache_file
end
