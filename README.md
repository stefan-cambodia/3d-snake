# 3D Snake

A third-person 3D snake game for Android, built with **Godot 4.7** and GDScript.

You guide a living serpent across a lakeside island sanctuary: eat sunfruit to grow, chain pickups
for combos, grab Surge crystals and rare relics, and dodge pillars, the barrier, your own body and
monoliths that rise out of the ground as the stages climb. The island has relief: rolling hills,
and raised stone terraces whose walls block the way but whose paved ramps let the serpent climb up
and back down. Every model, texture, sound and music track is generated procedurally (see `tools/`). The only third-party assets are the fonts (Cinzel, Outfit and Noto, all under the SIL OFL).

![3D Snake main menu](docs/screenshots/v1.7/01-main-menu-autumn.jpg)

| | | |
|---|---|---|
| ![Golden Dawn terraces](docs/screenshots/v1.2/02-dawn-terraces.jpg) | ![Surge on a terrace](docs/screenshots/v1.2/03-dawn-surge.jpg) | ![Moonlit Shrine, Stage 3](docs/screenshots/v1.2/07-night-stage-3.jpg) |
| ![Moonlit Shrine relic](docs/screenshots/v1.2/09-night-relic.jpg) | ![Misty Morning shore](docs/screenshots/v1.2/15-mist-shore.jpg) | ![Crimson Dusk terrace](docs/screenshots/v1.3/06-dusk-terrace.jpg) |
| ![Jade Monsoon ramp](docs/screenshots/v1.4/04-monsoon-ramp.jpg) | ![Jade Monsoon, a long Amethyst Krait](docs/screenshots/v1.4/07-monsoon-long-serpent.jpg) | ![Jade Monsoon relic](docs/screenshots/v1.4/03-monsoon-relic.jpg) |
| ![Silver Frost ramp](docs/screenshots/v1.5/05-frost-ramp.jpg) | ![Silver Frost, a long Pearl Naga](docs/screenshots/v1.5/10-frost-long-serpent.jpg) | ![Skins and sanctuaries](docs/screenshots/v1.5/13-skins-sanctuaries.jpg) |
| ![Turquoise Lagoon shore](docs/screenshots/v1.6/02-lagoon-shore.jpg) | ![Turquoise Lagoon, a Storm Serpent on a terrace](docs/screenshots/v1.6/09-lagoon-terrace.jpg) | ![Vietnamese](docs/screenshots/v1.6/14-vietnamese-main-menu.jpg) |
| ![Amber Autumn, the Tiger Python](docs/screenshots/v1.7/04-autumn-tiger-python.jpg) | ![Amber Autumn, Surge on a terrace](docs/screenshots/v1.7/10-autumn-surge-terrace.jpg) | ![Hindi](docs/screenshots/v1.7/15-hindi-main-menu.jpg) |
| ![Accessibility settings](docs/screenshots/v1.3/10-settings-accessibility.jpg) | ![Khmer](docs/screenshots/v1.2/24-khmer-main-menu.jpg) | ![Skins and sanctuaries in Khmer](docs/screenshots/v1.5/14-khmer-skins-sanctuaries.jpg) |

More in [docs/screenshots/v1.7](docs/screenshots/v1.7/README.md) (19 images of what is new in 1.7.0),
[docs/screenshots/v1.6](docs/screenshots/v1.6/README.md) (17 images of what was new in 1.6.0),
[docs/screenshots/v1.5](docs/screenshots/v1.5/README.md) (15 images of what was new in 1.5.0),
[docs/screenshots/v1.4](docs/screenshots/v1.4/README.md) (14 images of what was new in 1.4.0),
[docs/screenshots/v1.3](docs/screenshots/v1.3/README.md) (15 images of what was new in 1.3.0)
and [docs/screenshots/v1.2](docs/screenshots/v1.2/README.md) (26 images of the three older islands),
1920×1080, each with a contact sheet. Screenshots of earlier versions are kept in the [screenshot history](docs/screenshots/README.md).

- Package id: `com.studio.snake3d`, version 1.7.0 (code 8)
- Android 7.0+ (API 24), arm64-v8a, landscape
- Renderer: Godot *Mobile* (Vulkan); Godot falls back to OpenGL ES 3 when a device has no usable Vulkan driver at startup
- 16 languages: English, Français, ខ្មែរ (Khmer), ไทย (Thai), Tiếng Việt (Vietnamese), हिन्दी (Hindi), Español, Português, Deutsch, Italiano, Türkçe,
  Bahasa Indonesia, Русский, 日本語, 한국어, 简体中文. The phone's language is picked automatically on first launch

## Install the APK on a phone

The prebuilt, signed APK is written to **`build/android/snake3d.apk`** by the build script (see
below). It is a build output, so it is not stored in git.

**With USB (adb):**

1. On the phone, enable *Developer options* (tap *Build number* 7 times) and turn on *USB debugging*.
2. Connect it and run:
   ```sh
   adb install -r build/android/snake3d.apk
   ```

**Without a computer:** copy the APK to the phone, open it from a file manager and allow
"Install unknown apps" for that app when Android asks.

If Android says the package conflicts with an existing one, the installed copy was signed with a
different key. Uninstall it first (`adb uninstall com.studio.snake3d`); this erases its scores.

## Controls

| Action | Touch (default) | Keyboard / gamepad (desktop testing) |
|---|---|---|
| Steer | Slide a finger left/right anywhere on screen | A/D or ←/→, left stick or D-pad |
| Boost (uses stamina) | Hold the round button, bottom right | Shift, Space, W or ↑, gamepad A or right trigger |
| Pause | Pause button (top right), Android *Back*, or leaving the app | Esc or P |

In **Settings** you can switch steering to *Tap sides* (hold the left/right half of the screen) or a
floating *Joystick*, change steering sensitivity, mirror the layout for left-handed play, and adjust
camera distance and smoothing, graphics quality, haptics, volumes, FPS counter and language
(any of the 14). The main menu's **Quit** button saves and closes the game (Android *Back* on the
main menu does the same).

**Accessibility:** *Settings → Accessibility → Reduced motion* turns off camera shake, banking in
turns, the field-of-view zoom on boost and Surge, and the speed lines, for players prone to motion
sickness. The arrows at the screen edge that point to off-screen items also differ in shape (a
diamond for a Surge crystal, a ring for a relic), so they don't rely on telling cyan from violet. *Larger in-game text* draws the score, stage,
combo, length, hints and point popups 1.3 times bigger, and *Danger warning colour* changes the red
glow at the screen edges (shown when the serpent is close to an obstacle) to blue or yellow, which
are easier to see with red-blind vision.

**Scoring:** sunfruit 10 points, Surge crystal 25 (plus double points and extra speed for 5 s),
violet relic 150. Pickups within 3.2 s of each other build a combo multiplier up to ×3. Grazing an
obstacle without touching it gives a *Close Call* bonus. Every 6 fruits moves you up a stage
(14 in total): the snake gets faster and more monoliths rise. Score, length and stage
milestones unlock 12 more serpent skins and 7 more sanctuaries, each with its own island.

**Relief:** each sanctuary is an island of its own (Golden Dawn, Moonlit Shrine and Misty Morning
have different terraces, hills and shores). The snake follows the ground over hills and up ramps. Any ground steeper than about 39°
(the stone walls of the terraces) is a wall and ends the run like a pillar does. Each terrace has
one or two ramps, and food and relics also appear on the terrace tops.

## Requirements (to build from source)

- Linux x86_64 (the scripts use bash; the Godot steps work the same on other OSes)
- **Godot 4.7.2** editor, plus the matching **Android export templates**
- **Android SDK** with `platform-tools` and `build-tools` (Android Studio installs both)
- **JDK 17 or newer** (tested with OpenJDK 27)
- Python 3 for `tools/setup_godot.sh` (the optional asset generators also need numpy and Pillow;
  `tools/build_fonts.py` needs fontTools)

## Set up the toolchain

```sh
tools/setup_godot.sh
```

This downloads Godot 4.7.2 into `tools/godot/` (self-contained mode, git-ignored), fetches only the
Android export templates from the official bundle (about 230 MB instead of 1.3 GB), creates a debug
keystore and points the editor at your Android SDK and JDK. Set `ANDROID_HOME` and/or `JAVA_HOME`
first if they are not in the default places (`~/Android/Sdk`, the JDK on your `PATH`).

To use your own Godot install instead, pass it as `GODOT=/path/to/godot` to the scripts below, and
configure the Android SDK / JDK paths under *Editor Settings → Export → Android*.

## Run the game

```sh
tools/godot/godot --path .            # play on desktop (mouse = touch)
tools/godot/godot --path . --editor   # open the project in the Godot editor
```

The game also accepts automation flags after `--`, for example
`tools/godot/godot --path . -- --autoplay --quit-after=30` (the AI plays; see the top of
`scripts/core/main.gd` for the full list).

To see an island's relief from above (height, walls in red and their collision circles, ramps in
blue, ruins), run `tools/godot/godot --headless --path . -s tools/terrain_map.gd -- --seed=20241107
--px=8 --out=map.png`. 20241107 is the seed of the island in the game.

## Run the tests

```sh
tools/run_tests.sh                       # whole suite, headless; exit code 0 = all passed
tools/run_tests.sh --filter=test_spine   # only matching suites/tests
```

72 tests cover snake movement and steering, the relief and each sanctuary's island (walls cover all ground too steep to climb, ramps and hills are climbable, the snake climbs a ramp and is stopped by a wall), the spine (body path) maths, collisions, scoring and
combos, stage progression, rising obstacles, fair collectible spawning, world generation over many
seeds (including connectivity of the free space), save/load and corrupt-save recovery, an AI
autopilot run, the real main scene's state machine, camera, and HUD/touch layout around display
cut-outs, the translations (every key in every language, matching `%d`/`%s` placeholders,
fonts covering every character, and every screen fitting on a phone in every language), the
*Reduced motion* option, and touch gestures in the settings list (swiping from a slider or a toggle
scrolls the list without changing it).

## Build the Android APK

```sh
tools/build_android.sh                # release build -> build/android/snake3d.apk
tools/build_android.sh debug          # debug build (debug keystore)
tools/build_android.sh --emulator     # x86_64 build for the Android emulator -> build/android/snake3d-x86_64.apk
tools/build_android.sh --showcase     # demo build for screenshots -> build/android/snake3d-showcase.apk
tools/build_android.sh --aab          # Android App Bundle for Google Play -> build/android/snake3d.aab
```

The showcase build installs as a separate app (*3D Snake Showcase*) with a demo profile, and
the autopilot plays every run: see [docs/screenshots](docs/screenshots/README.md).

The script imports the project, exports with the `Android` preset from `export_presets.cfg`, and
checks the APK signature with `apksigner`.

**App Bundle (Google Play).** Play only accepts `.aab` files, which Godot builds with Gradle. Run
`tools/setup_godot.sh --gradle` once: it adds the Android source template and a JDK 17 in
`tools/jdk-17/` (Godot 4.7's Gradle 8.11 does not run on newer Java). The first `--aab` build
unpacks Godot's Android project into `android/build/` (git-ignored) and downloads Gradle's
dependencies, so it needs internet and takes several minutes; later builds are faster. The bundle is
signed with the same release key and checked with `jarsigner`. The store listing, graphics and
publishing steps are in [store/README.md](store/README.md); the privacy policy is
[PRIVACY.md](PRIVACY.md).

**Signing.** The first release build creates `signing/release.keystore` with a random password
stored next to it in `signing/release.properties`. That folder is git-ignored. **Back it up**: an
installed copy can only be updated by an APK signed with the same key. To sign with your own key,
set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` (alias) and
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` before running the script.

From the Godot editor you can instead use *Project → Export… → Android*, or *Remote Debug / One-click
deploy* with a phone connected over USB.

## Languages and translating

All UI text lives in **`assets/i18n/strings.csv`**: one row per key, one column per language (the
header row holds the locale codes). It opens in any spreadsheet program; keep it UTF-8 and comma
separated. Godot imports it into `strings.<locale>.translation` files (generated, not in git).

- **Fix or change a translation:** edit the cell and keep the same `%d` / `%s` / `%.1f` placeholders, in
  the same order, as the English text.
- **Add a language:** add a column (header = locale code, e.g. `vi`), then add the code to
  `LOCALES` in `scripts/core/localization.gd` and to `internationalization/locale/translations` in
  `project.godot`. If the language uses a new script, add a Noto font for it in `tools/build_fonts.py`
  and in `UiTheme.FALLBACKS_BY_LANGUAGE`.
- **After any change to the CSV, run `python3 tools/build_fonts.py`.** Cinzel and Outfit only cover
  Latin, so Khmer, Thai, Cyrillic, Chinese, Japanese and Korean use Noto fonts. The script cuts them
  down to the characters the translations use (about 0.7 MB in total instead of 50 MB) while keeping the
  shaping rules Khmer and Thai need. Then run the tests: they fail if a key or a character is missing,
  or if a translation is too long for its screen.

Khmer and Thai do not put spaces between words, so line breaking uses the ICU data that the project
exports (`internationalization/locale/include_text_server_data`, about 4.8 MB in the APK).

## Project layout

```
scenes/main/main.tscn     entry scene (everything else is built in code)
scripts/core/             game flow state machine (main.gd), tuning constants, localisation, helpers
scripts/snake/            simulation (snake_sim, spine path buffer) and the GPU-skinned body view
scripts/gameplay/         session rules, scoring, collectibles, effects, autopilot
scripts/world/            seeded island generator, terrain and relief, obstacles, meshes and themes
scripts/camera/           chase camera (intro, chase, death, menu and showcase modes)
scripts/input/            touch, keyboard and gamepad steering
scripts/ui/               HUD and menus (theme, screens, game over, settings, skins, records)
scripts/save/             player profile: settings, stats, high scores, unlocks
assets/                   generated audio, textures, icons; shaders; fonts; i18n/strings.csv
tests/                    headless test runner and suites
docs/screenshots/         screenshots for documentation and presentations
tools/                    setup/build/test scripts and the asset generators
```

## Troubleshooting

- **`Godot not found at tools/godot/godot`**: run `tools/setup_godot.sh`, or pass `GODOT=...`.
- **Export fails with "export templates not found" or missing SDK / JDK**: rerun
  `tools/setup_godot.sh` with `ANDROID_HOME` / `JAVA_HOME` set, or fix the paths under
  *Editor Settings → Export → Android*. The SDK needs `build-tools` (for `apksigner` / `zipalign`).
- **`INSTALL_FAILED_UPDATE_INCOMPATIBLE`**: the installed app was signed with another key. Uninstall
  it first, or build with the same keystore.
- **`INSTALL_FAILED_NO_MATCHING_ABIS`**: you installed the arm64 APK on an x86_64 emulator. Use
  `tools/build_android.sh --emulator`.
- **Black screen in the Android emulator**: Godot's Vulkan output does not appear on the emulator
  here (tested with both SwiftShader and host-GPU modes). The `--emulator` build therefore starts with
  the OpenGL (Compatibility) renderer. Real phones use Vulkan.
- **First launch is slow**: shaders are compiled and cached on first run. Later launches are faster.
- **Wireless debugging (`adb pair` / `adb connect`)**: pair with the code and the address shown under
  *Wireless debugging → Pair device with pairing code*, then `adb connect <phone-ip>:<port>` using the
  port on the main *Wireless debugging* screen. That port differs from the pairing port.
- **`adb: more than one device/emulator`**: pick one with `adb -s <serial> install ...`
  (`adb devices` lists the serials).
- **Squares or missing letters in some language**: run `python3 tools/build_fonts.py` (the
  translations use a character the bundled fonts don't have yet), then rebuild.
- **Profile looks wrong or a save got corrupted**: the game backs up an unreadable profile as
  `profile.cfg.bak` and starts fresh. *Settings → Reset progress* clears everything.

## Licence notes

Godot Engine is MIT-licensed. The Cinzel, Outfit and Noto fonts are under the SIL Open Font
License (`assets/fonts/*-OFL.txt`, `assets/fonts/fallback/Noto-OFL.txt`). All other assets were generated by the scripts in `tools/`.
