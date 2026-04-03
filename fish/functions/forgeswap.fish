function forgeswap --description "Swap between Forge accounts (~/forge1 and ~/forge2)"
    set -l forge_link "$HOME/forge"
    set -l forge1 "$HOME/forge1"
    set -l forge2 "$HOME/forge2"

    # Verify symlink exists (setup.sh handles initial migration)
    if not test -L "$forge_link"
        echo "Error: ~/forge is not a symlink. Run setup.sh first."
        return 1
    end

    set -l current (readlink "$forge_link")

    if test "$current" = "$forge1"
        rm "$forge_link"
        ln -s "$forge2" "$forge_link"
        echo "Switched to account 2 (~/forge -> ~/forge2)"
    else if test "$current" = "$forge2"
        rm "$forge_link"
        ln -s "$forge1" "$forge_link"
        echo "Switched to account 1 (~/forge -> ~/forge1)"
    else
        echo "Error: ~/forge points to unexpected target: $current"
        echo "Expected ~/forge1 or ~/forge2"
        return 1
    end
end
