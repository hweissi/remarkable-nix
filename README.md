# reMarkable Desktop (Nix + Wine)

This flake packages the Windows reMarkable Desktop app for Linux using Wine.

## Why we unpack manually
The Windows installer is built with the Qt Installer Framework and has command-line
automation disabled by the vendor. That means there is no reliable silent or scripted
installation flow for CI/Nix builds. To keep the package reproducible and non-interactive,
we carve the embedded payload archives from the EXE and extract them directly.

## How it works
- The build extracts embedded 7z payloads from the installer EXE into
  `$out/share/remarkable/app`.
- The wrapper initializes a Wine prefix in `$HOME` (or `$REMARKABLE_WINEPREFIX`) and
  runs `reMarkable.exe` directly from the Nix store.

## Usage
```sh
nix build .#remarkable
./result/bin/remarkable
```

or

```sh
nix run .
```


## Notes
- The app runs from the read-only Nix store; self-updates will fail.
- You can override the Wine prefix with `REMARKABLE_WINEPREFIX`.
- If a notification daemon is available, a "Starting reMarkable..." notice is shown.
