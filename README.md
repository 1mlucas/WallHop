# Wall Hop

A one-tap pixel-art arcade game for iOS, built with **Godot 4** (GDScript).

Tap to hop to the opposite wall. Dodge saws and spikes, grab fruit, beat your best score.

## Status

| Version | What's in it |
|---------|--------------|
| v0.1 | Playable core: wall hop, saws, spikes, fruit, score, best score, game over and retry, music and SFX |

Planned: menu polish, more hazards, skins, settings, iOS release.

## Run it

1. Install Godot 4.x (Standard, GDScript): <https://godotengine.org/download>
2. Godot Project Manager -> **Import** -> select `project.godot`
3. Open the project once (Godot imports the assets), then press **F5**

Desktop controls: click or press Space. On a phone: tap anywhere.

## Project layout

```
scenes/main.tscn     entry scene (just holds the script)
scripts/main.gd      game flow, player, spawning, collisions, UI
scripts/art.gd       sprite-sheet to SpriteFrames helper
assets/art/          Pixel Adventure 1 sprites
assets/audio/        OGG music and sound effects
Licenses/            license info for third-party assets
```

## Credits

See [CREDITS.md](CREDITS.md).
