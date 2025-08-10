function gcommitstoday --description 'Show today\'s git commits'
    git log --since=midnight --until=now --pretty=format:"%h - %ar - %an: %s"
    echo
end
