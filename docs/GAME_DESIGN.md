# Wall Hop - Game Design

## Vision
A one-tap arcade climber. Each run should feel like a short trip through
**zones**, each with its own look and its own trick, so the player always has
a next goal ("I want to see the Night Tower") on top of their best score.

## Core loop
1. Tap to hop to the opposite wall. The tower scrolls down and speeds up over time.
2. Read the hazards coming from the top and pick the safe wall.
3. Grab fruit for bonus points. A fruit streak raises the combo multiplier.
4. Reach the next zone: banner, new background, new hazard.
5. Die, see your score and the furthest zone you reached, retry right away.

## Zones (one run passes through them in order)
Distance is measured in meters (60 px = 1 m). Score = meters + fruit points.

| # | Zone | Starts at | New idea | Hazards |
|---|------|-----------|----------|---------|
| 1 | Meadow | 0 m | Learn to hop | Saws, spikes, fruit |
| 2 | Saw Mill | 80 m | Hazards that **move** | Saws sliding up and down the wall on a chain; saw zigzags |
| 3 | Hot Forge | 180 m | Hazards that **switch on and off** | Fire jets that flicker before they burn; fire on both walls, taking turns |
| 4 | Sky Garden | 300 m | Danger **in the middle** | Spiked balls swinging between the walls; fruit you can only grab mid-jump |
| 5 | Night Tower | 450 m | Everything at once | A mix of all hazards; endless |

Each zone change gives a breather (no hazards for a moment), a banner with the
zone name and a background crossfade.

## Fairness rules (checked by `tests/sim_run.gd`)
- Both walls are never deadly at the player's height at the same moment.
  The player can always survive by being on the right wall.
- Fire jets always warn (flicker) for longer than a hop takes (0.35 s vs 0.28 s).
- Two fires on opposite walls never burn at the same time.
- Swinging balls never reach a player who is holding a wall.
- Moving hazards reserve extra space, so the next row never overlaps their path.

## Scoring
- 1 point per meter.
- Fruit: 5 points times the combo (x1 to x5). The combo grows by one per fruit
  and resets when a fruit scrolls past without being collected.

## Ideas for later versions
Ideas that use sprites already in Pixel Adventure 1 (CC0):

**More zones**
- Ice Cave: icy wall patches where the frog slides down a little before it can hop.
- Crusher Hall: Rock Head blocks slam across the shaft on a rhythm.
- Wind Tunnel: fans push the frog sideways mid-hop, curving the jump.
- Falling Bridge: platforms in the middle that drop when touched; bounce off trampolines.

**Power-ups** (from item boxes you break by hopping into them)
- Shield: survive one hit.
- Magnet: pulls nearby fruit.
- Slow-mo: three seconds at reduced speed.

**Meta progression**
- Characters: Ninja Frog, Mask Dude, Pink Man, Virtual Guy, unlocked with fruit.
- Missions: "collect 30 fruit", "reach the Hot Forge without missing a fruit".
- Daily tower: a fixed random seed per day, so everyone plays the same layout.
- Zone checkpoints: after reaching a zone 3 times, you may start a run from it.

## Roadmap
| Version | Focus |
|---------|-------|
| v0.2 | Zones 1-5, moving / switching / swinging hazards, fruit combo, landing dust, mute button, headless simulation test |
| v0.3 | Character select, balance from playtesting, pause |
| v0.4 | Power-ups and missions |
| v0.5 | New zones (Ice Cave, Crusher Hall), settings screen |
| v1.0 | iOS export, TestFlight, App Store |
