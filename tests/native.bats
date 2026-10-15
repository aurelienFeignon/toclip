#!/usr/bin/env bats
load helper
@test 'macOS pbcopy' {
    mock uname 'echo Darwin'
    mock pbcopy 'cat > "$CAPTURE"'
    "$CLI" mac
    [ "$(cat "$CAPTURE")" = mac ]
}
@test 'X11 xclip flags' {
    mock uname 'echo Linux'
    export DISPLAY=:0
    mock xclip '[[ $* == "-selection clipboard -in" ]] || exit 1; cat > "$CAPTURE"'
    "$CLI" x11
    [ "$(cat "$CAPTURE")" = x11 ]
}
@test 'failed Wayland falls back to X11 xsel' {
    linux_wayland
    export DISPLAY=:0
    mock wl-copy 'exit 1'
    mock xclip 'exit 1'
    mock xsel '[[ $* == "--clipboard --input" ]] || exit 1; cat > "$CAPTURE"'
    "$CLI" fallback
    [ "$(cat "$CAPTURE")" = fallback ]
}
@test 'WSL encodes UTF-16LE for clip.exe' {
    mock uname 'echo Linux'
    export WSL_DISTRO_NAME=Ubuntu
    mock clip.exe 'cat > "$CAPTURE"'
    "$CLI" 'été'
    printf 'été' | iconv -f UTF-8 -t UTF-16LE > "$BATS_TEST_TMPDIR/expected"
    cmp "$CAPTURE" "$BATS_TEST_TMPDIR/expected"
}
@test 'check never invokes clipboard utility' {
    linux_wayland
    "$CLI" --check
    [ ! -e "$CAPTURE" ]
}
