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

    # Wallpaper-generated terminal colors. kitty already gets them (all 256, incl. the
    # 232-255 ones starship uses) from generated/terminal/kitty-theme.conf, and it logs a
    # [PARSE ERROR] for the urxvt-style OSC 708/13-17 codes in sequences.txt, so skip it there.
    if test "$TERM" != xterm-kitty; and test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    alias pamcan pacman
    alias q 'qs -c ii'
end
