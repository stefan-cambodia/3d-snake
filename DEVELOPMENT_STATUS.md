# Development status

_Last updated: 2026-11-07_

## Summary

The game is feature-complete for a 1.0 sideload release. The test suite passes, a signed release
APK builds reproducibly, and the game has been played on a real phone (Samsung Galaxy A56) with the
Vulkan renderer at a steady 60 fps. The UI is translated into 14 languages, including Khmer, with
fonts, shaping and line breaking checked on that phone. It has been tested on only one phone model
so far, and the translations other than English and French still need native speakers to review
them (see Known issues).

## Build and test status

| Check | Result |
|---|---|
| Headless test suite (`tools/run_tests.sh`) | **47 tests, 27,797 checks, 0 failures** (about 19 s) |
| All scripts compile (`tools/check_scripts.gd`) | OK |
| Headless autoplay smoke run of the real main scene | OK, no script errors |
| Release APK `build/android/snake3d.apk` (`tools/build_android.sh`) | **Built, 34 MB, arm64-v8a** (includes 4.8 MB of ICU line-breaking data and 0.7 MB of fallback fonts). Signature verified with apksigner (v2 + v3 schemes) |
| Manifest | `com.studio.snake3d`, version 1.0.0 (1), minSdk 24, targetSdk 36, only the VIBRATE permission |
| Emulator APK `build/android/snake3d-x86_64.apk` | Built and installed on an Android 15 (API 35) x86_64 emulator with the OpenGL renderer: title, menu, play, game over, play again and the records update all worked with touch input, at about 45 fps |
| Physical phone: Samsung Galaxy A56 (SM-A566B), Android 16, Exynos 1580 / Xclipse 540 | Release APK installed over wireless adb. Vulkan 1.3 Mobile renderer. **59.6–59.9 fps** in menus and live play (60 Hz display), worst frame 17–33 ms, no thermal throttling, no errors in the log. Main loop running 2.5 s after launch (warm start). French was picked from the phone's locale. Checked on the device: menu, play, boost and pause touch targets, pause menu, game over, danger vignette and the camera-hole side of the screen. Later: the Quit button closes the app; the main menu, settings, How to play, HUD and game-over screens in Khmer (correct subscript consonants and word-boundary line breaks); the language grid; switching language live |

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
- Main menu with a **Quit** button (hidden on iOS and the web), Skins & Sanctuaries (8 skins, 3 themes, unlocked through milestones), Records (top 10
  plus lifetime stats), Settings, How to play / About, pause menu, and a game-over screen with
  new-best and unlock announcements.
- 3 steering schemes (drag, tap sides, joystick), sensitivity, left-handed layout, camera distance
  and smoothing, volumes, FPS counter.
- **14 languages**: English, French, Khmer, Thai, Spanish, Portuguese (Brazil), German, Italian,
  Turkish, Indonesian, Russian, Japanese, Korean, Simplified Chinese. All text lives in
  `assets/i18n/strings.csv`; the phone's language is picked on first launch and can be changed live
  in Settings. Non-Latin scripts use subsetted Noto fonts (`tools/build_fonts.py`), and Khmer and Thai
  get dictionary-based line breaking from the exported ICU data.
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
- **Fixed (found on the phone): the screen edge on the camera-hole side.** With the cut-out on the
  left, a 92 px strip there was not covered by the danger vignette, the dimmed menu backdrops or the
  main menu gradient. Worse, the HUD sat inside the safe-area margins, so the **boost and pause touch
  areas were about 60 UI units left of the drawn buttons**, and the steer indicator, off-screen item
  markers and score popups were drawn shifted. The HUD now spans the whole screen (its coordinates
  equal touch and camera coordinates) and insets only its buttons and labels. Backdrops use
  `UiRoot.full_bleed()` to extend under the cut-out. The safe area is re-checked every 0.5 s, so
  flipping the phone to the other landscape side moves the layout too.
  `test_safe_area_insets_keep_hud_and_touch_aligned` covers this.
- The test runner awaits each test, so a test can wait for frames.
- `export/android/shutdown_adb_on_exit` is now off (also in `tools/setup_godot.sh`). Before this,
  every headless export ran `adb kill-server`, which dropped wireless-debugging connections.

## Changes: Quit button and languages (2026-11-07, later the same day)

- **Quit button** at the bottom of the main menu: saves the profile and closes the app (the same as
  Android *Back* on the main menu). Verified on the phone.
- **Internationalisation:** the strings moved from code into `assets/i18n/strings.csv` (126 keys ×
  14 locales), imported by Godot's CSV translation importer. `Localization` now only detects and
  applies the language. The language picker is a grid showing each language in its own script.
- **Fonts:** Godot sizes text lines by the tallest font in a fallback chain, and the Noto fonts for
  Thai and CJK are 15–20 % taller than Outfit. So each language only gets the fallback for its own
  script, and Latin languages keep exactly their old layout. A separate "picker" font holds every
  script for the language grid.
- **Main menu fits on any phone:** with the extra button, the column needed 757 px for 720. It now
  scales down by up to 20 % when needed (about 5 % in Latin languages). An early version scaled a
  container's child, which Godot silently resets; the new test caught this, and it was fixed and
  checked on the phone.
- **Scrolling from a button:** a swipe that started on a button (for example the language grid)
  did not scroll the settings list, so on the phone half the languages were out of reach. Those
  buttons now pass drags to the scroll container, and a press released at the end of a swipe is
  ignored, so scrolling never picks a language by accident. Verified on the phone.
- The language choice is saved immediately (other settings still save when Settings closes).
- New `tests/test_localization.gd` (7 tests): CSV columns match the supported locales, every key is
  translated with the same placeholders, Godot serves the CSV's text, every key used in the code
  exists, device-language detection (`fr_BE`→fr, `km_KH`→km, `zh_TW`→zh_CN, legacy `in`→id…), the fonts
  cover every character of every language, and every screen fits at 1280×720 in every language.

## Known issues and limitations

- **The translations other than English and French were written by an AI** and have not been
  reviewed by native speakers. Khmer (and Thai) matter most here: the Khmer text renders correctly,
  but its wording should be checked by a Khmer speaker. Fixes only need edits to `strings.csv`.
- Testing on the phone added a few short runs to the owner's profile (run count, records); one
  of them took the run count to 10, which unlocked the "Coral Bands" skin.

- **Vulkan shows a black screen on the Android emulator** (not on real phones). Godot logs
  `Couldn't present to Vulkan queue (VkResult error 5)` with both SwiftShader and host-GPU
  emulation, so the emulator build uses the OpenGL Compatibility renderer. On the Galaxy A56
  (Xclipse 540) Vulkan works. Other GPU families (Adreno, Mali, PowerVR) are untested. If a phone
  has no usable Vulkan driver at startup, Godot falls back to OpenGL automatically.
- The very first launch after install compiles shaders. On the emulator's OpenGL renderer that took
  about 35 s. It was not timed on the phone; a warm start reaches the main loop in 2.5 s.
- Headless runs print "ObjectDB instances leaked / resources still in use at exit". These are the
  looping Ogg streams that the engine's audio server is still holding at shutdown. Stopping the
  players in `_exit_tree` did not remove the warning. It only happens at exit and does not affect
  play.
- The manifest declares the Vulkan hardware features (Godot adds them for the Mobile renderer).
  Sideloading is not affected, but a Play Store listing would hide the game from devices without
  Vulkan.
- With no steering, the snake reaches the barrier about 6 s after "GO!". This is intended: the
  first-run tutorial shows how to steer.
- Audio output and haptics on the phone were not checked in this session: the tests here can't
  hear sound or feel vibration.

## Remaining work

1. **Have native speakers review the translations**, Khmer first.
2. **Test on more phones**, especially a low-end one and other GPU families (Qualcomm Adreno, ARM
   Mali). Check frame rate at each quality level, then tune the default quality. The Galaxy A56
   runs the default (medium) at 60 fps, so it could probably default to high.
3. Check audio and haptics on a phone, and time a cold first launch after a fresh install.
4. For a Play Store release: switch to a Gradle build to produce an AAB, decide whether the Vulkan
   features should be marked optional, add store assets and a privacy policy (the game collects no
   data), and use a long-lived upload key.
5. Optional: more languages, more sanctuary themes and skins, and accessibility options
   (colour-blind-safe item colours, reduced camera motion).
