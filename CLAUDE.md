# CLAUDE.md - arrowshot

macOS CLI (`arrowshot`) plus an agent skill (`skill/arrowshot`, Claude Code and Codex) that bakes
a big arrow with a sign into a screenshot PNG. Screenshot-only fork of
franzenzenhofer/big-arrow-on-the-screen (remote `upstream`). MIT.

## Layout

- `Sources/BigArrowCore`, `Sources/BigArrowOverlay`: upstream's geometry, placement and sign
  rendering. Change them only when needed, so `git merge upstream/main` stays clean.
- `Sources/BigArrowOverlay/ImageComposer.swift`: treats the screenshot as a display and renders
  the arrow's layer tree over it.
- `Sources/BigArrowTargeting`: window lookup and permission messages for `capture`.
- `Sources/arrowshot`: the CLI (`annotate`, `capture`).

## Rules

- Never draw on the live screen, raise or focus an app. `annotate` must need no permission;
  only `capture` may need Screen Recording, and its error names the app running the shell.
- Coordinates on the command line are image pixels, top-left origin; `--scale` (default from
  the PNG's DPI) converts them to the points the upstream layout works in.
- Swift 6 strict concurrency, SwiftPM, no dependencies besides swift-argument-parser.
- Gates before every commit: `swift build -c release && swift test`.
- Bumping `BigArrowVersion.current` and the skill's "Needs arrowshot X or newer" line go together
  (`SkillVersionTests`).
- The skill is symlinked from this checkout into `~/.claude/skills` and `~/.agents/skills`, and
  `~/.local/bin/arrowshot` links to `.build/release/arrowshot`: rebuild release after changes.

## Commands

```bash
swift build -c release && swift test
.build/release/arrowshot annotate in.png -o out.png --rect 100,100,200,40 --text "1. Click Save"
```
