# Screenshot history

One folder per released version. A new version gets a new folder; older folders are never
overwritten, so this directory shows how the game looked at each release.

| Version | Date | Folder | What it shows |
|---|---|---|---|
| **2.0.0** (current) | 2026-11-11 | [v2.0](v2.0/README.md) · [contact sheet](v2.0/overview.jpg) | 21 images of the environment overhaul: each of the nine sanctuaries' monument and shore, an overview, rain and snow in play |
| 1.8.0 | 2026-11-11 | [v1.8](v1.8/README.md) · [contact sheet](v1.8/overview.jpg) | 22 images of what is new: the Violet Aurora sanctuary and its island, the Nebula Naga skin, the new leaf colours on Amber Autumn and Silver Frost, Malay, Filipino, Khmer |
| 1.7.0 | 2026-11-11 | [v1.7](v1.7/README.md) · [contact sheet](v1.7/overview.jpg) | 19 images of what is new: the Amber Autumn sanctuary and its island, the Tiger Python skin, Hindi, the Vietnamese main menu, Khmer |
| 1.6.0 | 2026-11-11 | [v1.6](v1.6/README.md) · [contact sheet](v1.6/overview.jpg) | 17 images of what is new: the Turquoise Lagoon sanctuary and its island, the Storm Serpent skin, the scrolling Skins & Sanctuaries screen, Vietnamese, Khmer |
| 1.5.0 | 2026-11-11 | [v1.5](v1.5/README.md) · [contact sheet](v1.5/overview.jpg) | 15 images of what is new: the Silver Frost sanctuary and its island, the Pearl Naga skin, the Skins & Sanctuaries screen in English, Khmer and Thai |
| 1.4.0 | 2026-11-11 | [v1.4](v1.4/README.md) · [contact sheet](v1.4/overview.jpg) | 14 images of what is new: the Jade Monsoon sanctuary and its island, the Amethyst Krait skin, the Skins & Sanctuaries screen in English, Khmer and Thai |
| 1.3.0 | 2026-11-10 | [v1.3](v1.3/README.md) · [contact sheet](v1.3/overview.jpg) | 15 images of what is new: the Crimson Dusk sanctuary and its island, the Lotus Cobra skin, larger in-game text and the danger colour setting, Khmer |
| 1.2.0 | 2026-11-10 | [v1.2](v1.2/README.md) · [contact sheet](v1.2/overview.jpg) | 26 images: the three islands (Golden Dawn, and the new Moonlit Shrine and Misty Morning islands), menus, Khmer |
| 1.1.0 | 2026-11-08 | [v1.1](v1.1/README.md) · [contact sheet](v1.1/overview.jpg) | 24 images: the relief (hills, walled terraces, paved ramps), the new name *3D Snake*, the Reduced motion setting, all three sanctuaries, menus, Khmer |
| 1.0.0 | 2026-11-07 | [v1.0](v1.0/README.md) · [contact sheet](v1.0/overview.jpg) | 20 images of the first release, then called *Serpent Sanctum*: a flat island |

What changed between versions is listed in [CHANGELOG.md](../../CHANGELOG.md).

## How to take new ones

1. Build the showcase variant: `tools/build_android.sh --showcase`
   (`build/android/snake3d-showcase.apk`). It installs as a separate app, *3D Snake Showcase*
   (`com.studio.snake3d.showcase`), so the real game and its scores are untouched.
   For the Android emulator, which cannot show Godot's Vulkan output, build the emulator preset
   instead with `-- --showcase` added to its `command_line/extra_args` (and the OpenGL renderer it
   already uses), then put the preset back. `--theme=<id>`, `--skin=<id>` and `--lang=<code>` after
   `--showcase` start the game on that sanctuary, with that skin, in that language
   (for example `-- --showcase --theme=frost --skin=pearl --lang=km`). Adding `--tour` hides the
   menus and moves a free camera round the sanctuary's architecture, a new viewpoint every
   4 seconds (monument, second landmark, four stretches of shore, the lake, an overview).
2. Its first launch fills an empty profile with a demo history (a records table, every skin and
   sanctuary unlocked) and sets graphics quality to high. Every run started with **Play** is played
   by the autopilot, so the snake grows long and reaches later stages without anyone touching it.
   Change skin, sanctuary and language from the menus as usual.
3. Capture with `adb exec-out screencap -p > shot.png` (on a phone or an emulator), every second or
   so during a run, and keep the best frames.
4. Save them as 1920×1080 JPEGs in a new `vX.Y/` folder with its own `README.md` and
   `overview.jpg`, add a row to the table above, and point the gallery in the main README at the
   new folder.
