# Changelog

All notable changes to Wall Hop are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/) (pre-1.0: minor = milestone, patch = fixes and polish).

## [Unreleased]

## [0.4.2] - 2026-11-20
### Changed
- The perch landing hint is now a small still arrow on the plank instead of a faint copy of the character, which looked like a second character standing there.

## [0.4.1] - 2026-11-20
### Added
- **Double tap**: a second tap early in a hop makes a high hop (rises 190 px, lands a little later). Once per hop; a late second tap still queues the next hop.
- A high hop reaches perches 150 px further up.
- **Fruit towers**: 4 fruit stacked in the middle; a plain hop gets at most 2, a double tap in the middle gets them all.
- Perch **landing ghost**: a faint copy of the character on the perch the next hop would land on.
- Perch **timer dots**: three dots under the propeller go out one by one and turn orange near the end (no blinking).
- Perch **landing press**: the plank dips and springs back (off with reduced motion).
- Sounds for the high hop, landing on a perch and the propeller stopping (Kenney, CC0).
- This changelog.

### Changed
- Perch hold time and reach depend on the zone: 2.5 s in Meadow down to 1.5 s in Night Tower.
- Perches are spaced 1500 px apart (was 1300) to fit the longer hold in Meadow.
- `tests/run_tests.sh` also prints the fruit tower timing summary.

## [0.4] - 2026-11-20
### Added
- **Perches**: hovering lifts in the middle of the shaft. A hop from a wall stops on a perch when one is in reach (it shines a little brighter); the next tap hops on to the far wall.
- Four kinds of perch: still, sliding left-right, sinking (carries the rider down) and elevator (rises and sinks). Moving perches appear from the first zone.
- A perch holds the player for 2 s; its propeller stops and it slowly turns orange before it gives out (no blinking), then the player hops on automatically.
- New fruit layouts: sine waves, diagonal swoops eaten in one hop, and sunflower clusters (`scripts/fruit_layout.gd`).
- Shuffle bag for fruit types (40 per bag), so rare fruit comes regularly without long streaks.
- `tests/run_tests.sh`: passes only when the test prints `PASS:`, so script parse errors are caught.
- Tests for perches, fruit clearance, swoops, fruit points and the shuffle bag.

### Changed
- Fruit has a fixed value each: apple 5, bananas 8, orange 10, cherries 12, kiwi 15, strawberry 20, pineapple 30, melon 50.
- Reduced motion halves perch glides and slows sinking perches.
- Screenshots in `docs/` are no longer imported into the game build (`docs/.gdignore`).

- Fruit in the middle is never placed inside a hazard's reach (its whole swing or slide range).

### Removed
- The fruit combo multiplier and its HUD label.

## [0.3.1] - 2026-11-19
Comfort pass after playtesters reported dizziness, headaches, eye strain and nausea.

### Added
- **Reduced motion** option (gear icon on the title screen, or `R`): no afterimages, embers or sparks, still icons.
- "TAKE A BREAK" reminder on the game over screen after 15 minutes of play.
- Comfort checks in the simulation test and "Comfort rules" in `docs/GAME_DESIGN.md`.

### Changed
- Calmer walls: bigger bricks under a still haze that lowers contrast.
- Shorter, eased hops: 360 px instead of 456, slow start and slow stop.
- Top scroll speed lowered to 420 px/s (was 540).
- Soft fade instead of a fast blink while protected after a continue.
- Title and game over icons breathe slowly instead of pulsing.

### Removed
- Screen shake.
- Background scrolling (only the walls scroll now).

## [0.3] - 2026-11-19
### Added
- Random fruit trails down the middle of the shaft.
- Fireballs gliding wall to wall, with glow, ember trail and sparks.
- Fruit values by rarity (5 to 40 points, times the combo).
- Continue after game over for 100, then 250 fruit points (at most 2 per run).
- Character shop: Ninja Frog (free), Mask Dude (500), Pink Man (1200), Virtual Guy (2500), each with a spin and an afterimage trail in its own colour.
- Fruit points are banked into a wallet between runs.

### Changed
- Title and game over screens use icons and numbers instead of sentences.
- Score, fruit points and combo moved to the top-left corner.

### Fixed
- Tapping a character in the shop started the game instead of buying it.

## [0.2] - 2026-11-19
### Added
- Five zones, each adding one new idea: Meadow, Saw Mill (sliding saws, zigzags), Hot Forge (fire jets), Sky Garden (swinging spiked balls), Night Tower (everything, endless).
- Zone banner, background crossfade and a breather at each zone change.
- Fruit combo x1-x5 with floating points.
- Dust puff on landing.
- Mute button (top-right, or `M`), saved between sessions.
- Furthest zone shown on the title and game over screens.
- Headless simulation test (`tests/sim_run.gd`) checking the fairness rules.

## [0.1] - 2026-11-19
### Added
- First playable version: one-tap hop between the left and right walls.
- Saws and spikes, collectible fruit.
- Score and saved best score, game over and retry.
- Music and sound effects.

[Unreleased]: https://github.com/1mlucas/WallHop/compare/v0.4.2...HEAD
[0.4.2]: https://github.com/1mlucas/WallHop/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/1mlucas/WallHop/compare/v0.4...v0.4.1
[0.4]: https://github.com/1mlucas/WallHop/compare/v0.3.1...v0.4
[0.3.1]: https://github.com/1mlucas/WallHop/compare/v0.3...v0.3.1
[0.3]: https://github.com/1mlucas/WallHop/compare/v0.2...v0.3
[0.2]: https://github.com/1mlucas/WallHop/compare/v0.1...v0.2
[0.1]: https://github.com/1mlucas/WallHop/releases/tag/v0.1
