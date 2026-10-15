# shellcheck shell=bash
# candidates and work are supplied by detect.sh and the CLI.
# shellcheck disable=SC2154
native_copy() {
    native_candidates
    for native_tool in "${candidates[@]}"; do
        # Suppress tool diagnostics: they may contain user data.
        case $native_tool in
            wl-copy) wl-copy < "$1" >/dev/null 2>&1 && return 0;;
            xclip) xclip -selection clipboard -in < "$1" >/dev/null 2>&1 && return 0;;
            xsel) xsel --clipboard --input < "$1" >/dev/null 2>&1 && return 0;;
            pbcopy) pbcopy < "$1" >/dev/null 2>&1 && return 0;;
            clip.exe)
                # Windows clip expects UTF-16LE; do not pass UTF-8 as OEM text.
                if iconv -f UTF-8 -t UTF-16LE < "$1" > "$work/windows" 2>/dev/null; then
                    clip.exe < "$work/windows" >/dev/null 2>&1 && return 0
                fi;;
        esac
    done
    return 1
}
