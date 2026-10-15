#!/usr/bin/env bats
load helper
encode() {
    export work="$BATS_TEST_TMPDIR" MODE="$1"
    printf 'a\n\n' > "$work/input"
    bash -c 'source "$ROOT/lib/osc52.sh"; exec 3>"$work/sequence"; osc_copy "$work/input"'
}
@test 'OSC 52 exact bytes including trailing newlines' {
    encode plain
    printf '\033]52;c;YQoK\007' > "$BATS_TEST_TMPDIR/expected"
    cmp "$BATS_TEST_TMPDIR/sequence" "$BATS_TEST_TMPDIR/expected"
}
@test 'tmux DCS doubles inner escape' {
    export TMUX=session
    encode tmux
    printf '\033Ptmux;\033\033]52;c;YQoK\007\033\\' > "$BATS_TEST_TMPDIR/expected"
    cmp "$BATS_TEST_TMPDIR/sequence" "$BATS_TEST_TMPDIR/expected"
}
@test 'screen DCS wrapper' {
    export STY=session
    encode screen
    printf '\033P\033]52;c;YQoK\007\033\\' > "$BATS_TEST_TMPDIR/expected"
    cmp "$BATS_TEST_TMPDIR/sequence" "$BATS_TEST_TMPDIR/expected"
}
@test 'screen refuses oversized payload without partial sequence' {
    export STY=session work="$BATS_TEST_TMPDIR"
    head -c 600 /dev/zero > "$work/input"
    run bash -c 'source "$ROOT/lib/osc52.sh"; exec 3>"$work/sequence"; osc_copy "$work/input"'
    [ "$status" -ne 0 ]
    [ ! -s "$work/sequence" ]
}
@test 'nested multiplexers rejected' {
    export STY=session TMUX=session
    run encode nested
    [ "$status" -ne 0 ]
}
@test 'dumb terminal rejected' {
    export TERM=dumb
    run "$CLI" --backend osc52 test
    [ "$status" -eq 3 ]
}
@test 'no controlling terminal fails clearly' {
    command -v setsid >/dev/null || skip 'setsid is Linux-specific'
    run setsid "$CLI" --backend osc52 test
    [ "$status" -eq 3 ]
    [[ $output == *'controlling terminal'* ]]
}
@test 'controlling pseudo-terminal receives OSC while stdout stays empty' {
    [[ $(uname -s) == Linux ]] || skip 'util-linux script interface'
    command -v script >/dev/null || skip 'requires util-linux script'
    # The pty has no emulator: tests delivery, not a real clipboard update.
    export OUT="$BATS_TEST_TMPDIR/stdout"
    run script -q -e -c '"$CLI" --quiet --backend osc52 hello > "$OUT"' "$BATS_TEST_TMPDIR/typescript"
    [ "$status" -eq 0 ]
    [ ! -s "$OUT" ]
    expected=$(printf '\033]52;c;aGVsbG8=\007')
    [[ $(cat "$BATS_TEST_TMPDIR/typescript") == *"$expected"* ]]
}
@test 'failed native backend falls back to OSC on controlling pty' {
    [[ $(uname -s) == Linux ]] || skip 'util-linux script interface'
    command -v script >/dev/null || skip 'requires util-linux script'
    linux_wayland
    mock wl-copy 'exit 1'
    run script -q -e -c '"$CLI" --quiet hello' "$BATS_TEST_TMPDIR/typescript"
    [ "$status" -eq 0 ]
    expected=$(printf '\033]52;c;aGVsbG8=\007')
    [[ $(cat "$BATS_TEST_TMPDIR/typescript") == *"$expected"* ]]
}
@test 'OSC status is silent by default and opt-in with verbose' {
    [[ $(uname -s) == Linux ]] || skip 'util-linux script interface'
    command -v script >/dev/null || skip 'requires util-linux script'
    export ERR="$BATS_TEST_TMPDIR/stderr"
    run script -q -e -c '"$CLI" --backend osc52 hello 2> "$ERR"' /dev/null
    [ "$status" -eq 0 ]
    [ ! -s "$ERR" ]
    run script -q -e -c '"$CLI" --verbose --backend osc52 hello 2> "$ERR"' /dev/null
    [ "$status" -eq 0 ]
    [[ $(cat "$ERR") == *'clipboard update is unconfirmed'* ]]
    run script -q -e -c '"$CLI" --verbose --quiet --backend osc52 hello 2> "$ERR"' /dev/null
    [ "$status" -eq 0 ]
    [ ! -s "$ERR" ]
}
