# Changelog

What changed in each version of the game. Version numbers are the Android app's `versionName`
(the `versionCode` is in brackets). Screenshots of every version are kept in
[docs/screenshots](docs/screenshots/README.md), and each version is tagged in git (`v1.0.0`, `v1.1.0`, `v1.2.0`, `v1.3.0`).

## 1.3.0 (4) — 2026-11-10

Screenshots: [docs/screenshots/v1.3](docs/screenshots/v1.3/README.md)

### Added
- **A fourth sanctuary, Crimson Dusk**: a low sun, a violet and pink sky, and an island of its own
  (three terraces). Unlocked after 25 runs.
- **A ninth skin, Lotus Cobra** (pink with pale stripes). Unlocked after eating 300 fruit in total.
- **Larger in-game text** (Settings → Accessibility): the score, best score, stage, combo, length,
  hints and point popups are drawn 1.3 times bigger.
- **Danger warning colour** (Settings → Accessibility): the glow at the screen edges when the
  serpent is close to an obstacle can be red (as before), blue or yellow. Dark red is hard to see
  with red-blind vision.
- All of the above in the 14 languages.

### Changed
- *Skins & Sanctuaries* shows the skins five to a row and the sanctuaries four to a row.

## 1.2.0 (3) — 2026-11-10

Screenshots: [docs/screenshots/v1.2](docs/screenshots/v1.2/README.md)

### Added
- **Each sanctuary has its own island**: Golden Dawn keeps the 1.1.0 island, Moonlit Shrine and
  Misty Morning get islands of their own (other terraces, hills and shore). Choosing a sanctuary
  rebuilds the island behind a short fade (0.43 s on a Galaxy A56).
- Google Play preparation: an App Bundle build (`tools/build_android.sh --aab`), the store listing
  and graphics in `store/`, and a privacy policy (`PRIVACY.md`).

### Fixed
- Off-screen arrows pointing at a crystal or relic could cover the boost or pause button; they now
  slide along the screen edge around them.

## 1.1.0 (2) — 2026-11-08

Screenshots: [docs/screenshots/v1.1](docs/screenshots/v1.1/README.md)

### Changed
- **New name: 3D Snake** (it was *Serpent Sanctum*): the app name, the main menu title, the startup
  image and the credits in all 14 languages. The package id stays `com.studio.snake3d`, so the update
  installs over 1.0.0 and keeps the player's progress.
- The frame rate is capped at 60 fps on phones. On 120 Hz screens the game alternated 120 and 60 fps
  frames, which looked less smooth than a steady 60 and cost battery.

### Added
- **Relief.** The island has gentle hills and 2–3 raised terraces with stone walls, each reached by
  two paved ramps. The serpent climbs and descends ramps and hills; the walls (any ground steeper
  than about 39°) stop it like a pillar does. Food and relics also appear on terrace tops. The
  whole island stays reachable in every layout.
- *How to play* explains the terraces (new line in all 14 languages).
- **Reduced motion** (Settings → Accessibility): no camera shake, banking, zoom effects or speed
  lines.
- Off-screen arrows show the item's shape as well as its colour (a diamond for Surge crystals, a
  ring for relics), for colour-blind players.

### Improved
- Terrain look: stone terrace walls (sandstone on a laterite footing, moss in the joints), paved
  ramps, shading at the foot of walls and in hollows, shadows of the walls, grass with lush and
  dry patches, bare earth on hill slopes.
- The menu-background and Showcase autopilot takes the ramps to reach terrace tops.

### Fixed
- In Settings, a vertical swipe starting on a slider changed its value instead of scrolling the
  list; a swipe starting on a toggle did not scroll either.
- After a few minutes on OpenGL devices (and the Android emulator), the game logged "Too many
  instances using shader instance variables".
- Two terrain grids overlapped by one row of cells, so a strip of ground was drawn twice.

## 1.0.0 (1) — 2026-11-07

Screenshots: [docs/screenshots/v1.0](docs/screenshots/v1.0/README.md). The game was then called
*Serpent Sanctum*.

First release.
- Third-person 3D snake with smooth steering on a flat lakeside island: sunfruit, Surge crystals,
  rare relics, combos, Close Call bonuses, boost with stamina, 14 stages with rising monoliths.
- Chase camera, procedural models, textures, music and sound effects, haptics, a first-run tutorial
  and an AI attract mode behind the main menu.
- 8 serpent skins and 3 sanctuaries (Golden Dawn, Moonlit Shrine, Misty Morning) unlocked by
  milestones; records; settings for three steering schemes, left-handed layout, camera, graphics
  quality, volumes and FPS counter; a Quit button.
- 14 languages, including Khmer and Thai with proper fonts and line breaking.
- A Showcase build for screenshots and demos.
