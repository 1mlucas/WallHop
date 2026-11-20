# Wall Hop - Game Design

## Vision
A one-tap arcade climber. Each run should feel like a short trip through
**zones**, each with its own look and its own trick, so the player always has
a next goal ("I want to see the Night Tower") on top of their best score.

## Core loop
1. Tap to hop to the opposite wall. The tower scrolls down and speeds up over time.
2. Read the hazards coming from the top and pick the safe wall.
3. Grab fruit for points, on the walls and in natural-looking layouts down the
   middle (see Fruit layouts). Each fruit has its own fixed value.
4. Land on **perches** (hovering lifts) in the middle to break up the wall-to-wall
   rhythm: rest, eat the fruit above, wait for saws to pass, then hop on.
5. Reach the next zone: banner, new background, new hazard.
6. Die, bank the fruit points, then choose: continue (pay fruit points), restart,
   or go back to the title to buy a new character.

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

## Perches (v0.4)
Hovering lifts (Pixel Adventure 1 "Falling Platform") in the middle of the shaft.
- A hop from a wall stops on a perch when one is in reach (it shines a little
  brighter). Otherwise the hop goes to the other wall as usual.
- On a perch the player stands still; the perch hovers under them while the world
  scrolls. Fruit above it falls straight into the player's hands.
- The next tap hops on to the wall the player was heading for (half a hop, 0.28 s).
- A perch carries the player for 2 s. In the last 0.8 s its propeller stops and it
  slowly warms to orange (no blinking); then the player hops on by itself.
- Used perches drop away (only fade out with reduced motion). Perches are at least
  1300 px of climb apart, so two of them never stack up.
- Patterns: `perch` (lift + small fruit column above), `perch_saws` (saws on both
  walls one after the other: wait on the lift until they pass).
- **Moving perches**: `perch_slide` glides 110 px left and right of the middle,
  `perch_lift` rises and sinks 90 px (an elevator), `perch_sink` carries the rider
  down the screen at 80 px/s (hop off before it gets low). Glides use a slow sine
  (3.0-3.6 s per cycle: slow at the ends, no sudden turns). The hop follows the
  plank wherever it is, the rider moves with it, and the hop off always ends on a
  wall at the usual height. Reduced motion halves the glide and slows the sink.

| Zone | Perch types |
|------|-------------|
| Meadow | still, sliding, sinking |
| Saw Mill onwards | with saws, sliding, sinking, elevator |

### Perch feedback (v0.4.1)
- **Landing arrow**: while the player holds a wall and a perch is in reach, a small
  still arrow sits on the plank, showing where the next hop lands. (v0.4.1 showed a
  faint copy of the character there; players read it as a second character.)
- **Timer dots**: three small dots under the propeller; one goes out per third of
  the hold, and they turn orange in the last 0.8 s. Only 3 changes, no blinking.
- **Landing press**: the plank dips about 8 px and springs back (off with reduced motion).
- **Sounds**: a soft thud on landing, a falling tone when the propeller stops.
- **Per zone**: hold time and how far up a hop still reaches a perch.

| Zone | Hold | Reach |
|------|------|-------|
| Meadow | 2.5 s | 260 px |
| Saw Mill | 2.0 s | 220 px |
| Hot Forge | 2.0 s | 220 px |
| Sky Garden | 1.8 s | 220 px |
| Night Tower | 1.5 s | 200 px |

## Double tap: high hop (v0.4.1)
A single tap still hops at once (no waiting to see if a second tap comes).
- A **second tap in the first 65% of a hop** turns it into a high hop: the hop
  restarts from where the player is, rises 190 px (140 with reduced motion) and
  takes 0.46 s more, eased like any hop. Once per hop.
- A later second tap queues the next hop, as before.
- Uses: land later so a saw on the target wall can pass first; reach a perch up to
  150 px further up; shoot up through a **fruit tower** (4 fruit stacked in the
  middle). A plain hop gets at most 2 of the tower, a double tap in the middle all 4.
- Never required: every pattern can be survived with single taps.

## Fruit layouts (v0.4, `scripts/fruit_layout.gd`)
Fruit should look hand-placed but differ every run:
- **Scatter** (`fruit_trail`): random walk up the middle, each fruit 120-220 px higher
  and at least 80 px to the side of the previous one.
- **Wave** (`fruit_wave`): a gentle sine snake with random phase, bend and width, plus
  a little jitter.
- **Swoop** (`fruit_swoop`): a diagonal ribbon along the path of one hop; one hop at
  the right moment eats all of it.
- **Cluster** (`sky_fruit`): a sunflower (golden-angle) spiral, evenly spread, never in rows.
- **Clearance**: a fruit is dropped if it would sit anywhere a hazard can reach (its
  whole swing or slide range), so no fruit is a trap.
- **Shuffle bag** for fruit types: each bag of 40 holds every fruit `weight` times,
  so rare fruit comes regularly and there are no long streaks.

## Comfort rules (checked by `tests/sim_run.gd`)
Playtesters reported dizziness, headaches, eye strain and nausea after long
sessions. These rules apply to every new feature:
- **No screen shake.** The camera never moves on its own.
- **Still background.** Only the walls scroll; the background never drifts.
- **Calm walls.** Bricks are drawn larger (64 px) under a still, semi-transparent
  haze that lowers their contrast.
- **Short, eased hops.** 360 px between the walls, 0.36 s, smoothstep easing
  (slow start, slow stop).
- **Top scroll speed 420 px/s.**
- **No hard blinking.** Anything that flashes stays at or below 3 dips per
  second (the protection after a continue is a soft 1.5 Hz fade).
- **Calm UI.** Tap icons breathe slowly (0.9 s, 6%) instead of pulsing.
- **Reduced motion** option (gear icon on the title screen, or R): no
  afterimages, no embers or sparks, still icons. Saved between sessions.
- **Break reminder.** After 15 minutes of play, the game over screen shows
  "TAKE A BREAK".

## Fairness rules (checked by `tests/sim_run.gd`)
- Both walls are never deadly at the player's height at the same moment.
  The player can always survive by being on the right wall.
- Fire jets always warn (flicker) for longer than a hop takes (0.45 s vs 0.36 s).
- Two fires on opposite walls never burn at the same time.
- Swinging balls never reach a player who is holding a wall.
- Fireballs stay inside the shaft and are only ever at one wall at a time.
- Middle fruit is never reachable from a wall, and neighbours in a trail are at least 80 px apart sideways.
- Moving hazards reserve extra space, so the next row never overlaps their path.
- Fruit never spawns inside a hazard's reach (fire on the same wall is the one
  deliberate exception: it is only deadly while burning).
- Two perches never stack up, even at top speed with the player riding one to the end.

## Scoring
- 1 point per meter.
- Fruit: a fixed value per fruit, no multiplier (v0.4 removed the combo).
- Rarer fruit is worth more (weight = copies in a bag of 40):

| Fruit | Points | Weight |
|-------|--------|--------|
| Apple | 5 | 9 |
| Bananas | 8 | 8 |
| Orange | 10 | 7 |
| Cherries | 12 | 6 |
| Kiwi | 15 | 4 |
| Strawberry | 20 | 3 |
| Pineapple | 30 | 2 |
| Melon | 50 | 1 |

## Screens: icons over text
Title and game over use icons and numbers instead of sentences:
- Title: logo, trophy + best score, one coloured bar per zone (lit up to the furthest zone), pulsing play icon, character picker (locked characters show apple + price), wallet in the corner.
- Game over: big score, trophy + best (or NEW BEST!), zone bars for this run, apple + fruit points earned, restart icon and continue icon (with its price), back icon to return to the title and shop.

## Continue
After a game over the player can continue the same run instead of restarting:
- Paid with fruit points: 100 for the first continue, 250 for the second; at most 2 per run, so best scores still mean something.
- The run keeps its score, zone and distance. Hazards on screen are cleared, the next ones come after a breather, and the player is protected (blinking) for 1.5 s.
- Fruit points are banked at every death, but only the part not banked before (no double counting).
- Later: "watch an ad to continue" once ads are added.

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
| v0.3.1 | Comfort pass against motion sickness and eye strain (see Comfort rules) |
| v0.4 | Perches in the middle (still, sliding, sinking, elevator), natural fruit layouts, fixed fruit values (no combo) |
| v0.4.1 | Double tap high hop, fruit towers, perch landing ghost, timer dots, landing press, sounds, hold time per zone |
| next | Fruit bandits (Pixel Adventure 2 enemies), double tap for a higher hop, pause, safe area |
| later | Power-ups and missions, new zones (Ice Cave, Crusher Hall), settings screen |
| v1.0 | iOS export, TestFlight, App Store |
