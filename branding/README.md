# Branding

The app icon: a glowing hourglass on a dark rounded square (supplied by the user, 2026-11-08),
recoloured to the turquoise gradient **Aurora**: `#34D399` → `#22D3EE` → `#3B82F6` (mint, cyan,
blue), from the hourglass's top-left to its bottom-right corner. The user chose it from four
proposals (Lagune, Aurora, Tiefsee, Mint-Petrol).

| File | What |
|---|---|
| `icon-source.jpg` | The original, 2048 px, on a white page with a shadow, in orange → pink → purple. Source of all colour icons (recoloured, see below). |
| `hourglass.svg` | The hourglass in one colour, traced from the original (outline, sand, grains). Coordinates are source pixels around the hourglass centre (1024, 1028). |
| `hourglass-small.svg` | Same shape for 16–24 px: thicker outline, no grains. |

`tool/make_icons.py` makes every icon from these three files (ImageMagick 7 on the host); the
results are committed. Run it again after changing anything here:

| Platform | Icon | Colours |
|---|---|---|
| Android 8+ | adaptive icon: background `#24242A`, foreground = the recoloured hourglass cut out softly | Aurora |
| Android 13+ with "Designsymbole" | monochrome layer from `hourglass.svg` | tinted by the system (wallpaper colours) |
| Android < 8 | the rounded square | Aurora |
| Notification, Quick Settings tile, update notice | `ic_quick.xml` from `hourglass-small.svg` | tinted by the system |
| Linux (window, launcher) | `app/linux/runner/resources/app_icon.png`, copied to `bundle/data/` | Aurora |
| Windows (exe, taskbar) | `app/windows/runner/resources/app_icon.ico`, 16–256 px; 16/24 from `hourglass-small.svg` | Aurora; 16/24 px in `#22D3EE` |

**Recolouring** (`recoloured_source` in the script): brightness comes from the original (glow,
grains, glass), colour from a diagonal gradient; the dark background stays neutral, midtones take
the gradient, highlights go towards white. A plain hue shift can't do this (orange → purple would
become green → red). To try another palette, change `GRADIENT` and run the script.

`tool/make_icons.py --preview DIR` writes `icon-preview.png`: Android masks (circle, squircle,
square), the themed icon in a light and a dark palette, the desktop icon at 256/48/24/16 px and the
small icon in a status bar.
