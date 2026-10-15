setup() {
    ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
    CLI=$ROOT/bin/toclip
    export ROOT CLI
    export PATH="$BATS_TEST_TMPDIR/mocks:$PATH"
    mkdir -p "$BATS_TEST_TMPDIR/mocks"
    export CAPTURE="$BATS_TEST_TMPDIR/capture"
    unset SSH_TTY SSH_CONNECTION SSH_CLIENT TMUX STY WAYLAND_DISPLAY DISPLAY WSL_DISTRO_NAME WSL_INTEROP
    export TERM=xterm-256color
}
mock() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" > "$BATS_TEST_TMPDIR/mocks/$1"
    chmod +x "$BATS_TEST_TMPDIR/mocks/$1"
}
linux_wayland() {
    mock uname 'echo Linux'
    export WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR"
    mock wl-copy 'cat > "$CAPTURE"'
}
