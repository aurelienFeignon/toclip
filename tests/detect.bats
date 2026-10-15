#!/usr/bin/env bats
load helper
@test 'Wayland preferred over X11' {
    linux_wayland
    export DISPLAY=:0
    mock xclip 'exit 99'
    run "$CLI" --check
    [ "$status" -eq 0 ]
    [[ $output == *wl-copy* ]]
    [[ $output == *'not verified'* ]]
}
@test 'headless native unavailable despite installed tools' {
    mock uname 'echo Linux'
    mock wl-copy 'exit 0'
    run "$CLI" --backend native --check
    [ "$status" -eq 3 ]
}
@test 'SSH bypasses native even when display exists' {
    linux_wayland
    export SSH_CONNECTION='remote local' TERM=dumb
    run "$CLI" secret
    [ "$status" -eq 3 ]
    [ ! -e "$CAPTURE" ]
}
@test 'native can be forced over SSH' {
    linux_wayland
    export SSH_TTY=/dev/pts/1
    "$CLI" --backend native hello
    [ "$(cat "$CAPTURE")" = hello ]
}
@test 'missing TERM is rejected' {
    unset TERM
    run "$CLI" --backend osc52 --check
    [ "$status" -eq 3 ]
    [[ $output == *'TERM is missing'* ]]
}
