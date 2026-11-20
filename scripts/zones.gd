extends RefCounted
## Zone table. A run passes through these in order; the last one is endless.
## "patterns" maps a spawn pattern name (see main.gd _spawn_pattern) to its weight.

const METERS_PX := 60.0

const LIST: Array[Dictionary] = [
	{
		"name": "MEADOW",
		"start_m": 0,
		"bg": "res://assets/art/bg_blue.png",
		"bg_tint": Color(1, 1, 1),
		"color": Color(0.45, 0.75, 1.0), # zone dot on title / game over
		"wall_tint": Color(1, 1, 1),
		"patterns": {"saw": 3, "spikes": 3, "fruit": 2, "fruit_trail": 2, "fruit_wave": 1, "fruit_swoop": 1, "perch": 1, "perch_slide": 2, "perch_sink": 1},
	},
	{
		"name": "SAW MILL",
		"start_m": 80,
		"bg": "res://assets/art/bg_green.png",
		"bg_tint": Color(1, 1, 1),
		"color": Color(0.45, 0.85, 0.4), # zone dot on title / game over
		"wall_tint": Color(0.85, 0.95, 0.85),
		"patterns": {"saw": 2, "spikes": 1, "fruit": 1, "fruit_trail": 1, "fruit_wave": 1, "fruit_swoop": 1, "saw_slide": 4, "zigzag": 2, "perch_saws": 2, "perch_slide": 2, "perch_sink": 1, "perch_lift": 1},
	},
	{
		"name": "HOT FORGE",
		"start_m": 180,
		"bg": "res://assets/art/bg_brown.png",
		"bg_tint": Color(1, 0.9, 0.85),
		"color": Color(1.0, 0.5, 0.2), # zone dot on title / game over
		"wall_tint": Color(1, 0.8, 0.7),
		"patterns": {"spikes": 1, "fruit": 1, "fruit_trail": 1, "fruit_swoop": 1, "saw_slide": 1, "fire": 2, "fire_dual": 2, "fireball": 4, "perch_saws": 1, "perch_slide": 1, "perch_sink": 1, "perch_lift": 1},
	},
	{
		"name": "SKY GARDEN",
		"start_m": 300,
		"bg": "res://assets/art/bg_purple.png",
		"bg_tint": Color(1, 1, 1),
		"color": Color(0.75, 0.5, 1.0), # zone dot on title / game over
		"wall_tint": Color(0.9, 0.85, 1),
		"patterns": {"saw": 1, "fruit_trail": 1, "fruit_wave": 1, "fruit_swoop": 1, "zigzag": 2, "saw_slide": 1, "ball": 4, "sky_fruit": 1, "fireball": 2, "perch_saws": 1, "perch_slide": 1, "perch_sink": 1, "perch_lift": 2},
	},
	{
		"name": "NIGHT TOWER",
		"start_m": 450,
		"bg": "res://assets/art/bg_gray.png",
		"bg_tint": Color(0.55, 0.6, 0.8),
		"color": Color(0.45, 0.5, 0.85), # zone dot on title / game over
		"wall_tint": Color(0.6, 0.65, 0.85),
		"patterns": {"saw": 1, "spikes": 1, "fruit": 1, "saw_slide": 2, "zigzag": 2, "fire": 1, "fire_dual": 2, "ball": 2, "sky_fruit": 1, "fruit_trail": 1, "fruit_wave": 1, "fruit_swoop": 1, "fireball": 3, "perch_saws": 1, "perch_slide": 1, "perch_sink": 1, "perch_lift": 1},
	},
]


## Index of the zone for a distance in meters.
static func index_at(meters: float) -> int:
	var idx := 0
	for i in LIST.size():
		if meters >= float(LIST[i]["start_m"]):
			idx = i
	return idx


## Picks a pattern name using the zone's weights.
static func pick_pattern(zone: int) -> String:
	var weights: Dictionary = LIST[zone]["patterns"]
	var total := 0
	for k: String in weights:
		total += int(weights[k])
	var roll := randi() % total
	for k: String in weights:
		roll -= int(weights[k])
		if roll < 0:
			return k
	return weights.keys()[0]
