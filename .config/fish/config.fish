set --global tide_left_prompt_items pwd git context os newline
set --global tide_context_always_display true

if status is-interactive
    # Commands to run in interactive sessions can go here
end

thefuck --alias | source

begin
    set --local AUTOJUMP_PATH $HOME/.autojump/share/autojump/autojump.fish
    if test -e $AUTOJUMP_PATH
        source $AUTOJUMP_PATH
    end
end

