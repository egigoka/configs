function ensure_path
  if not contains $argv[1] $PATH
    set -gx PATH $PATH $argv[1]
  end
end
