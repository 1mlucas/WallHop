extends RefCounted
## Data tables: playable characters (shop) and fruit values.

const Art := preload("res://scripts/art.gd")

## price is in fruit points. trail is the colour of the afterimages while hopping.
const CHARACTERS: Array[Dictionary] = [
	{"id": "ninja_frog", "name": "NINJA FROG", "price": 0, "trail": Color(0.45, 1.0, 0.55)},
	{"id": "mask_dude", "name": "MASK DUDE", "price": 500, "trail": Color(1.0, 0.65, 0.25)},
	{"id": "pink_man", "name": "PINK MAN", "price": 1200, "trail": Color(1.0, 0.5, 0.8)},
	{"id": "virtual_guy", "name": "VIRTUAL GUY", "price": 2500, "trail": Color(0.4, 0.8, 1.0)},
]

## points: base value per fruit (multiplied by the combo). weight: how often it spawns.
## Rarer fruit is worth more.
const FRUITS: Dictionary = {
	"apple": {"points": 5, "weight": 30},
	"bananas": {"points": 5, "weight": 30},
	"orange": {"points": 10, "weight": 20},
	"cherries": {"points": 10, "weight": 20},
	"kiwi": {"points": 15, "weight": 12},
	"strawberry": {"points": 15, "weight": 12},
	"pineapple": {"points": 25, "weight": 6},
	"melon": {"points": 40, "weight": 3},
}


static func character(id: String) -> Dictionary:
	for c: Dictionary in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]


static func character_index(id: String) -> int:
	for i in CHARACTERS.size():
		if CHARACTERS[i]["id"] == id:
			return i
	return 0


static func character_frames(id: String) -> SpriteFrames:
	var dir := "res://assets/art/chars/%s/" % id
	return Art.build({
		"wall": {"path": dir + "wall.png", "w": 32, "h": 32, "fps": 10.0},
		"jump": {"path": dir + "jump.png", "w": 32, "h": 32, "fps": 20.0},
		"fall": {"path": dir + "fall.png", "w": 32, "h": 32, "fps": 20.0},
		"spin": {"path": dir + "spin.png", "w": 32, "h": 32, "fps": 22.0},
		"idle": {"path": dir + "idle.png", "w": 32, "h": 32, "fps": 20.0},
		"hit": {"path": dir + "hit.png", "w": 32, "h": 32, "fps": 20.0, "loop": false},
	})


## Picks a fruit name using the spawn weights.
static func pick_fruit() -> String:
	var total := 0
	for k: String in FRUITS:
		total += int(FRUITS[k]["weight"])
	var roll := randi() % total
	for k: String in FRUITS:
		roll -= int(FRUITS[k]["weight"])
		if roll < 0:
			return k
	return FRUITS.keys()[0]
