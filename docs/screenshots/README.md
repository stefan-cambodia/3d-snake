# Serpent Sanctum — screenshots

Captured on 2026-11-07 from the game running on Android (1920×1080, high quality setting), with the
autopilot playing the runs. Free to use for documentation, store pages and presentations.
`overview.jpg` is a contact sheet of all of them.

| | |
|---|---|
| ![](01-main-menu.jpg) **01** Main menu (Golden Dawn) | ![](02-gameplay-surge.jpg) **02** Surge crystal: speed and double points |
| ![](03-gameplay-stage-up.jpg) **03** Stage 6: faster, and monoliths rise | ![](04-gameplay-long-serpent.jpg) **04** A 44 m serpent winding through the ruins |
| ![](05-gameplay-relic-beam.jpg) **05** A rare relic, marked by a beam of light | ![](06-night-crystal.jpg) **06** Moonlit Shrine: Surge crystal pickup |
| ![](07-night-relic.jpg) **07** Moonlit Shrine: relic collected (+450) | ![](08-night-surge.jpg) **08** Moonlit Shrine: Surge and combo |
| ![](09-night-barrier.jpg) **09** Stage 5 beside the glowing sanctuary barrier | ![](10-mist-stage-up.jpg) **10** Misty Morning with the Ember Python skin |
| ![](11-main-menu-night.jpg) **11** Main menu (Moonlit Shrine, Azure Naga) | ![](12-main-menu-mist.jpg) **12** Main menu (Misty Morning, Ember Python) |
| ![](13-skins-sanctuaries.jpg) **13** Skins & Sanctuaries: 8 serpents, 3 sanctuaries | ![](14-game-over-new-best.jpg) **14** Game over with a new best score |
| ![](15-records.jpg) **15** Records: hall of fame | ![](16-how-to-play.jpg) **16** How to play |
| ![](17-settings-languages.jpg) **17** Settings: 14 languages | ![](18-khmer-main-menu.jpg) **18** Khmer: main menu |
| ![](19-khmer-how-to-play.jpg) **19** Khmer: How to play (word-boundary line breaks) | ![](20-khmer-gameplay.jpg) **20** Khmer: Surge during a run |

## How to take new ones

1. Build the showcase variant: `tools/build_android.sh --showcase`
   (`build/android/snake3d-showcase.apk`). It installs as a separate app, *Serpent Sanctum
   Showcase* (`com.studio.snake3d.showcase`), so the real game and its scores are untouched.
2. Its first launch fills an empty profile with a demo history (a records table, every skin and
   sanctuary unlocked) and sets graphics quality to high. Every run started with **Play** is played
   by the autopilot, so the snake grows long and reaches later stages without anyone touching it.
   Change skin, sanctuary and language from the menus as usual.
3. Capture with `adb exec-out screencap -p > shot.png` (on a phone or an emulator).

These images came from the Android emulator, which uses the OpenGL renderer; phones use Vulkan,
which looks nearly identical.
