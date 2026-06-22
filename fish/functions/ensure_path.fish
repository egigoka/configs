function ensure_path
  set -l path $argv[1]
  set -l new_path

  for entry in $PATH
    if test "$entry" != "$path"
      set -a new_path $entry
    end
  end

  set -gx PATH $path $new_path
end
