# Contributing

Use Bash 3.2-compatible syntax and standard Linux/macOS command-line tools. Keep
clipboard content in private files, never in Bash variables, logs or command
arguments. Runtime dependencies must be justified. Do not add telemetry.

Install Bats and ShellCheck, then run `make test lint`. Tests mock graphical tools
and assert exact OSC framing without requiring a clipboard. Add regression tests
for observable bugs rather than duplicating implementation details.

`tests/integration/terminal.sh` is a separate manual clipboard-writing test. Before
claiming real compatibility, record OS, terminal/version, SSH/multiplexer versions,
clipboard permission settings, tested size, Unicode and trailing-newline results.
Never include secrets in fixtures or reports. CI covers Linux and macOS; WSL and
real terminal tests require their own execution evidence.

Installation can be tested without root using `make install PREFIX=/tmp/toclip-test`
and the matching `make uninstall`. Packaging should use PREFIX and DESTDIR.

Submit focused changes with a description of the behavior and validation. Update
both README languages and the changelog for user-facing changes. Releases and
remote pushes require the repository owner's authorization.
