# Wall Hop - Game Design

## Vision
A one-tap arcade climber. Each run should feel like a short trip through
**zones**, each with its own look and its own trick, so the player always has
a next goal ("I want to see the Night Tower") on top of their best score.

## Core loop
1. Tap to hop to the opposite wall. The tower scrolls down and speeds up over time.
2. Read the hazards coming from the top and pick the safe wall.
3. Grab fruit for points, on the walls and in random zigzag trails down the middle
   (4-6 fruit, random spacing; hop back and forth to collect them). A fruit streak raises the combo multiplier.
4. Reach the next zone: banner, new background, new hazard.
5. Die, bank the fruit points, buy a new character in the shop, play again.

## Zones (one run passes through them in order)
Distance is measured in meters (60 px = 1 m). Score = meters + fruit points.

| # | Zone | Starts at | New idea | Hazards |
|---|------|-----------|----------|---------|
| 1 | Meadow | 0 m | Learn to hop | Saws, spikes, fruit on walls and in the middle |
| 2 | Saw Mill | 80 m | Hazards that **move** | Saws sliding up and down the wall on a chain; saw zigzags |
| 3 | Hot Forge | 180 m | Hazards that **switch on and off** | Fire jets that flicker before they burn; fire on both walls, taking turns; **fireballs gliding wall to wall** (glow, ember trail, sparks on each wall) |
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
- Fireballs stay inside the shaft and are only ever at one wall at a time.
- Middle fruit is never reachable from a wall, and neighbours in a trail are at least 80 px apart sideways.
- Moving hazards reserve extra space, so the next row never overlaps their path.

## Scoring
- 1 point per meter.
- Fruit: its base value times the combo (x1 to x5). The combo grows by one per
  fruit and resets when a fruit scrolls past without being collected.
- Rarer fruit is worth more:

| Fruit | Points | Spawn weight |
|-------|--------|--------------|
| Apple, Bananas | 5 | 30 |
| Orange, Cherries | 10 | 20 |
| Kiwi, Strawberry | 15 | 12 |
| Pineapple | 25 | 6 |
| Melon | 40 | 3 |

## Screens: icons over text
Title and game over use icons and numbers instead of sentences:
- Title: logo, trophy + best score, one coloured bar per zone (lit up to the furthest zone), pulsing play icon, character picker (locked characters show apple + price), wallet in the corner.
- Game over: big score, trophy + best (or NEW BEST!), zone bars for this run, apple + fruit points earned, pulsing restart icon (tap anywhere to play again), back icon to return to the title and shop.

## Characters and shop
Fruit points from every run are banked into a wallet and spent in the shop on
the title screen (arrows to browse, button to buy). Characters are cosmetic:
same hitbox and speed, so scores stay comparable. Each has its own hop effect:
a spin animation and a trail of afterimages in its colour.

| Character | Price | Trail |
|-----------|-------|-------|
| Ninja Frog | free | green |
| Mask Dude | 500 | orange |
| Pink Man | 1200 | pink |
| Virtual Guy | 2500 | blue |

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
- Missions: "collect 30 fruit", "reach the Hot Forge without missing a fruit".
- Daily tower: a fixed random seed per day, so everyone plays the same layout.
- Zone checkpoints: after reaching a zone 3 times, you may start a run from it.

## Roadmap
| Version | Focus |
|---------|-------|
| v0.2 | Zones 1-5, moving / switching / swinging hazards, fruit combo, landing dust, mute button, headless simulation test |
| v0.3 | Middle fruit trails, bouncing fireballs, corner HUD, fruit values, character shop with hop trails |
| v0.3.x | Pause, fill the iPhone screen (safe area), balance from playtesting |
| v0.4 | Power-ups and missions |
| v0.5 | New zones (Ice Cave, Crusher Hall), settings screen |
| v1.0 | iOS export, TestFlight, App Store |
