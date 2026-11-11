# Development status — 3D Snake

_Last updated: 2026-11-11 · version 2.0.0 (code 10) · history in [CHANGELOG.md](CHANGELOG.md)_

## Summary

The game (renamed from *Serpent Sanctum* in 1.1.0) is feature-complete for a sideload release. The test suite passes, a signed release
APK builds reproducibly, and the game has been played on a real phone (Samsung Galaxy A56) with the
Vulkan renderer at a steady 60 fps. The UI is translated into 18 languages, including Khmer, with
fonts, shaping and line breaking checked on that phone. It has been tested on only one phone model
so far, and the translations other than English and French still need native speakers to review
them (see Known issues).

## Build and test status

| Check | Result |
|---|---|
| Headless test suite (`tools/run_tests.sh`) | **79 tests, 56,104 checks, 0 failures** (about 77 s) |
| All scripts compile (`tools/check_scripts.gd`) | OK |
| Headless autoplay smoke run of the real main scene | OK, no script errors |
| Release APK `build/android/snake3d.apk` (`tools/build_android.sh`) | **Built, 34 MB, arm64-v8a** (includes 4.8 MB of ICU line-breaking data and 0.7 MB of fallback fonts). Signature verified with apksigner (v2 + v3 schemes) |
| Manifest | `com.studio.snake3d`, version 2.0.0 (10), minSdk 24, targetSdk 36, only the VIBRATE permission |
| Emulator APK `build/android/snake3d-x86_64.apk` | Built and installed on an Android 15 (API 35) x86_64 emulator with the OpenGL renderer: title, menu, play, game over, play again and the records update all worked with touch input, at about 45 fps |
| Physical phone: Samsung Galaxy A56 (SM-A566B), Android 16, Exynos 1580 / Xclipse 540 | Release APK installed over wireless adb. Vulkan 1.3 Mobile renderer. **59.6–59.9 fps** in menus and live play (60 Hz display), worst frame 17–33 ms, no thermal throttling, no errors in the log. Main loop running 2.5 s after launch (warm start). French was picked from the phone's locale. Checked on the device: menu, play, boost and pause touch targets, pause menu, game over, danger vignette and the camera-hole side of the screen. Later: the Quit button closes the app; the main menu, settings, How to play, HUD and game-over screens in Khmer (correct subscript consonants and word-boundary line breaks); the language grid; switching language live. On 2026-11-08: the update installs over the old version and keeps the profile; audio is playing (Android reports the game's stream as started, unmuted, media volume 12/15 on the speaker); haptics fire (Android's vibrator log shows the game's 10 ms pickup and 30 ms stage-up pulses from real play, and the 30 ms test pulse from Settings); swiping the Settings list from a slider or a toggle scrolls it without changing the setting; the Accessibility section in Thai |
| Launch time on the phone (process start → Godot main loop) | **First launch after clearing app data: 6.3 s** (shaders and Vulkan pipelines compiled and cached; first image after 3.3 s). **Normal launch: 3.0 s.** Measured with the Showcase build, so the owner's profile was not touched |
| Relief build on the phone (2026-11-08) | Installed over the previous version, profile kept. **Medium quality (the phone default): steady 60 fps** with the new 60 fps cap (98% of frames at 16 ms over 85 s of autopilot play, 0 dropped). Without the cap the 120 Hz screen got an uneven mix of 8 ms and 16 ms frames (84 fps average). High quality: 54.5 fps (13% of frames at 33 ms). Launch to main loop: 2.8 s (3.6 s on the first launch after the update, which recompiles the changed shaders). Terraces, walls, ramps and the snake climbing a ramp checked on screen |
| Emulator soak (2026-11-08) | 7 minutes of autopilot runs: no errors (the pre-fix build hit the shader instance limit after 1.5–4 minutes) |
| App Bundle `build/android/snake3d.aab` (`tools/build_android.sh --aab`) | **Built, 34 MB**, Gradle 8.11 on JDK 17, signed with the release key (`jarsigner` verified). Not yet installed on a device (needs bundletool or a Play test track) |

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
- Relief: gentle hills, and 2 or 3 raised terraces with stone walls and 1 or 2 paved ramps each. The
  snake climbs ramps and hills; ground steeper than `TerrainField.CLIMB_LIMIT` (0.8, about 39°) is a
  wall. Walls are ordinary obstacles built from the terrain's own slope, so collisions, spawn rules,
  the autopilot and the connectivity guarantee cover them; the autopilot reaches terrace tops by
  their ramps.

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
- Main menu with a **Quit** button (hidden on iOS and the web), Skins & Sanctuaries (14 skins, 9 sanctuaries each with its own island, unlocked through milestones), Records (top 10
  plus lifetime stats), Settings, How to play / About, pause menu, and a game-over screen with
  new-best and unlock announcements.
- 3 steering schemes (drag, tap sides, joystick), sensitivity, left-handed layout, camera distance
  and smoothing, volumes, FPS counter.
- Accessibility: a *Reduced motion* option (no camera shake, banking, FOV zoom or speed lines),
  *Larger in-game text* (HUD texts 1.3 times bigger), a choice of colour for the danger glow (red,
  blue or yellow), and off-screen item arrows that differ in shape as well as colour.
- **18 languages** (Malay and Filipino since 1.8.0): English, French, Khmer, Thai, Vietnamese, Hindi, Spanish, Portuguese (Brazil), German, Italian,
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

## Changes: screenshots (2026-11-07)

- `docs/screenshots/` (now `docs/screenshots/v1.0/`): 20 screenshots (1920×1080 JPEG) covering the three sanctuaries, several
  skins, Surge, relics, stage-ups, the barrier, every menu screen, and Khmer; plus `overview.jpg`
  (contact sheet). Captured on the Android emulator with the autopilot playing.
- `--showcase` mode in `main.gd` and the `Android Showcase` export preset
  (`tools/build_android.sh --showcase`): a separate package with a demo profile and autopilot-driven
  runs, for future screenshot or demo sessions.

## Changes: accessibility and settings touch fixes (2026-11-08)

- **Reduced motion** (*Settings → Accessibility*, off by default, saved in the profile): the chase
  camera ignores shake, stays level in turns and keeps a fixed field of view on boost and Surge, and
  the HUD draws no speed lines. Translated into all 14 languages; the Khmer row was checked on the
  emulator (subscript consonants render correctly).
- **Off-screen markers do not rely on colour alone:** the Surge crystal marker is a diamond and the
  relic marker a ring, matching the 3D items. Cyan and violet are hard to tell apart with some kinds
  of colour blindness. Checked on the emulator during an autopilot run.
- **Fixed: swiping the Settings list from a slider changed the slider.** Godot's slider jumps to
  wherever a finger lands, so a vertical swipe starting on, say, *Steering sensitivity* set it to a
  new value (1.0 became 1.8 in the test) and the list did not scroll. `ScrollSafeSlider` reads the
  gesture first: a horizontal drag moves the slider, a vertical one scrolls the list, and a tap
  still sets the value. Toggles now also let a swipe scroll the list and ignore the release at the
  end of a swipe, as the language buttons already did. Lists also wait for 10 px of finger
  movement before scrolling (it was 0), so a slightly shaky tap is still a tap. Checked on the
  emulator and then on the Galaxy A56: a swipe that starts on the steering-sensitivity slider (set
  to maximum) scrolls the list and the slider stays at maximum.
- Checked on the phone: audio output, haptics, and the cold first-launch time (see the table).
- New tests: `tests/test_accessibility.gd` (4) and `tests/test_ui_touch.gd` (3). The touch tests
  push real input events through the main scene's viewport, and fail on the previous code.

## Changes: relief and graphics (2026-11-08)

- **Relief** (`scripts/world/terrain_field.gd`): 4–6 gentle hills (up to 2 m) and 2–3 raised
  terraces (1.7–2.5 m) with stone walls and 1–2 paved ramps each. The first ramp faces the middle of
  the island; the spawn area, the spawn corridor and the barrier gap stay clear (checked against the
  actual walls when a terrace is placed). Hills fade out well before any terrace, so they never
  steepen a wall or a ramp.
- **Walls are obstacles made from the terrain's own slope**: ground steeper than `CLIMB_LIMIT` (0.8)
  is sampled every 0.5 m and covered by collision circles (about 85 per terrace, built once, about
  80 ms). Collision, spawn rules, the obstacle-gap rule and the connectivity guarantee therefore
  cover walls with no special cases. Ruins and rising monoliths keep off the ramps.
  `Obstacle.edge_distance_within()` skips far obstacles cheaply, so the many wall circles do not
  slow collision checks.
- The ramp's sides are as tall as the ramp is high: steep near the top (part of the wall), gentle
  further down, so the snake can join a ramp from the side near its foot.
- **Autopilot** (menu background, Showcase, tests): goes for food on a terrace through the best
  ramp (foot, then top) and leaves the same way.
- **Camera**: a wall no longer pulls the camera in when the camera is above the terrace.
- **Rendering**:
  - The terrain mesh uses a 0.5 m grid over the arena (±38 m), 1 m around it and 4 m beyond, with
    borders bent onto the coarser grid so the grids meet without cracks. It is built from packed
    arrays instead of SurfaceTool.
  - Fixed: neighbouring terrain grids overlapped by one row of cells (the hole test missed the
    first row), so a strip of ground was drawn twice.
  - Terrace walls are drawn as weathered sandstone courses on a laterite footing, with moss in the
    joints and run-off streaks. Ramps and the wall tops are paved.
  - Vertex ambient occlusion darkens the foot of walls and hollows. Invisible strips along the walls
    cast their shadows (the terrain itself casts none).
  - The grass has broad lush and sun-dried patches, hill slopes wear through to bare earth, and
    there are no grass clumps on walls or paving.
- **Fixed: "Too many instances using shader instance variables"** after a few minutes of autoplay
  in the emulator. Under OpenGL, Godot reserves 16 slots per object that uses `instance uniform`s,
  out of 4096, so at most 256 such objects can exist at once (Vulkan allows 16 times more). The
  stone and glow shaders used them for small things (a per-stone tint, the lantern fade, the
  rising monolith glow). They now use a tint derived from the object's position and ordinary
  material parameters, so the limit can no longer be reached.
- Cost: the world takes about 175 ms longer to build on the development PC (about 0.5 s instead of
  0.39 s). On the phone, launch to main loop is 2.8 s (3.0 s was measured before, on the Showcase
  build).
- **Frame rate capped at 60 on phones** (`Engine.max_fps`). The Galaxy A56's screen runs at 120 Hz,
  and the game alternated 8 ms and 16 ms frames, which looks less smooth than a steady 60 and costs
  battery and heat. Measured on the phone before and after (see the table).
- New tests: `tests/test_relief.gd` (6): every steep spot is out of the head's reach and every wall
  circle sits on a slope; ramps and open ground are climbable and the open ground has real relief;
  the snake climbs a ramp with its body trailing behind; a wall stops it; the autopilot's route
  uses ramps; food appears on terrace tops. The terrain test in `test_world_generation.gd` now
  checks walls instead of "every slope is gentle". `tools/terrain_map.gd` draws a top-down map of
  the relief, walls and ruins for a seed.

## Changes: version 1.1.0 — name, ramps, screenshots history (2026-11-08)

- **Renamed 3D Snake** (app name, main menu title on one line, startup image, credits in all 14
  languages, Showcase app name). The package id is unchanged, so the update keeps players' progress.
- **Version 1.1.0 (code 2)**, with a [CHANGELOG.md](CHANGELOG.md). Git tags `v1.0.0` (the commit the
  1.0 screenshots were taken from) and `v1.1.0`.
- **Every terrace now has two ramps.** With one ramp, a terrace was a dead end: a long snake could not
  turn round on top while its own body filled the only way down. Headless autopilot runs on the
  game's island showed the deaths clustering there.
- **Autopilot** lines up with a ramp's axis (a point 3 m beyond its foot, then the top) instead of
  cutting across from the ramp's edge into its steep upper sides. Over 40 layouts of the game's
  island (90 s cap): average survival 78.1 s → 84.8 s, no deaths in the first 15 s (one before).
- *How to play* has a 7th line about terraces and ramps (14 languages; fonts rebuilt).
- Installed on the Galaxy A56 over 1.0.0: the launcher shows *3D Snake*, the menu title reads
  3D SNAKE, the owner's profile (Thai, best score 871) is kept, launch to main loop 2.9 s.
- **Screenshot history**: the 1.0 screenshots moved to `docs/screenshots/v1.0/` (unchanged, with git
  history); 24 new ones of 1.1.0 in `docs/screenshots/v1.1/` with a captioned contact sheet;
  `docs/screenshots/README.md` lists the versions and how to add the next one. The README gallery
  shows 1.1.0.

## Changes: Google Play preparation (2026-11-08)

- **App Bundle**: `tools/build_android.sh --aab` builds `build/android/snake3d.aab` (34 MB) with
  Gradle through a new *Android Play* preset (same package, version and signing key as the APK). The
  game data travels in an install-time asset pack, as Godot 4.7 does. `tools/setup_godot.sh
  --gradle` fetches what it needs: Godot's Android source template and Eclipse Temurin JDK 17 in
  `tools/jdk-17/` (checksum verified), because Godot 4.7's Gradle 8.11 runs on Java 17–23 only and
  this machine has Java 27 (and 25 in Android Studio). Godot's `--install-android-build-template`
  alone starts the editor and never exits, so the build script passes it with the export instead.
  First build: about 4 minutes with Gradle's downloads. Checked: `jarsigner` verifies the bundle;
  the manifest has package `com.studio.snake3d`, version 1.1.0 (2), VIBRATE as the only requested
  permission, no Internet.
- **Vulkan was already optional**: the manifest marks `android.hardware.vulkan.level` and
  `android.hardware.vulkan.version` `required="false"` (only OpenGL ES 3.0 is required, the
  fallback renderer), so Play does not hide the game from phones without Vulkan. The earlier
  known-issue note saying otherwise was wrong.
- **Upload key**: the existing `signing/release.keystore` (RSA 2048, valid until 2054) meets Play's
  requirement (valid past 2033). It must be backed up; it stays git-ignored.
- **Store listing** in `store/`: 512×512 icon and 1024×500 feature graphic
  (`tools/make_store_assets.py`), English/French/Khmer texts, the screenshots to upload, Data
  safety and content-rating answers, and the publishing steps, including the signing choice that
  decides whether the Play version can update an APK-installed copy.
- **Privacy policy** in `PRIVACY.md` (English and French), public on GitHub: no data collected, no
  Internet access, saves stay on the device.

## Changes: an island per sanctuary (2026-11-08, released in 1.2.0)

- Each theme in `WorldThemes` has a `terrain_seed`: Golden Dawn 20241107 (the 1.1.0 island),
  Moonlit Shrine 20241110, Misty Morning 20241112 (chosen for three terraces each and different
  layouts; all checked by the tests).
- `TerrainField.regenerate(seed)` rebuilds a terrain in place, so the session, snake, camera and
  views keep their reference. `WorldView` keeps everything built from the terrain under one
  `Island` node and `rebuild_island()` replaces just that (sky, lights, materials stay).
- Choosing a sanctuary in *Skins & Sanctuaries* fades out, regenerates the terrain, rebuilds the
  island, restarts the menu's background run on it and fades back, keeping the skins close-up.
  Measured on the Galaxy A56 (Showcase build): 425–431 ms; on the PC about 0.5 s.
- Tests: every sanctuary's island is valid (terraces with two ramps, all reachable over several
  layouts), `regenerate()` equals a new terrain, and switching in the real main scene rebuilds the
  island and the run's walls.
- **Fixed: off-screen item markers could cover the boost or pause button.** A marker that would is
  slid along the screen edge around the button (`Hud.avoid_buttons()`), for both handednesses;
  `test_markers_keep_clear_of_hud_buttons` checks every edge position.

## Changes: version 1.2.0 (2026-11-10)

- **Version 1.2.0 (code 3)**: an island per sanctuary, the Google Play preparation and the
  off-screen marker fix (see [CHANGELOG.md](CHANGELOG.md)). Git tag `v1.2.0`.
- Built with this version: the release APK, the App Bundle, the Showcase APK and the emulator APK;
  the release APK's manifest reads version 1.2.0 (3). Test suite: 64 tests, 0 failed.
- **Screenshots**: 26 new ones in `docs/screenshots/v1.2/` with a captioned contact sheet, taken on
  the Android 15 emulator (OpenGL renderer) from a Showcase-mode build of 1.2.0: all three islands,
  the menus, Khmer. The v1.0 and v1.1 folders are untouched.
- Seen while taking them, on the emulator only: every sanctuary's island loads and plays, the
  language switch works live, Khmer renders correctly in the menu, How to play, Records and the HUD.
- **On the phone** (Galaxy A56, 2026-11-10): the 1.2.0 release APK installed over 1.1.0 as an
  update (Android reports version 1.2.0, code 3). It starts with the Vulkan renderer and the profile
  was kept: the owner's language, best score, records table and unlocked skins are all there.
- **The new islands on the phone**, with the 1.2.0 Showcase build (so the owner's scores were not
  touched): choosing Moonlit Shrine rebuilt the island in 449 ms and Misty Morning in 422 ms; the
  autopilot played about 35 s on each (terraces, ramps, shore, barrier all drawn correctly), with no
  errors in the log. Frame rate at the Showcase build's *high* quality, counting the menu fade and
  with a picture-in-picture video from another app on screen: 53.4 fps average on Moonlit Shrine,
  52.5 on Misty Morning, no janky frames reported, which matches what *high* gave on the 1.1.0
  island (about one frame in eight missed). Not measured at the default (medium) quality on the
  new islands.

## Changes: version 1.3.0 (2026-11-10)

- **Crimson Dusk**, a fourth sanctuary (`dusk` in `WorldThemes`, island seed 20241120: three
  terraces, five hills; unlocked at 25 runs), and **Lotus Cobra**, a ninth skin (300 fruit in
  total). Both are only parameters; the existing tests check the new island like the others
  (two ramps per terrace, whole island reachable over several layouts).
- *Skins & Sanctuaries*: skins five to a row (two rows for nine), sanctuaries four to a row; the
  panel is 60 px wider.
- **Larger in-game text** (`hud_large`): `Hud.set_large_text()` scales the score, best, stage,
  combo, length, banner subtitle, tutorial hint and point popups by 1.3 and moves the stage bar,
  combo ring and labels so nothing overlaps.
- **Danger warning colour** (`danger_color`: red, blue, yellow): the vignette texture is now white
  and tinted by `Hud.set_danger_color()`; red gives exactly the old look.
- 8 new strings in the 14 languages (AI-written except English and French, like the others); the
  fallback fonts were rebuilt for the new characters.
- Tests: `test_larger_hud_text_scales_and_stays_tidy` and `test_danger_colour_setting`
  (66 tests in all, 0 failed).
- Built: release APK, App Bundle, Showcase APK, emulator APK, all 1.3.0 (4).
- **Seen on the emulator** (Android 15, OpenGL, Showcase mode): the Crimson Dusk island loads from
  the sanctuary picker and the autopilot plays on it; the Lotus Cobra skin; the two new settings in
  English and Khmer (subscript consonants correct); larger text in play in English and Khmer.
  The blue and yellow danger glow were seen later the same day, in the plain emulator build, by
  starting a run and not steering (the autopilot never came close enough to an obstacle).
- **Screenshots**: 15 new ones in `docs/screenshots/v1.3/` (what is new); older folders untouched.
- **On the phone** (Galaxy A56, 2026-11-10): the 1.3.0 release APK installed over 1.2.0 (Android
  reports 1.3.0, code 4), starts with Vulkan, profile kept (the owner's language and best score).
- **Frame rate at medium quality (the phone default) on the phone**, Showcase build with
  `--quality=1`, 35 s of autopilot play per island, a picture-in-picture video from another app on
  screen: Misty Morning 99.2 % of frames at 16 ms, Crimson Dusk 99.1 %, Moonlit Shrine 98.8 %;
  no dropped frames, so a steady 60 fps on all three. Islands rebuilt in 523–541 ms when
  switching. Golden Dawn was measured the same way in 1.1.0.
- Not done: installing the App Bundle on a device. That needs Google's bundletool, and downloading
  it was not permitted in this session.

## Changes: version 1.4.0 (2026-11-11)

- **Jade Monsoon**, a fifth sanctuary (`monsoon` in `WorldThemes`, island seed 20241114; unlocked
  at 15 relics), and **Amethyst Krait**, a tenth skin (violet with gold bands; unlocked at
  stage 8). Both are only parameters; the existing tests check the new island like the others.
- *Skins & Sanctuaries*: sanctuaries five to a row; cards 110 px high with a 38 px swatch so both
  skin rows and the sanctuary row fit on one screen without scrolling.
- **Fixed**: the swatch `TextureRect` took its height from its 64 px texture and ignored the
  smaller minimum size, which pushed a two-line name over the card's bottom edge
  (`expand_mode = EXPAND_IGNORE_SIZE`).
- The Showcase demo profile now has a best stage of 8, so it still unlocks every skin.
- 2 new strings in the 14 languages (AI-written except English and French, like the others); the
  fallback fonts were rebuilt for the new characters.
- Tests: `test_skin_and_sanctuary_names_stay_inside_their_cards` (every card, in the 14 languages;
  it fails without the swatch fix). 67 tests in all, 40,180 checks, 0 failed.
- Built: release APK, App Bundle, Showcase APK, emulator APK, all 1.4.0 (5).
- **Seen on the emulator** (Android 15, OpenGL, Showcase mode): the Jade Monsoon island loads from
  the sanctuary picker and the autopilot played a 3-minute run on it to stage 7 (53.9 m) with the
  Amethyst Krait skin, no errors in the log; *Skins & Sanctuaries* in English, Khmer and Thai,
  where two-line names now stay inside their cards.
- **Screenshots**: 14 new ones in `docs/screenshots/v1.4/`; older folders untouched.
- **On the phone** (Galaxy A56, 2026-11-11): the 1.4.0 release APK installed over 1.3.0 (Android
  reports 1.4.0, code 5); the game itself was not opened afterwards, so "profile kept" was not
  looked at this time. In the Showcase build (Vulkan, `--quality=1`, French): *Skins &
  Sanctuaries* fits on one screen with two-line names inside their cards; Jade Monsoon loads in
  438–519 ms and the autopilot played three runs on it with no errors in the log.
- **Frame rate at medium quality on the phone**, 35 s of autopilot play, a picture-in-picture
  video from another app on screen: Jade Monsoon 99.7 % of frames at 16 ms in one run and 90.7 %
  in another (9 % at 33 ms, 56.7 fps average; that stretch included a Surge); Crimson Dusk,
  measured between the two for comparison, 98.7 %. No dropped frames in any of them. So the new
  island holds 60 fps like the others most of the time; the slower stretch was not reproduced.

## Changes: version 1.5.0 (2026-11-11)

- **Silver Frost**, a sixth sanctuary (`frost` in `WorldThemes`, island seed 20241125; unlocked
  at 2000 points in one run), and **Pearl Naga**, an eleventh skin (pearl white, rose sheen;
  unlocked at 60 m in one run). Both are only parameters; the existing tests check the new island
  like the others. The trees and bushes keep their green on the frosted ground.
- *Skins & Sanctuaries*: six cards to a row for both skins and sanctuaries, panel 830 px wide.
- Launch options for screenshots: `--theme=<id>`, `--skin=<id>` (only if unlocked) and
  `--lang=<code>`.
- The Showcase demo profile's best length is now 61.2 m, so it still unlocks every skin.
- 2 new strings in the 14 languages (AI-written except English and French, like the others); the
  fallback fonts were rebuilt for the new characters.
- Tests: `test_frost_and_pearl_unlock_at_their_milestones`. 68 tests in all, 40,281 checks,
  0 failed.
- Built: release APK, App Bundle, Showcase APK, emulator APK, all 1.5.0 (6).
- **Seen on the emulator** (Android 15, OpenGL, Showcase mode): the game starts on Silver Frost
  with the Pearl Naga skin, and the autopilot played a 2 min 20 s run on it to stage 7 (49.9 m,
  2412 points), no errors in the log; *Skins & Sanctuaries* in English, Khmer and Thai, where the
  six cards per row and the new names stay inside the panel and their cards.
- **Screenshots**: 15 new ones in `docs/screenshots/v1.5/`; older folders untouched.
- **Not done on the phone**: the Galaxy A56 was not connected, so 1.5.0 has not been installed
  there, and Silver Frost's look under Vulkan, its loading time and its frame rate are unmeasured.

## Changes: version 1.6.0 (2026-11-11)

- **Turquoise Lagoon**, a seventh sanctuary (`lagoon` in `WorldThemes`, island seed 20241201;
  unlocked at 100 close calls in total), and **Storm Serpent**, a twelfth skin (slate blue, glowing
  gold runes; unlocked at a combo of 8). Two unlock rules are new (`near_misses`, `best_combo`),
  each with its sentence (`REQ_NEAR_MISSES`, `REQ_BEST_COMBO`). The autopilot reached combos of
  3 to 7 in its runs, so 8 asks for a deliberate chain.
- **Vietnamese** (`vi`), the 15th language: 146 strings, AI-written like the others. Cinzel and
  Outfit lack most accented Vietnamese letters, and falling back letter by letter mixed two typefaces inside
  words, so Vietnamese is drawn entirely with a Noto Sans subset
  (`UiTheme.BASE_BY_LANGUAGE`, `NotoSansVi-Subset.ttf`, 189 KB, built by `tools/build_fonts.py`).
  The title "3D SNAKE" is therefore in Noto Sans too in Vietnamese, not in Cinzel.
- *Skins & Sanctuaries* scrolls: seven sanctuaries take two rows, which no longer fit on a 16:9
  screen. The list opens scrolled to the sanctuary in use.
- 4 new strings in the 15 languages; the fallback fonts were rebuilt.
- Tests (3 new, 71 in all, 40,819 checks, 0 failed): the two new unlock thresholds; every unlock
  rule has a translated sentence and a real profile stat; the list scrolls, shows the sanctuary in
  use, a swipe chooses nothing and a tap still chooses; Vietnamese has its own complete font and
  switching language swaps it in and out; `vi_VN` is detected.
- Built: release APK, App Bundle, Showcase APK, emulator APK, all 1.6.0 (7).
- **Seen on the emulator** (Android 15, OpenGL, Showcase mode): two autopilot runs on Turquoise
  Lagoon with the Storm Serpent (1716 and 1869 points, stage 5 both times), no errors in the log.
  After the first one the grass was toned down (it was close to neon). *Skins & Sanctuaries* in
  English, Vietnamese and Khmer; the main menu and Settings in Vietnamese.
- **Screenshots**: 17 new ones in `docs/screenshots/v1.6/`; older folders untouched.
- **Not done on the phone**: 1.6.0 (like 1.5.0) has not been installed on the Galaxy A56, at the
  owner's request to move on; the lagoon's look under Vulkan and its frame rate are unmeasured.
- The store listing has no Vietnamese text yet (English, French and Khmer only).

## Changes: version 1.7.0 (2026-11-11)

- **Amber Autumn**, an eighth sanctuary (`autumn` in `WorldThemes`, island seed 20241207; unlocked
  at 60 Surge crystals in total), and **Tiger Python**, a thirteenth skin (orange, black bands;
  unlocked at 600 fruit in total). One unlock rule is new (`total_energy`, sentence
  `REQ_TOTAL_ENERGY`). The trees keep their green on the amber ground.
- **Hindi** (`hi`), the 16th language: 149 strings, AI-written like the others. Devanagari comes
  from a Noto Sans Devanagari subset used as a fallback (338 KB: the shaping tables for conjuncts
  are kept whole); Latin letters and digits stay in Cinzel and Outfit.
- **Fixed**: the main menu's "3D SNAKE" has a font kind of its own (`logo`) that never changes
  with the language, so it is in Cinzel again in Vietnamese.
- Store listing: Vietnamese and Hindi texts added, counts updated in the others.
- 3 new strings in the 16 languages; the fallback fonts were rebuilt (1.6 MB in all).
- Tests (1 new, 72 in all, 41,301 checks, 0 failed): the two new unlock thresholds; Hindi uses
  its fallback font and `hi_IN` is detected; the logo keeps Cinzel in Vietnamese. The existing
  tests cover the Hindi text for fit, fonts and placeholders like every other language.
- Built: release APK, App Bundle, Showcase APK, emulator APK, all 1.7.0 (8).
- **Seen on the emulator** (Android 15, OpenGL, Showcase mode): two autopilot runs on Amber Autumn
  with the Tiger Python (727 points at stage 4, then 1514 at stage 5), no errors in the log; the
  main menu, *Skins & Sanctuaries* and Settings in Hindi, with conjuncts shaped correctly; the
  Vietnamese main menu; *Skins & Sanctuaries* in English and Khmer.
- **Screenshots**: 19 new ones in `docs/screenshots/v1.7/`; older folders untouched.
- **Not done on the phone**: 1.5.0, 1.6.0 and 1.7.0 have not been installed on the Galaxy A56.

## Changes: version 1.8.0 (2026-11-11)

- **Leaf colours per sanctuary**: a theme may define `leaf_a` and `leaf_b`. The foliage shader
  then recolours the leaves (vertex alpha > 0; bark is left alone), each tree taking a blend of
  the two colours from its position and each leaf cluster keeping its own brightness. Used by
  Silver Frost, Amber Autumn and Violet Aurora; the other six keep the green of the tree meshes.
  One extra `mix` per fragment; the frame rate was not measured.
- **Violet Aurora**, a ninth sanctuary and the second night one (`aurora`, island seed 20241213;
  unlocked at stage 10), and **Nebula Naga**, a fourteenth skin (violet, glowing teal diamonds;
  unlocked at 50 runs). The first version was almost all violet-blue; the grass and light were
  moved towards teal after seeing it on the emulator.
- **Malay** (`ms`) and **Filipino** (`fil`; a phone reporting the older code `tl` gets it too),
  the 17th and 18th languages: 151 strings each, AI-written like the others. Both use the game's
  usual fonts.
- The Showcase demo profile's best stage is now 10, so it still unlocks every sanctuary.
- 2 new strings in the 18 languages; the fallback fonts were rebuilt.
- Tests (2 new, 74 in all, 42,134 checks, 0 failed): the two new unlock thresholds; each
  sanctuary's leaf colours reach the shader and the others switch them off; `ms_MY`, `fil_PH` and
  `tl_PH` are detected.
- Built: release APK, App Bundle, Showcase APK, emulator APK, all 1.8.0 (9).
- **Seen on the emulator** (Android 15, OpenGL, Showcase mode): the new foliage shader compiles
  and the trees are frosted on Silver Frost, orange and red on Amber Autumn, teal and violet on
  Violet Aurora. Three autopilot runs on Violet Aurora with the Nebula Naga, no errors in the
  log: the first ended after 8 seconds against a stone (20 points), the next two reached stage 2
  or more, the best one stage 5 (1081 points). The main menu and *Skins & Sanctuaries* in Malay
  and Filipino; *Skins & Sanctuaries* in English and Khmer.
- **Screenshots**: 22 new ones in `docs/screenshots/v1.8/`; older folders untouched.
- **Not done on the phone**: 1.5.0 to 1.8.0 have not been installed on the Galaxy A56. The new
  foliage shader has therefore not been compiled by the Vulkan renderer yet.
- The store listing has no Malay or Filipino text.

## Changes: version 2.0.0, the environment overhaul (2026-11-11)

Before 2.0.0 every island shared one temple gate, one serpent statue, twelve scattered column
stumps and one kind of column; only the colours and the relief differed.

- **`SanctuaryKit`** (`scripts/world/sanctuary_kit.gd`): modular architecture built in code.
  Columns in five orders, colonnades, arches and voussoir rings, stairs with rails, stepped and
  round bases, tiered towers, hip roofs, domes, stupas, obelisks, trilithons, and props: urns in
  three shapes, bowls, bells in frames, stone lanterns, altars, steles, pedestals, guardian
  idols, fallen heads, rubble, crystals, fire bowls, vines. Everything in a zone is merged into
  three surfaces (stone, vertex-coloured accents, emissive), so a zone costs three draw calls.
- **`SanctuaryStyles`**: one style per sanctuary (column order, monument, second landmark, shore
  set with weights, lake ruins, far-shore silhouette, roof type, two stone tones, paving and wall
  colours, ceramics, timber, light colour, four kinds of tree, flowers, ferns, ground special,
  weather, sun shafts, aurora).
- **`SanctuaryBuilder`**: seeded layout with footprints. Great monument on the north islet,
  second landmark on the east islet, a building on each small islet, 16 stations and up to 16
  prop groups round the shore facing the playfield, up to 9 ruins in the lake where the water is
  deep enough, 6 silhouettes on the far shore. Rules: nothing nearer the centre than the barrier
  plus 1.6 m, no two footprints overlap, trees do not grow through buildings.
- **Playfield**: pillars take the sanctuary's column order (all orders stay inside the classic
  column's width, so the collision circle is unchanged); stone, paving and terrace walls take
  its colours. Ground cover placed in clusters on open ground: ferns, flowers, pebbles, and
  leaf litter, ice shards, shells or glowing mushrooms. None of it collides.
- **Shaders**: stone (two tones in beds, streaks on vertical faces, darker undersides; one extra
  texture read), water (mirrors the horizon colour at grazing angles), sky (northern lights),
  new emissive and sun-shaft shaders. Weather is one particle system re-dressed per sanctuary.
- **Performance measures**: merged meshes per zone (6 shore sectors, so the camera culls most of
  the shore); far shore and islets cast no shadows; ground cover is instanced and hidden beyond
  70 m; weather and ground cover scale with the quality setting and weather is off at low
  quality. Architecture adds 15,000 to 57,000 triangles depending on the sanctuary (Silver Frost
  least, Turquoise Lagoon most). An island builds in 0.6 to 0.8 s on the PC (it was 0.5 to 0.6 s).
- **Fixed on the way**: merging a non-indexed mesh into an indexed one drops the non-indexed
  triangles from the draw list. The old serpent statue was built that way, so its body was
  probably not being drawn (not checked against an old build); it is indexed throughout now.
- **Tests** (5 new, 79 in all, 56,104 checks, 0 failed): every sanctuary has a complete style
  and a monument and landmark of its own; layouts are reproducible, outside the playfield and
  free of overlaps; no built vertex is nearer than the lantern ring; triangle budget; every
  column order fits the pillar collision; switching sanctuary swaps monument, pillars, ground
  cover, weather, stone and sky.
- **Seen on the emulator** (Android 15, OpenGL): a camera tour of all nine sanctuaries (new
  `--tour` option) and autopilot runs on Jade Monsoon and Silver Frost, no errors in the log.
  Frame rate in the menu scene at medium quality: 59.4 fps for 1.8.0, 55 to 58 fps for 2.0.0
  (before the last two trims: one texture read fewer in the stone shader, half the mist). An
  autopilot run at high quality: 46.9 fps.
- **Not done on the phone**: the Galaxy A56 was not connected. Nothing since 1.4.0 has been
  measured there, and 2.0.0 is the heaviest change yet: the phone's frame rate at medium quality
  is the main open question.
- **Limits**: this is stylised, procedural low-poly architecture with one tiling stone texture,
  not photorealistic scanned assets; there are no interiors; no real-time light from the new
  fires and lanterns (they glow but do not light their surroundings); the far-shore pieces have
  no level of detail of their own; islet and shore buildings do not adapt to a steep slope beyond
  standing on a deep foundation.

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
- The App Bundle has only been checked structurally (signature, contents, manifest), not installed
  on a device: that needs Google's bundletool (`build-apks` / `install-apks`) or a Play internal
  test track.
- With no steering, the snake reaches the barrier about 6 s after "GO!". This is intended: the
  first-run tutorial shows how to steer.
- Audio and haptics were checked through Android's own reports (audio stream started and unmuted,
  vibrations logged as played), not by ear or by hand. Whether the mix sounds right still needs a
  person to listen.
- Launch options such as `--autoplay` cannot be passed to the Android build with
  `adb shell am start --esa command_line_params`: Godot's launcher activity ignores them. Put them in
  the export preset's `command_line/extra_args` instead (as the Showcase preset does).

## Remaining work

1. **Have native speakers review the translations**, Khmer first (including the accessibility
   strings and the newer names: Crimson Dusk, Lotus Cobra, Jade Monsoon, Amethyst Krait,
   Silver Frost, Pearl Naga, Turquoise Lagoon, Storm Serpent), and the whole Vietnamese
   translation (new in 1.6.0), the Hindi one (1.7.0), and the Malay and Filipino ones (1.8.0).
2. **Test on more phones**, especially a low-end one and other GPU families (Qualcomm Adreno, ARM
   Mali). Check frame rate at each quality level, then tune the default quality. The Galaxy A56
   runs the default (medium) at a steady 60 fps with the relief; high drops about one frame in
   eight there, so medium stays the default.
3. Listen to the audio mix and feel the haptics on a phone (Android reports both working), and try
   *Reduced motion* during a real run on the phone (only the automated tests cover it in play).
4. For a Play Store release (prepared, see [store/README.md](store/README.md)): create the Play
   Console app, fill in the listing, upload `build/android/snake3d.aab` to internal testing and test
   it on a phone, back up `signing/`, and have a native speaker check the Khmer listing text.
5. Play a real run by hand on the Moonlit Shrine, Misty Morning and Crimson Dusk islands on the
   phone (so far only the autopilot has played them there; medium quality holds 60 fps on all).
6. On the phone, look at the blue and yellow danger glow and at *Larger in-game text* during a real
   run (the glow's new colours have been seen on the emulator only: screenshots 14 and 15 of
   `docs/screenshots/v1.3`). Yellow stands out less than blue on Crimson Dusk's warm light; a
   person should judge whether it is strong enough there.
7. Play a real run by hand on Jade Monsoon on the phone, and watch for slow stretches there (one
   35 s measurement out of two had 9 % of frames at 33 ms).
8. Install 2.0.0 on the phone (1.5.0 to 2.0.0 have only run on the emulator): check that the
   update keeps the profile, look at the new architecture under Vulkan, and above all measure the
   frame rate there, and try scrolling *Skins & Sanctuaries* with a finger.
9. Optional: more languages, more sanctuaries and skins; Malay and Filipino store listings.
