# Development status

_Last updated: 2026-11-07_

## Summary

The game is feature-complete for a 1.0 sideload release. The test suite passes, a signed release
APK builds reproducibly, and the full flow has been played on an Android emulator. It has **not yet
been run on a physical phone**, and the Vulkan renderer has not been seen working on Android (see
Known issues).

## Build and test status

| Check | Result |
|---|---|
| Headless test suite (`tools/run_tests.sh`) | **39 tests, 23,721 checks, 0 failures** (about 11 s) |
| All scripts compile (`tools/check_scripts.gd`) | OK |
| Headless autoplay smoke run of the real main scene | OK, no script errors |
| Release APK `build/android/snake3d.apk` (`tools/build_android.sh`) | **Built, 30 MB, arm64-v8a**. Signature verified with apksigner (v2 + v3 schemes) |
| Manifest | `com.studio.snake3d`, version 1.0.0 (1), minSdk 24, targetSdk 36, only the VIBRATE permission |
| Emulator APK `build/android/snake3d-x86_64.apk` | Built and installed on an Android 15 (API 35) x86_64 emulator with the OpenGL renderer: title, menu, play, game over, play again and the records update all worked with touch input, at about 45 fps |
| Physical Android device | **Not tested** |

## Features

**Gameplay**
- Smooth, continuous steering (not grid-based). The body follows the exact path of the head using
  an arc-length ring buffer. Growth is gradual, up to 190 m of body.
- Collisions with obstacles, the island barrier and the snake's own body, using slightly forgiving
  hit-spheres. A short snake can circle tightly without killing itself.
- Collectibles: sunfruit (grow, 10 points), cyan Surge crystals (speed and double points for 5 s),
  rare violet relics marked by a beam of light (150 points, short-lived). Spawn rules keep them
  reachable and fair.
- Combo multiplier (up to ×3), *Close Call* near-miss bonus, boost with stamina.
- 14 stages: speed increases, and monoliths rise from the ground after a glowing warning circle.
  A monolith waits for the snake to move off its spot, and the free area always stays connected.
- Seeded island layout with a guaranteed clear spawn corridor, checked across many seeds by the tests.

**Presentation**
- Third-person chase camera: predictive yaw, speed-based distance and FOV, banking, shake, pulling
  in when an obstacle blocks the view, plus intro, death-orbit, menu-orbit and skin-showcase shots.
- GPU-skinned snake body with a gulp animation and a flicking tongue. Lakeside island with water,
  grass, foliage, pillars, broken and fallen columns, ruined walls, rocks and braziers. 3 graphics
  quality levels (medium by default on phones, high on desktop).
- Procedural audio: two music tracks with crossfades, 17 sound effects, lake ambience and a slither
  loop that follows speed. The music is muffled while paused.
- Haptic feedback, a first-run tutorial, and AI attract mode behind the main menu.

**Meta and UI**
- Main menu, Skins & Sanctuaries (8 skins, 3 themes, unlocked through milestones), Records (top 10
  plus lifetime stats), Settings, How to play / About, pause menu, and a game-over screen with
  new-best and unlock announcements.
- 3 steering schemes (drag, tap sides, joystick), sensitivity, left-handed layout, camera distance
  and smoothing, volumes, FPS counter, English/French. The language is auto-detected.
- The profile is saved with ConfigFile. A corrupt save is backed up and replaced with defaults.
- The game pauses automatically when the app loses focus. Android *Back* moves back through menus.

## Changes in this session

- **Fixed: the camera stayed in the slow menu orbit for the whole run when a game was started from
  the main menu.** Runs started with *Play again* were not affected. `_begin_run()` hid the menus
  after it set the camera to INTRO. That emitted `screen_changed` while the state was still MENU,
  and the menu handler reset the camera. Now the menus are hidden first, and the handler ignores
  the "no screen" case. `tests/test_game_flow.gd` covers this and fails without the fix.
- The test runner waits one frame before it starts, so suites can instance the real main scene.
- Added `export_presets.cfg` (an `Android` preset and an `Android Emulator x86_64` preset),
  `tools/setup_godot.sh`, `tools/build_android.sh` and `tools/run_tests.sh`.
- Release signing uses a generated local keystore in `signing/` (git-ignored).
- Removed a NUL-character literal in a test that caused "Unicode parsing error" noise.

## Known issues and limitations

- **Vulkan shows a black screen on the Android emulator.** Godot logs
  `Couldn't present to Vulkan queue (VkResult error 5)`, with both SwiftShader and host-GPU
  emulation. With the OpenGL Compatibility renderer, the same build renders correctly, so the
  emulator build uses that renderer. Phones use the Mobile (Vulkan) renderer, which has **not been
  checked on real hardware**. If a phone has no usable Vulkan driver at startup, Godot falls back to
  OpenGL automatically. That does not cover a driver that starts but then fails to present.
- First launch is slow while shaders compile: about 35 s on the emulator with the OpenGL renderer.
  It is likely much shorter on a real GPU, but this has not been measured.
- Headless runs print "ObjectDB instances leaked / resources still in use at exit". These are the
  looping Ogg streams that the engine's audio server is still holding at shutdown. Stopping the
  players in `_exit_tree` did not remove the warning. It only happens at exit and does not affect
  play.
- The manifest declares the Vulkan hardware features (Godot adds them for the Mobile renderer).
  Sideloading is not affected, but a Play Store listing would hide the game from devices without
  Vulkan.
- With no steering, the snake reaches the barrier about 6 s after "GO!". This is intended: the
  first-run tutorial shows how to steer.
- Audio was not heard on Android: the emulator ran without audio output. Desktop audio uses the
  same streams.

## Remaining work

1. **Test on physical phones** (low-end, mid-range and flagship). Confirm Vulkan rendering, touch
   feel, frame rate at each quality level, haptics and audio. Tune the quality auto-detection with
   real numbers.
2. Measure first-launch shader compile time on a real device. If it is long, add a loading
   indicator or precompile shaders behind the title card.
3. For a Play Store release: switch to a Gradle build to produce an AAB, decide whether the Vulkan
   features should be marked optional, add store assets and a privacy policy (the game collects no
   data), and use a long-lived upload key.
4. Optional: more languages, more sanctuary themes and skins, and accessibility options
   (colour-blind-safe item colours, reduced camera motion).
