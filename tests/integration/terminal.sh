#!/usr/bin/env bash
# Manual integration: run in the terminal being evaluated, then paste elsewhere.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
printf 'toclip integration: UTF-8 été 世界\nsecond line\n\n' |
    "$root/bin/toclip" --backend osc52
printf 'Paste into a trusted editor and compare UTF-8 and both final LFs.\n' >&2
