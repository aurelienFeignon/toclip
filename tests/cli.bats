#!/usr/bin/env bats
load helper
@test 'help and version' {
    run "$CLI" --help
    [ "$status" -eq 0 ]
    run "$CLI" --version
    [ "$output" = 'toclip 0.1.0' ]
}
@test 'arguments joined without added newline and UTF-8 preserved' {
    linux_wayland
    "$CLI" 'été $HOME' '世界'
    printf 'été $HOME 世界' > "$BATS_TEST_TMPDIR/expected"
    cmp "$CAPTURE" "$BATS_TEST_TMPDIR/expected"
}
@test 'stdin preserves multiline and trailing newlines' {
    linux_wayland
    printf 'a\nb\n\n' > "$BATS_TEST_TMPDIR/input"
    "$CLI" < "$BATS_TEST_TMPDIR/input"
    cmp "$CAPTURE" "$BATS_TEST_TMPDIR/input"
}
@test 'file and removal of exactly one LF' {
    linux_wayland
    printf 'a\n\n' > "$BATS_TEST_TMPDIR/input"
    "$CLI" --no-newline --file "$BATS_TEST_TMPDIR/input"
    printf 'a\n' > "$BATS_TEST_TMPDIR/expected"
    cmp "$CAPTURE" "$BATS_TEST_TMPDIR/expected"
}
@test 'empty input accepted including zero limit' {
    linux_wayland
    "$CLI" --max-bytes 0 < /dev/null
    [ ! -s "$CAPTURE" ]
}
@test 'size overflow fails before copying' {
    linux_wayland
    run "$CLI" --max-bytes 2 abc
    [ "$status" -eq 4 ]
    [ ! -e "$CAPTURE" ]
}
@test 'NUL rejected without logging content' {
    linux_wayland
    printf 'SECRET\000value' > "$BATS_TEST_TMPDIR/input"
    run "$CLI" --file "$BATS_TEST_TMPDIR/input"
    [ "$status" -eq 5 ]
    [[ $output != *SECRET* ]]
    [ ! -e "$CAPTURE" ]
}
@test 'large input succeeds with explicit limit' {
    linux_wayland
    head -c 100000 /dev/zero | tr '\000' x > "$BATS_TEST_TMPDIR/input"
    "$CLI" --max-bytes 100000 --file "$BATS_TEST_TMPDIR/input"
    cmp "$CAPTURE" "$BATS_TEST_TMPDIR/input"
}
@test 'invalid options and conflicting sources' {
    for option in '--backend bad' '--max-bytes -1' '--max-bytes 9999999999' '--file' '--unknown' '--file /dev/null text'; do
        # Intentional splitting of test fixtures.
        run bash -c '"$CLI" $1' _ "$option"
        [ "$status" -eq 2 ]
    done
}
@test 'content and tool errors never appear on output' {
    linux_wayland
    mock wl-copy 'cat; echo SECRET >&2; exit 1'
    run "$CLI" --backend native SECRET
    [ "$status" -eq 3 ]
    [[ $output != *SECRET* ]]
}
@test 'temporary directory removed on success and failure' {
    linux_wayland
    mkdir "$BATS_TEST_TMPDIR/private"
    export TMPDIR="$BATS_TEST_TMPDIR/private"
    "$CLI" hello
    run "$CLI" --max-bytes 1 hello
    [ "$status" -eq 4 ]
    [ -z "$(ls -A "$TMPDIR")" ]
}
@test 'quiet suppresses native verbose messages and stdout stays empty' {
    linux_wayland
    run "$CLI" --verbose --quiet secret
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
@test 'staged installation works and uninstall removes installed files' {
    run make -s -C "$ROOT" install PREFIX=/usr/local DESTDIR="$BATS_TEST_TMPDIR/stage"
    [ "$status" -eq 0 ]
    linux_wayland
    "$BATS_TEST_TMPDIR/stage/usr/local/bin/toclip" installed
    [ "$(cat "$CAPTURE")" = installed ]
    run make -s -C "$ROOT" uninstall PREFIX=/usr/local DESTDIR="$BATS_TEST_TMPDIR/stage"
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/stage/usr/local/bin/toclip" ]
}
@test 'TERM interruption cleans private resources' {
    linux_wayland
    mkdir "$BATS_TEST_TMPDIR/private"
    export TMPDIR="$BATS_TEST_TMPDIR/private"
    mock wl-copy 'kill -TERM "$PPID"; exit 0'
    run "$CLI" hello
    [ "$status" -eq 143 ]
    [ -z "$(ls -A "$TMPDIR")" ]
}
@test 'missing input file reports I/O failure without copying' {
    linux_wayland
    run "$CLI" --file "$BATS_TEST_TMPDIR/missing"
    [ "$status" -eq 1 ]
    [ ! -e "$CAPTURE" ]
}
