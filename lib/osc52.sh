# shellcheck shell=bash
# work is owned by the CLI; osc_error is returned to it.
# shellcheck disable=SC2154,SC2034
osc_ready() {
    osc_error='OSC 52 unavailable: TERM is missing, dumb, or a Linux console'
    case ${TERM:-} in ''|dumb|linux) return 1;; esac
    osc_error='OSC 52 requires base64'
    command -v base64 >/dev/null 2>&1 || return 1
    osc_error='OSC 52 requires a writable controlling terminal (/dev/tty)'
    # Redirect stderr first so shell open errors cannot leak to the caller.
    { exec 3>/dev/tty; } 2>/dev/null || return 1
    return 0
}
osc_copy() {
    base64 < "$1" > "$work/base64" 2>/dev/null || return 1
    LC_ALL=C tr -d '\r\n' < "$work/base64" > "$work/encoded" || return 1
    # screen has small, version-dependent DCS limits. Fail conservatively.
    if [[ -n ${STY:-} ]]; then
        [[ -z ${TMUX:-} ]] || { printf 'toclip: nested screen/tmux is unsupported\n' >&2; return 1; }
        [[ $(wc -c < "$work/encoded") -le 700 ]] || {
            printf 'toclip: screen payload exceeds conservative 700-byte Base64 limit\n' >&2; return 1;
        }
    fi
    {
        if [[ -n ${TMUX:-} ]]; then printf '\033Ptmux;\033' || return 1;
        elif [[ -n ${STY:-} ]]; then printf '\033P' || return 1; fi
        printf '\033]52;c;' || return 1
        cat "$work/encoded" || return 1
        printf '\007' || return 1
        if [[ -n ${TMUX:-}${STY:-} ]]; then printf '\033\134' || return 1; fi
    } >&3
}
