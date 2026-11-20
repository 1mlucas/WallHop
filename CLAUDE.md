# Wall Hop - notes for Claude Code

## Project
One-tap pixel-art mobile game (portrait 720x1280, iOS first) built with Godot 4.x and GDScript.
Tap to hop to the opposite wall (or onto a perch in the middle; double tap for a high hop), dodge saws and spikes, collect fruit. Current version: v0.4.1.

## About the owner
- Not a game developer. QA/automation engineer (Java, Python) who wants Claude to write the code.
- Prefers replies in Vietnamese. Keep explanations short and practical; give exact steps for anything done in Godot's UI or Terminal.
- Wants each milestone pushed to GitHub (commit + tag) as a portfolio showcase.

## Layout
- `scenes/main.tscn` - entry scene, only holds the script
- `scripts/main.gd` - game flow, player, spawning, collisions, UI (everything is built in code)
- `scripts/zones.gd` - zone table (looks, start distance, pattern weights)
- `scripts/hazard.gd` - scrolling hazard/fruit/perch node: motion, hit capsule, fruit clearance
- `scripts/fruit_layout.gd` - fruit placement shapes (scatter, wave, swoop, cluster)
- `scripts/catalog.gd` - characters (shop prices, trail colours) and fruit values
- `scripts/art.gd` - sprite sheet to SpriteFrames helper
- `tests/sim_run.gd` - headless simulation + fairness test (must pass before a PR)
- `tests/run_tests.sh` - runs sim_run.gd; trust this, not the Godot exit code (a parse error still exits 0)
- `docs/GAME_DESIGN.md` - design doc: zones, fairness rules, ideas, roadmap
- `assets/art/` - Pixel Adventure 1 sprites (Pixel Frog, CC0); `assets/art/chars/<id>/` holds one folder per character
- `assets/audio/sfx`, `assets/audio/music` - OGG files (Juhani Junkala, CC0)
- `Licenses/`, `CREDITS.md` - keep updated whenever an asset is added

## Conventions
- GDScript with static typing, tabs for indentation, constants in UPPER_CASE.
- Pixel art: nearest-neighbour filtering (set in project.godot), drawn at 3x scale.
- Comfort first (players reported motion sickness): no screen shake, no background scrolling, nothing flashing faster than 3 times per second, eased motion, and every new moving effect must respect `reduced_motion`. See "Comfort rules" in docs/GAME_DESIGN.md.
- Keep new assets CC0 or paid-with-license only. Avoid CC-BY-SA / CC-BY-ND. Record the source in CREDITS.md.
- Audio is converted to OGG before being added (small iOS build).
- Do not commit: `.godot/`, build output, Apple certificates or provisioning profiles, zip archives.

## Testing without the editor UI
Godot 4.x can run headless, for example:
`godot --headless --path . --quit-after 120`
or with a simulation script: `godot --headless --path . --script path/to/sim.gd`
Always run the project headless and `tests/run_tests.sh` after changing scripts, and tell the owner to press F5 to check visuals and feel.

## Workflow per milestone
Never commit straight to `main`; every change goes through a branch and a Pull Request.
1. Branch from an up-to-date main: `git switch main && git pull && git switch -c feature/vX.Y-short-name`
2. Implement and test (headless run, then the owner checks with F5). Make small, focused commits.
3. Update README.md (status table), CHANGELOG.md (move "Unreleased" into the new version) and CREDITS.md if needed.
4. Push and open a PR: `git push -u origin feature/vX.Y-short-name && gh pr create --base main --title "vX.Y: summary" --body "..."` (the body lists the changes and how they were tested).
5. Merge after the owner reviews: `gh pr merge --merge --delete-branch`
6. Tag on main (annotated, so `--follow-tags` pushes it): `git switch main && git pull && git tag -a vX.Y -m "vX.Y: summary" && git push --follow-tags`
7. Publish the release: `gh release create vX.Y --title "vX.Y - summary" --notes "..."`

## Roadmap
See `docs/GAME_DESIGN.md` for the full roadmap.
- next: v0.4.2-v0.4.5 small releases (bounce-pad and other perches, fruit polish, pause and safe area, audio and settings), then v0.5 fruit bandits (Pixel Adventure 2 enemies)
- later: more hazards, settings, iOS export (Xcode + Apple Developer account), ads/IAP plugins
