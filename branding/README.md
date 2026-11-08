# Branding

The app icon: a glowing hourglass on a dark rounded square (supplied by the user, 2026-11-08).

| File | What |
|---|---|
| `icon-source.jpg` | The original, 2048 px, on a white page with a shadow. Source of all colour icons. |
| `hourglass.svg` | The hourglass in one colour, traced from the original (outline, sand, grains). Coordinates are source pixels around the hourglass centre (1024, 1028). |
| `hourglass-small.svg` | Same shape for 16–24 px: thicker outline, no grains. |

`tool/make_icons.py` makes every icon from these three files (ImageMagick 7 on the host); the
results are committed. Run it again after changing anything here:

| Platform | Icon | Colours |
|---|---|---|
| Android 8+ | adaptive icon: background `#24242A`, foreground = the original cut out softly | original |
| Android 13+ with "Designsymbole" | monochrome layer from `hourglass.svg` | tinted by the system (wallpaper colours) |
| Android < 8 | the rounded square as is | original |
| Notification, Quick Settings tile, update notice | `ic_quick.xml` from `hourglass-small.svg` | tinted by the system |
| Linux (window, launcher) | `app/linux/runner/resources/app_icon.png`, copied to `bundle/data/` | teal (app colour) |
| Windows (exe, taskbar) | `app/windows/runner/resources/app_icon.ico`, 16–256 px; 16/24 from `hourglass-small.svg` | teal (app colour) |

Linux and Windows don't recolour app icons, so the desktop uses the app's own colour
(`seedColor = Colors.teal`): the original's brightness mapped onto a teal ramp, which keeps the glow
and the grains (a plain hue shift would turn the purple yellow-green).

`tool/make_icons.py --preview DIR` writes `icon-preview.png`: Android masks (circle, squircle,
square), the themed icon in a light and a dark palette, the desktop icon at 256/48/24/16 px and the
small icon in a status bar.
