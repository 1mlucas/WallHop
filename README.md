# Wall Hop

A one-tap pixel-art arcade game for iOS, built with **Godot 4** (GDScript).

Tap to hop to the opposite wall. Climb through five zones, dodge saws, spikes, fire and swinging spiked balls, chain fruit combos, beat your best score.

## Status

| Version | What's in it |
|---------|--------------|
| v0.1 | Playable core: wall hop, saws, spikes, fruit, score, best score, game over and retry, music and SFX |
| v0.2 | Five zones (Meadow, Saw Mill, Hot Forge, Sky Garden, Night Tower) with sliding saws, fire jets, swinging spiked balls; fruit combo; landing dust; mute button; headless simulation test |
| v0.3 | Icon-based title and game over screens, continue after game over (paid with fruit points), random fruit trails down the middle, smooth fireballs with glow and ember trail, score in the corner, fruit worth different points, character shop (4 characters, each with its own hop trail) |

Planned: pause, full-screen iPhone layout, power-ups, missions, more zones, iOS release. See [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md).

## Run it

1. Install Godot 4.x (Standard, GDScript): <https://godotengine.org/download>
2. Godot Project Manager -> **Import** -> select `project.godot`
3. Open the project once (Godot imports the assets), then press **F5**

Desktop controls: click or press Space, M toggles sound, Left/Right browse characters and B buys on the title screen; after a game over, C continues and Esc goes back to the title. On a phone: tap anywhere; the speaker icon top-right mutes.

## Test it

A headless simulation plays several long runs and checks the fairness rules (for example, both walls are never deadly at the same time):

```
godot --headless --path . --script tests/sim_run.gd
```

Exit code 0 means pass.

## Project layout

```
scenes/main.tscn     entry scene (just holds the script)
scripts/main.gd      game flow, player, spawning, collisions, UI
scripts/zones.gd     zone table: names, looks, hazard pattern weights
scripts/hazard.gd    scrolling hazard / fruit with motion and hit shape
scripts/catalog.gd   characters (prices, trail colours) and fruit values
scripts/art.gd       sprite-sheet to SpriteFrames helper
tests/sim_run.gd     headless simulation and fairness test
docs/GAME_DESIGN.md  zones, rules, ideas and roadmap
assets/art/          Pixel Adventure 1 sprites
assets/audio/        OGG music and sound effects
Licenses/            license info for third-party assets
```

## Credits

See [CREDITS.md](CREDITS.md).
