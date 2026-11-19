# Wall Hop - notes for Claude Code

## Project
One-tap pixel-art mobile game (portrait 720x1280, iOS first) built with Godot 4.x and GDScript.
Tap to hop to the opposite wall, dodge saws and spikes, collect fruit. Current version: v0.1.

## About the owner
- Not a game developer. QA/automation engineer (Java, Python) who wants Claude to write the code.
- Prefers replies in Vietnamese. Keep explanations short and practical; give exact steps for anything done in Godot's UI or Terminal.
- Wants each milestone pushed to GitHub (commit + tag) as a portfolio showcase.

## Layout
- `scenes/main.tscn` - entry scene, only holds the script
- `scripts/main.gd` - game flow, player, spawning, collisions, UI (everything is built in code)
- `scripts/art.gd` - sprite sheet to SpriteFrames helper
- `assets/art/` - Pixel Adventure 1 sprites (Pixel Frog, CC0)
- `assets/audio/sfx`, `assets/audio/music` - OGG files (Juhani Junkala, CC0)
- `Licenses/`, `CREDITS.md` - keep updated whenever an asset is added

## Conventions
- GDScript with static typing, tabs for indentation, constants in UPPER_CASE.
- Pixel art: nearest-neighbour filtering (set in project.godot), drawn at 3x scale.
- Keep new assets CC0 or paid-with-license only. Avoid CC-BY-SA / CC-BY-ND. Record the source in CREDITS.md.
- Audio is converted to OGG before being added (small iOS build).
- Do not commit: `.godot/`, build output, Apple certificates or provisioning profiles, zip archives.

## Testing without the editor UI
Godot 4.x can run headless, for example:
`godot --headless --path . --quit-after 120`
or with a simulation script: `godot --headless --path . --script path/to/sim.gd`
Always run the project headless after changing scripts, and tell the owner to press F5 to check visuals and feel.

## Workflow per milestone
1. Implement and test.
2. Update README.md (status table) and CREDITS.md if needed.
3. `git add . && git commit -m "vX.Y: summary" && git tag vX.Y && git push --follow-tags`

## Roadmap
- v0.2: balance and feel tweaks from playtesting, dust and pop effects, character select, mute button
- later: more hazards, settings, iOS export (Xcode + Apple Developer account), ads/IAP plugins
