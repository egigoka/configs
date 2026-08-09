function _ssh_with_temporary_unlocked_keys --description "SSH with temporary unlocked key copies"
    set -l unlocked_dir "$HOME/.ssh/.unlocked"
    set -l identity_options

    command mkdir -p -m 700 "$unlocked_dir"

    # Resolve the identities selected by ~/.ssh/config for this invocation.
    # Existing private keys are copied and decrypted once per unlocked session.
    for identity in (command ssh -G $argv 2>/dev/null | string match -r '^identityfile .+' | string replace 'identityfile ' '')
        set identity (string replace -r '^~/' "$HOME/" -- "$identity")
        test -f "$identity"; or continue

        set -l key_name (path basename "$identity")
        set -l unlocked_key "$unlocked_dir/$key_name"

        if not test -f "$unlocked_key"
            set -l temporary_key (command mktemp "$unlocked_dir/.$key_name.XXXXXX")
            or return 1

            command cp "$identity" "$temporary_key"
            and command chmod 600 "$temporary_key"
            and command ssh-keygen -p -f "$temporary_key" -N ""
            if test $status -ne 0
                command rm -f "$temporary_key"
                return 1
            end

            command mv "$temporary_key" "$unlocked_key"
            or return 1
        end

        set -a identity_options -o "IdentityFile=$unlocked_key"
    end

    command ssh -o AddKeysToAgent=no -o UseKeychain=no $identity_options $argv
end
