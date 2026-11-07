# Serpent Sanctum

A third-person 3D snake game for Android, built with **Godot 4.7** and GDScript.

You guide a living serpent across a lakeside island sanctuary: eat sunfruit to grow, chain pickups
for combos, grab Surge crystals and rare relics, and dodge pillars, the barrier, your own body and
monoliths that rise out of the ground as the stages climb. Every model, texture, sound and music
track is generated procedurally (see `tools/`). The only third-party assets are the two OFL fonts.

- Package id: `com.studio.snake3d`, version 1.0.0 (code 1)
- Android 7.0+ (API 24), arm64-v8a, landscape
- Renderer: Godot *Mobile* (Vulkan); Godot falls back to OpenGL ES 3 when a device has no usable Vulkan driver at startup

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
(English / French).

**Scoring:** sunfruit 10 points, Surge crystal 25 (plus double points and extra speed for 5 s),
violet relic 150. Pickups within 3.2 s of each other build a combo multiplier up to ×3. Grazing an
obstacle without touching it gives a *Close Call* bonus. Every 6 fruits moves you up a stage
(14 in total): the snake gets faster and more monoliths rise. Score, length and stage
milestones unlock 7 more serpent skins and 2 more sanctuary themes.

## Requirements (to build from source)

- Linux x86_64 (the scripts use bash; the Godot steps work the same on other OSes)
- **Godot 4.7.2** editor, plus the matching **Android export templates**
- **Android SDK** with `platform-tools` and `build-tools` (Android Studio installs both)
- **JDK 17 or newer** (tested with OpenJDK 27)
- Python 3 for `tools/setup_godot.sh` (the optional asset generators also need numpy and Pillow)

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

## Run the tests

```sh
tools/run_tests.sh                       # whole suite, headless; exit code 0 = all passed
tools/run_tests.sh --filter=test_spine   # only matching suites/tests
```

39 tests cover snake movement and steering, the spine (body path) maths, collisions, scoring and
combos, stage progression, rising obstacles, fair collectible spawning, world generation over many
seeds (including connectivity of the free space), save/load and corrupt-save recovery, an AI
autopilot run, and the real main scene's state machine and camera.

## Build the Android APK

```sh
tools/build_android.sh                # release build -> build/android/snake3d.apk
tools/build_android.sh debug          # debug build (debug keystore)
tools/build_android.sh --emulator     # x86_64 build for the Android emulator -> build/android/snake3d-x86_64.apk
```

The script imports the project, exports with the `Android` preset from `export_presets.cfg`, and
checks the APK signature with `apksigner`.

**Signing.** The first release build creates `signing/release.keystore` with a random password
stored next to it in `signing/release.properties`. That folder is git-ignored. **Back it up**: an
installed copy can only be updated by an APK signed with the same key. To sign with your own key,
set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` (alias) and
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` before running the script.

From the Godot editor you can instead use *Project → Export… → Android*, or *Remote Debug / One-click
deploy* with a phone connected over USB.

## Project layout

```
scenes/main/main.tscn     entry scene (everything else is built in code)
scripts/core/             game flow state machine (main.gd), tuning constants, localisation, helpers
scripts/snake/            simulation (snake_sim, spine path buffer) and the GPU-skinned body view
scripts/gameplay/         session rules, scoring, collectibles, effects, autopilot
scripts/world/            seeded island generator, terrain, obstacles, meshes and themes
scripts/camera/           chase camera (intro, chase, death, menu and showcase modes)
scripts/input/            touch, keyboard and gamepad steering
scripts/ui/               HUD and menus (theme, screens, game over, settings, skins, records)
scripts/save/             player profile: settings, stats, high scores, unlocks
assets/                   generated audio, textures, icons; shaders; fonts
tests/                    headless test runner and suites
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
- **`adb: more than one device/emulator`**: pick one with `adb -s <serial> install ...`
  (`adb devices` lists the serials).
- **Profile looks wrong or a save got corrupted**: the game backs up an unreadable profile as
  `profile.cfg.bak` and starts fresh. *Settings → Reset progress* clears everything.

## Licence notes

Godot Engine is MIT-licensed. The Cinzel and Outfit fonts are under the SIL Open Font License
(`assets/fonts/*-OFL.txt`). All other assets were generated by the scripts in `tools/`.
