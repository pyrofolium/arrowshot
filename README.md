# arrowshot

Bake a big arrow with a sign into a screenshot. A screenshot-only fork of
[franzenzenhofer/big-arrow-on-the-screen](https://github.com/franzenzenhofer/big-arrow-on-the-screen)
(`bigarrow`): same arrow, sign and box rendering, but drawn into a PNG instead of over the live
screen. No overlay window, no focus change, no app raising, no Accessibility permission.

Made for agents writing PR tutorials, docs and bug reports: take a screenshot, point at the
control, check the image, share it.

```bash
arrowshot annotate shot.png -o step1.png --rect 900,300,200,44 --text "1. Click Save"
arrowshot capture --window "Google Chrome:My App" -o step2.png --at 160,620 --text "2. Type a name"
```

## Commands

| Command | What it does |
|---|---|
| `annotate <image> -o out.png` | Draws one arrow into an existing image. `-o` may be the input itself; run again for more arrows. |
| `capture -o out.png` | Screenshots a window (`--window "App[:title]"`, even when covered, never raised), a region (`--region x,y,w,h` in screen points) or a display (`--display N`), then annotates it if arrow options are given. Needs Screen Recording for the app running your shell. |

Arrow options (both commands): `--at x,y` or `--rect x,y,w,h` in **image pixels**, `--text`,
`--from <side>`, `--size S|M|L` (default S), `--color`, `--style arrow|box|ring`,
`--shape bend|straight|zigzag|spiral`, `--border shadow|white-black|black`, `--corners`,
`--border-color`, `--text-color`, `--edge-color`, `--avoid x,y,w,h` (keep the sign off an area,
repeatable), `--scale N` (pixels per point; default from the PNG's DPI, so Retina captures get 2),
`--json`.

Exit codes: 0 ok, 2 bad input, 3 target not found, 4 permission missing.

## Install

```bash
git clone https://github.com/pyrofolium/arrowshot && cd arrowshot
swift build -c release
ln -sf "$PWD/.build/release/arrowshot" ~/.local/bin/arrowshot
# the agent skill, for Claude Code and Codex
ln -sfn "$PWD/skill/arrowshot" ~/.claude/skills/arrowshot
ln -sfn "$PWD/skill/arrowshot" ~/.agents/skills/arrowshot
```

Requires macOS 14+ and Xcode 16+.

### Linux

`annotate` also builds on Linux (tested on Ubuntu 24.04, arm64); `capture` is macOS only.

```bash
sudo apt install libcairo2-dev libpango1.0-dev   # plus a Swift 6 toolchain, e.g. via swiftly
swift build -c release
```

The sign's font is [Nunito](https://fonts.google.com/specimen/Nunito) when it is installed (the
closest free match for SF Pro Rounded Heavy), else Ubuntu Sans. Linux reads PNG input only.

## Development

```bash
swift build -c release && swift test
```

The arrow geometry, placement and sign rendering (`BigArrowCore`, `BigArrowOverlay`) are
upstream's, kept as they are so upstream fixes merge cleanly (`git fetch upstream && git merge
upstream/main`). The live-overlay CLI, its scripts and docs were removed; `ImageComposer` and
`Sources/arrowshot` are new.

## License

MIT, as upstream. Copyright notices for upstream and its third-party assets are in `LICENSE` and
`THIRD_PARTY_NOTICES.md`.
