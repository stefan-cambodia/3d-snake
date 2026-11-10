# Screenshot history

One folder per released version. A new version gets a new folder; older folders are never
overwritten, so this directory shows how the game looked at each release.

| Version | Date | Folder | What it shows |
|---|---|---|---|
| **1.2.0** (current) | 2026-11-10 | [v1.2](v1.2/README.md) · [contact sheet](v1.2/overview.jpg) | 26 images: the three islands (Golden Dawn, and the new Moonlit Shrine and Misty Morning islands), menus, Khmer |
| 1.1.0 | 2026-11-08 | [v1.1](v1.1/README.md) · [contact sheet](v1.1/overview.jpg) | 24 images: the relief (hills, walled terraces, paved ramps), the new name *3D Snake*, the Reduced motion setting, all three sanctuaries, menus, Khmer |
| 1.0.0 | 2026-11-07 | [v1.0](v1.0/README.md) · [contact sheet](v1.0/overview.jpg) | 20 images of the first release, then called *Serpent Sanctum*: a flat island |

What changed between versions is listed in [CHANGELOG.md](../../CHANGELOG.md).

## How to take new ones

1. Build the showcase variant: `tools/build_android.sh --showcase`
   (`build/android/snake3d-showcase.apk`). It installs as a separate app, *3D Snake Showcase*
   (`com.studio.snake3d.showcase`), so the real game and its scores are untouched.
   For the Android emulator, which cannot show Godot's Vulkan output, build the emulator preset
   instead with `-- --showcase` added to its `command_line/extra_args` (and the OpenGL renderer it
   already uses), then put the preset back.
2. Its first launch fills an empty profile with a demo history (a records table, every skin and
   sanctuary unlocked) and sets graphics quality to high. Every run started with **Play** is played
   by the autopilot, so the snake grows long and reaches later stages without anyone touching it.
   Change skin, sanctuary and language from the menus as usual.
3. Capture with `adb exec-out screencap -p > shot.png` (on a phone or an emulator), every second or
   so during a run, and keep the best frames.
4. Save them as 1920×1080 JPEGs in a new `vX.Y/` folder with its own `README.md` and
   `overview.jpg`, add a row to the table above, and point the gallery in the main README at the
   new folder.
