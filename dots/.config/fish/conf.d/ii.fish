# illogical-impulse fish bits (from dots/.config/fish/config.fish; kept out of
# config.fish so the CachyOS config stays untouched).
if status is-interactive
    # Starship prompt, only once the package is installed
    if command -q starship; and test "$TERM" != linux
        function starship_transient_prompt_func
            starship module character
        end
        starship init fish | source
        enable_transience
    end

    # Wallpaper-generated terminal colors
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    alias pamcan pacman
    alias q 'qs -c ii'
end
