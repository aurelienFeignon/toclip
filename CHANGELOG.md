# Changelog

## 0.1.0 — unreleased

- Successful copies are silent by default; `--verbose` reports local status.
- Bash CLI for arguments, stdin and files; bounded private spooling, NUL rejection,
  newline preservation and explicit error codes.
- OSC 52 controlling-terminal output with tmux/screen wrappers and conservative
  size checks; emission explicitly distinguished from clipboard confirmation.
- Native Wayland, X11, macOS and WSL candidates with automatic SSH-aware routing.
- Bats tests, ShellCheck, staged installation and Linux/macOS CI configuration.
- English and French documentation; no real-terminal compatibility claims yet.
