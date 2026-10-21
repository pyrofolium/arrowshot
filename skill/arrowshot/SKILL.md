---
name: arrowshot
description: "Make annotated screenshots: bake a big arrow with a short action label (\"1. Click Save\") into a PNG of an app or web page, using the arrowshot CLI. Use whenever a screenshot should point at something: PR descriptions and GUI tutorials, step-by-step usage guides, docs, Slack posts, bug reports, 'screenshot with an arrow', 'annotate this screenshot', 'show where to click in a picture', or anything that used to call for bigarrow. Draws nothing on the live screen and never takes the focus."
license: MIT
allowed-tools: Bash(arrowshot:*)
metadata:
  short-description: "Bake big arrows and labels into screenshots"
---

# arrowshot

Needs arrowshot 0.2.0 or newer (`arrowshot --version`).

`arrowshot` draws the big-arrow-with-a-sign look straight into an image file. Nothing appears on
screen, no app is raised, and only `capture` needs a permission (Screen Recording). One arrow per
call; run it again on its own output for the next arrow.

On Linux only `annotate` works: `capture` exits 2, so take the screenshot with
`agent-browser screenshot`, browser-director or `gnome-screenshot`, then annotate it. Linux reads
PNG only, and the sign's font is Nunito (or Ubuntu Sans) instead of SF Pro Rounded.

## The one pattern

```bash
# 1. a plain screenshot (any source, see below)
# 2. find the target's pixel box in that image
arrowshot annotate shot.png -o step1.png --rect X,Y,W,H --text "1. Click Save"
# 3. Read step1.png and check the arrow lands on the right control before you use it
```

Coordinates are **pixels of the image**, top-left origin. `--rect` boxes the control and points
at it (best for buttons, fields, rows); `--at X,Y` points at a spot. `-o` may be the input file.

## Getting the screenshot and the box

| Source | Screenshot | Target box in image pixels |
|---|---|---|
| Page in agent-browser / Playwright | `agent-browser screenshot shot.png` | `agent-browser get box "<selector>"` gives CSS px; multiply by `devicePixelRatio` (1 by default, so use as is) |
| A window (Chrome, native app) | `arrowshot capture --window "Google Chrome" -o shot.png` | Read the image and measure; for a Chrome page at 100 % zoom: `x = r.x * dpr`, `y = (outerHeight - innerHeight + r.y) * dpr` from `getBoundingClientRect()` (dpr is 2 on Retina) |
| A screen region / display | `arrowshot capture --region x,y,w,h -o shot.png` (global screen points) or `--display 2` | Read the image and measure |
| An existing image | (none) | Read it and measure |

- `capture --window "App:title"` picks the window whose title contains `title` (for Chrome, the
  active tab's title). It captures the window even when covered, without raising it, and drops
  the macOS window shadow (`--window-shadow` keeps it). It does not switch tabs: make the right
  tab active first.
- `capture` accepts the same arrow options, so `capture ... -o step1.png --rect ... --text ...`
  does both in one go when you already know the coordinates.
- Arrow size follows the image's DPI: a 144 DPI Retina capture gets `--scale 2` automatically, a
  72 DPI browser screenshot `--scale 1`. Override with `--scale N` if it looks too big or small.

## Several arrows in one image

Number the steps in the sign text. Pass the previous sign's box (`sign` in the `--json` result)
as `--avoid` so the next sign does not cover it, or pick the side with `--from`:

```bash
arrowshot annotate shot.png -o out.png --rect 900,300,200,44 --text "1. Click Save" --json
# → ... "sign":[510,289,240,67] ...
arrowshot annotate out.png --at 160,620 --text "2. Type a name" --color blue --avoid 510,289,240,67
```

For a step-by-step tutorial, prefer one image per step (one arrow each), each captured after the
previous step is done so the UI shows the right state.

## Look

Sign text: a short imperative label, numbered for tutorials ("2. Open a red vine"). `--size S|M|L`
(default S), `--color` red, orange, yellow, green, teal, blue, purple, pink, black, white or #hex,
`--style arrow|box|ring`, `--from top|left|bottom-right|...` (preferred sign side),
`--shape bend|straight|zigzag|spiral`, `--border shadow|white-black|black`, `--corners round|sharp`,
`--border-color`, `--text-color`, `--edge-color`.

## Errors

Exit 2 bad input, 3 target not found (target outside the image, no such app or window; the message
lists the apps with windows), 4 permission missing: `capture` needs Screen Recording for the app
that runs your shell (Terminal, Ghostty, iTerm2, VS Code); the message names it and the pane.
`annotate` never needs a permission.

## Hygiene

Write screenshots to a scratch or task folder, not into the repo under review. Look at every
image before sharing: it must show the intended state and no private content (other tabs,
notifications, personal data). Delete throwaway captures when done.
