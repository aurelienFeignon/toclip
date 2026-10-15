# toclip

Copy terminal text to a clipboard with Bash 3.2+, including from a headless SSH
server to a compatible local terminal. No daemon, runtime, network requests or
telemetry. Version 0.1.0.

```sh
echo "Hello World" | toclip
toclip "Hello World"
cat file.txt | toclip
git diff | toclip
docker logs container 2>&1 | toclip
toclip --file file.txt
```

## Installation

```sh
git clone <repository-url>
cd toclip
sudo make install
# Without root:
make install PREFIX="$HOME/.local"
# Add $HOME/.local/bin to PATH yourself if necessary.
```

Default prefix: `/usr/local`. Keep `bin` and `lib/toclip` together under the same
prefix; symlinked executables are not resolved automatically. No shell startup
files are modified. Uninstall with `make uninstall` using the same prefix (and
sudo when needed). `DESTDIR` supports package staging, for example
`make install DESTDIR=/tmp/package PREFIX=/usr`. The layout can be used by future
deb/rpm/Homebrew recipes; no packages are shipped yet.

Runtime tools: Bash, base64, head, tail, wc, tr, cmp, od, mktemp, cat, mv, rm,
uname, dirname; grep for WSL autodetection. Standard Linux/macOS userlands provide
these. Native clipboard utilities are optional. WSL `clip.exe` additionally uses
iconv for UTF-8 to UTF-16LE conversion. Bats and ShellCheck are development tools,
not runtime dependencies.

## CLI and input contract

```sh
toclip --backend auto             # default; reads stdin
toclip --backend native --file report.txt
toclip --backend osc52 --max-bytes 100000 < report.txt
toclip --no-newline < report.txt   # removes exactly one final LF
toclip --check                    # inspect prerequisites, without copying
toclip --verbose "text"
toclip --quiet --backend osc52 "text"
toclip -- --text-starting-with-dash
toclip --help
toclip --version
```

Options precede text. Multiple text arguments are joined with single spaces,
without adding a newline. With no text arguments, stdin is read; interactive
stdin requires an explicit source. A file and text arguments cannot be combined.
`--file` accepts readable regular files. UTF-8 and final newlines are preserved;
`--no-newline` removes one LF, retaining a preceding CR. No Unicode normalization
or general encoding validation is performed. WSL conversion rejects invalid UTF-8.

This is a **text utility**: NUL bytes are rejected on all backends, binary copying
is unsupported. Other bytes are carried unchanged except WSL encoding conversion;
the clipboard tool or terminal may impose additional text/encoding constraints.
Never use this tool as a lossless binary transport.

The default input limit is **75000 bytes**, including final newlines before any
removal. `--max-bytes N` accepts 0 through 999999999. An overflow fails before any
clipboard operation; it is never silently truncated. stdin/file spooling reads
at most N+1 bytes, so oversized pipelines may give their producer SIGPIPE. Text
arguments are already held by the invoking shell and are spooled before checking.
OSC 52 Base64 expands input to `4 * ceil(bytes / 3)` bytes, plus framing. Increasing
the input limit cannot increase the terminal's own limit.

Exit codes: 0 = native tool completed or OSC 52 emitted; 1 = I/O or OSC emission
failure; 2 = usage; 3 = no usable backend/native failures; 4 = size limit;
5 = NUL input. A native exit status does not promise future clipboard persistence.
Native tool errors are suppressed to avoid leaking content. `--verbose` reports
the selected native tool or the unconfirmed OSC 52 emission status. Copies are
silent by default; `--quiet` also suppresses verbose messages. Errors are never suppressed. Copy operations never print content
on stdout or stderr. Help/version print on stdout; diagnostics use stderr.

## Selection and native backends

Automatic priority:

1. SSH (`SSH_TTY`, `SSH_CONNECTION` or `SSH_CLIENT`): OSC 52, even with forwarded X11.
2. Local macOS: `pbcopy`.
3. Local Linux/WSL: `clip.exe` when WSL is detected, then `wl-copy` when both
   `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` are set, then `xclip`, then `xsel` when
   `DISPLAY` is set.
4. If native tools are missing or actually fail: OSC 52.

WSL is detected by `WSL_DISTRO_NAME`, `WSL_INTEROP`, or a Microsoft kernel marker.
Native candidates must exist and receive input successfully: environment variables
alone do not prove a display is usable. A failed tool may have partially changed
the clipboard before fallback. No timeout is imposed on native programs; interrupt
a stalled program with Ctrl-C. Native tools may themselves start clipboard owner
processes as required by X11/Wayland; toclip adds no daemon.

`--backend native` allows intentional remote/forwarded clipboard access and tries
only native candidates. `--backend osc52` bypasses native tools. `--check` does not
write to the clipboard or probe it by overwriting it: native output is explicitly
candidate-only. OSC checks TERM, base64, and writable `/dev/tty`; neither check
confirms graphical connectivity, terminal policy, nor clipboard contents.

## OSC 52, SSH and multiplexers

OSC 52 sends `ESC ] 52 ; c ; BASE64 BEL` to the controlling terminal, **not stdout**.
It needs no X11/Wayland. The terminal may decode it into the local clipboard. There
is no reliable acknowledgement of a write: success means local emission only.
No clipboard read/query is attempted. Unknown TERM values are allowed on a
best-effort basis; missing TERM, `dumb`, and the Linux console (`linux`) are rejected.
A known-looking TERM value does not prove support.

```sh
ssh host 'git diff | /usr/local/bin/toclip'   # often lacks a controlling tty
ssh -t host 'git diff | /usr/local/bin/toclip' # requests one
# Or run inside an interactive SSH session:
git diff | toclip --backend osc52
```

Remote noninteractive commands need an allocated terminal. Terminal clipboard
permission must be enabled on the **client**. Consult the specific terminal's
manual; terminal versions, policies and size limits differ.

With `TMUX`, toclip wraps the sequence in tmux DCS passthrough and doubles the
inner ESC. On tmux versions providing this option, configure intentionally:

```tmux
set -g allow-passthrough on
```

This implementation uses passthrough rather than tmux's clipboard interception.
The outer terminal still must support OSC 52. `set-clipboard on` is an alternative
architecture for applications emitting unwrapped OSC 52; toclip does not change
that setting. See the [tmux clipboard documentation](https://github.com/tmux/tmux/wiki/Clipboard)
and [XTerm control sequence specification](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html).

With `STY`, a screen DCS wrapper is used, with a conservative **700-byte Base64
payload limit** (at most 525 raw bytes). Older screen versions can have small
passthrough limits; this limit is a precaution, not a compatibility guarantee.
No chunking is used because repeated OSC 52 writes can replace rather than append
to the clipboard. Nested screen/tmux detected by both variables is rejected;
other nested multiplexer arrangements are unverified. No automatic configuration
changes are made.

## Validation and compatibility

| Environment | Automated evidence | Real clipboard validation |
| --- | --- | --- |
| Linux Wayland / X11 | mocked selection, flags, failure fallback | Not performed |
| macOS | mocked pbcopy | Not performed |
| WSL | mocked clip.exe, actual iconv conversion | Not performed |
| Headless SSH | mocked selection and terminal absence | Not performed |
| OSC 52 | exact bytes, newlines, actual Linux pty delivery and fallback | Not performed |
| tmux / screen | exact wrapper bytes; screen limit | Not performed |
| Linux installation | staged install, execution, uninstall | No clipboard needed |

These tests verify implementation behavior, **not end-to-end terminal support**.
CI is configured for Linux and macOS; a configured job is not evidence it has run.
All 35 tests passed locally on Linux with Bats 1.11.1; ShellCheck 0.10.0
reported no issues. Linux pty tests validate delivery only, without a terminal
emulator or clipboard. To repeat:

```sh
# Debian / Ubuntu
sudo apt-get install bats shellcheck
make test
make lint
# Separate, manual integration test (writes your actual clipboard):
bash tests/integration/terminal.sh
```

The manual test asks you to paste into a trusted editor and inspect Unicode and
trailing LFs. Run it in each desired terminal, via SSH, and inside tmux/screen;
record terminal/server versions and settings before claiming compatibility.

## Troubleshooting

- No controlling terminal: use an interactive terminal or `ssh -t`; cron and CI
  normally cannot use OSC 52. Forced native mode can work without a tty.
- Sequence emitted but clipboard unchanged: check the client terminal's OSC 52
  permissions, size limit and tmux passthrough configuration. Try a short string
  outside multiplexers. Local success does not confirm a clipboard update.
- Native failure: check display variables, graphical-session permissions and the
  installed clipboard tool. Use `--check` and `--verbose` (neither logs content).
- Large input: choose a supported native backend or deliberately increase the
  limit; terminal limits remain independent. screen has a separate conservative cap.
- Wrong clipboard through SSH: prefer automatic or forced OSC 52; forced native
  operates where its tool connects, potentially the remote desktop.

## Security

No telemetry, network calls, content history, or dynamic evaluation of input.
Content uses a private `mktemp -d` directory with umask 077 and traps for EXIT,
HUP, INT and TERM. SIGKILL, machine crashes, swap, backups and storage recovery
can leave recoverable data; deletion is not secure erasure. Use a trusted TMPDIR
or memory-backed temporary storage according to your threat model.

Prefer stdin to literal arguments for secrets: arguments can appear in shell
history and process listings. Native tools receive content on stdin. The OSC 52
payload is Base64, **not encryption**; SSH carries it within the SSH terminal
stream. Terminal/session recording can capture that stream. Nothing is emitted
to redirected stdout, but `/dev/tty` necessarily carries encoded content.

Client terminal security policy controls OSC 52. Enabling it lets processes that
can write terminal sequences replace your clipboard. Local clipboard managers,
clipboard history or synchronization software may retain/share copied content.
Review those settings when copying credentials.

MIT licensed. See [CONTRIBUTING.md](CONTRIBUTING.md).
