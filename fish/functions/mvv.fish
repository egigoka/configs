function mvv
    if test (count $argv) -lt 2
        echo "Usage: mvv <source>... <destination>" >&2
        return 1
    end

    # Extract destination (last arg) and sources (all but last)
    set dest $argv[-1]
    set sources $argv[1..-2]

    set rsync_opts -a --remove-source-files --info=progress2

    set need_trailing_slash false
    if test (count $sources) -eq 1
        if not test -e $dest
            if test -d $sources[1]
                set need_trailing_slash true
            end
        end
    end

    set rsync_srcs
    for src in $sources
        if test $need_trailing_slash = true
            set rsync_srcs $rsync_srcs "$src/"
        else
            set rsync_srcs $rsync_srcs "$src"
        end
    end

    rsync $rsync_opts $rsync_srcs $dest
    or return $status

    for src in $sources
        if test -d $src
            find $src -depth -type d -empty -exec rmdir {} \;
        end
    end
end
