# shellcheck shell=bash
is_ssh() { [[ -n ${SSH_TTY:-}${SSH_CONNECTION:-}${SSH_CLIENT:-} ]]; }
is_wsl() {
    [[ -n ${WSL_DISTRO_NAME:-}${WSL_INTEROP:-} ]] ||
        { [[ -r /proc/sys/kernel/osrelease ]] && LC_ALL=C grep -qi microsoft /proc/sys/kernel/osrelease; }
}
native_candidates() {
    candidates=()
    case $(uname -s) in
        Darwin) command -v pbcopy >/dev/null 2>&1 && candidates+=(pbcopy);;
        Linux)
            if is_wsl && command -v clip.exe >/dev/null 2>&1 && command -v iconv >/dev/null 2>&1; then candidates+=(clip.exe); fi
            if [[ -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]] && command -v wl-copy >/dev/null 2>&1; then candidates+=(wl-copy); fi
            if [[ -n ${DISPLAY:-} ]]; then
                command -v xclip >/dev/null 2>&1 && candidates+=(xclip)
                command -v xsel >/dev/null 2>&1 && candidates+=(xsel)
            fi;;
    esac
    return 0
}
