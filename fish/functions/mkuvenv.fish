function mkuvenv --argument-names cmd --description "Create a uv managed virtualenv"
    if test ! "$_UVENV_LOADED" = true
        echo "[plugin: virtualfish-uvenv] plugin was not loaded" >&2 && return 1 
    end
    if not command -q uv
        echo "[plugin: virtualfish-uvenv] command uv not found, not installed or not in path" >&2 && return 1 
    end
    if test -z "$VIRTUALFISH_HOME"
        echo "[plugin: virtualfish-uvenv] variable VIRTUALFISH_HOME is not set" >&2 && return 1 
    end
    set -l options "" "-h" "--help"
    if contains -- $cmd $options
        echo "Usage: mkuvenv <name> [uv init options]" && return 0
    end
    if string match -q -- '-*' $cmd
        echo "Usage: mkuvenv <name> [uv init options]"
        echo "[plugin: virtualfish-uvenv] ERR: Using addition uv init options *after* <name>" >&2
        return 1
    end
    set -l rest $argv[2..-1]
    set -l dir "$VIRTUALFISH_HOME/$cmd"
    if test -e "$dir"
        echo "[plugin: virtualfish-uvenv] venv $cmd already exists at $dir" >&2 && return 1
    end

    if test -n "$VIRTUAL_ENV"
        vf deactivate
    end

    # create the folder, project and environment
    echo "[plugin: uvenv] cmd: mkdir -p \"$dir\""
    mkdir -p "$dir"
    echo "[plugin: virtualfish-uvenv] cmd: uv init --no-readme --no-package --no-workspace --no-description --vcs none --directory \"$dir\" $rest"
    uv init --no-readme --no-package --no-workspace --no-description --vcs none --directory "$dir" $rest
    rm -f "$dir/main.py" "$dir/.gitignore"
    echo "[plugin: virtualfish-uvenv] cmd: uv venv . --allow-existing --directory \"$dir\""
    uv venv . --allow-existing --directory "$dir"

    if test "$UVENV_INVALID_PIP_SHIM" = true
        if test ! -e "$dir/bin/pip"
            echo "[plugin: virtualfish-uvenv] creating invalid pip shim"
            echo -e "#!/usr/bin/env sh\necho \"Use 'uv pip' instead\"\nexit 1\n" > "$dir/bin/pip"
            chmod +x "$dir/bin/pip"
        end
        if test ! -e "$dir/bin/pip3"
            ln -s "$dir/bin/pip" "$dir/bin/pip3"
        end
    end

    vf activate "$cmd"
end