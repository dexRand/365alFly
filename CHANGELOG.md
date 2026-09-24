# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-24

First public release.

### Added

- Real Microsoft PowerPoint on Linux through a disposable Windows 11 + Office
  VM (`dockur/windows` in Docker/QEMU-KVM), driven over FreeRDP.
- `wrapper/pptx-open`: opens a `.pptx` in real PowerPoint. Default mode is
  seamless RDP RemoteApp; `--desktop` gives a full RDP desktop and `--vnc` a
  web-VNC session with a shared folder.
- `scripts/pptx-deploy.sh`: environment CLI
  (`init`, `doctor`, `office-config`, `prepare`, `up`, `down`, `reset`, `logs`,
  `status`, `url`).
- `scripts/setup.sh`: idempotent host setup that checks and installs only the
  missing pieces (`--check`, `--dry-run`, `--with-dev`).
- OEM auto-provisioning: Office via the official ODT, trusted location,
  session settings, RemoteApp allowlist, auto-dismiss of the Office sign-in
  prompt.
- Fidelity gate: 13 test decks / 25 slides compared pixel-by-pixel against
  native Windows references (21 byte-identical, 4 anti-aliasing only).
- End-to-end "explode" test (`scripts/e2e-explode.sh`) covering
  open / edit / save / close and host-file persistence.
- CI: shellcheck + bats on push and pull requests (45 tests).

### Security

- No secrets or license keys are committed; `.env`, the generated Office
  configuration and the shared folder are git-ignored.

### Known limitations

- The `--vnc` keyboard trigger requires an unlocked Windows session; the
  seamless RDP mode is the recommended path.
- Office activation requires the user's own product key or a Microsoft 365
  sign-in; the project ships no activation or piracy tooling.
- KVM is required, and the window modes need a local display (X11, or Wayland
  with XWayland); otherwise use the web-VNC mode in a browser.

[0.1.0]: https://github.com/dexRand/365alFly/releases/tag/v0.1.0
