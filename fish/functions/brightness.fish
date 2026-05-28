function brightness --description "Get or set laptop display brightness (Linux/macOS)"
    set -l val $argv[1]

    if test -n "$val"; and not string match -qr '^[+-]?[0-9]+$' -- $val
        echo "Usage: brightness [PERCENT|+PERCENT|-PERCENT]" >&2
        echo "  brightness        show current brightness" >&2
        echo "  brightness 50     set brightness to 50%" >&2
        echo "  brightness +10    increase brightness by 10%" >&2
        echo "  brightness -10    decrease brightness by 10%" >&2
        return 1
    end

    set -l n (string trim --chars=+- -- $val)
    set -l sign (string sub --length 1 -- $val)

    switch (uname -s)
        case Linux
            if command -q brightnessctl
                if test -n "$val"
                    switch $sign
                        case +
                            brightnessctl --quiet set "$n%+"
                        case -
                            brightnessctl --quiet set "$n%-"
                        case '*'
                            brightnessctl --quiet set "$n%"
                    end
                    or return $status
                end
                echo (brightnessctl --machine-readable | string split ,)[4]
            else if command -q light
                if test -n "$val"
                    switch $sign
                        case +
                            light -A $n
                        case -
                            light -U $n
                        case '*'
                            light -S $n
                    end
                    or return $status
                end
                printf '%.0f%%\n' (light -G)
            else
                echo "brightness: install 'brightnessctl' or 'light'" >&2
                return 1
            end

        case Darwin
            if not command -q brightness
                echo "brightness: install the 'brightness' CLI (brew install brightness)" >&2
                return 1
            end
            set -l cur (command brightness -l | string match -rg 'brightness ([0-9.]+)' | tail -1)
            if test -z "$val"
                printf '%.0f%%\n' (math "$cur * 100")
                return
            end
            set -l target
            switch $sign
                case +
                    set target (math "$cur + $n / 100")
                case -
                    set target (math "$cur - $n / 100")
                case '*'
                    set target (math "$n / 100")
            end
            set target (math "min(max($target, 0), 1)")
            command brightness $target
            or return $status
            printf '%.0f%%\n' (math "$target * 100")

        case '*'
            echo "brightness: unsupported OS: "(uname -s) >&2
            return 1
    end
end
