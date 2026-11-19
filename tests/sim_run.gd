extends SceneTree
## Headless simulation test. Plays several long god-mode runs with a random tapper
## and checks the fairness rules from docs/GAME_DESIGN.md.
## Run: godot --headless --path . --script tests/sim_run.gd
## Exit code 0 = pass, 1 = fail.

const Zones := preload("res://scripts/zones.gd")
const Hazard := preload("res://scripts/hazard.gd")
const Catalog := preload("res://scripts/catalog.gd")

const DT := 1.0 / 60.0
const RUNS := 3
const RUN_SECONDS := 150.0
const STEPS_PER_FRAME := 20

var failures: Array[String] = []
var main: Node2D
var run := 0
var step := 0
var tap_timer := 0.0
var zones_seen := {}
var kinds_seen := {}
var motions_seen := {}
var unfair_frames := 0
var ball_on_wall_frames := 0
var fireball_out_frames := 0
var center_fruit_ids := {}


func _initialize() -> void:
	_test_zone_table()
	_test_catalog()


func _process(_delta: float) -> bool:
	if main == null:
		_start_run() # scenes are only ready once the tree is running
		return false
	for i in STEPS_PER_FRAME:
		_step()
		if step >= int(RUN_SECONDS / DT):
			_end_run()
			run += 1
			if run >= RUNS:
				return _finish()
			_start_run()
			return false
	return false


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


# ---------------------------------------------------------------- unit checks

func _test_zone_table() -> void:
	_check(Zones.index_at(0.0) == 0, "index_at(0) should be zone 0")
	var last_start := -1
	for i in Zones.LIST.size():
		var start := int(Zones.LIST[i]["start_m"])
		_check(start > last_start, "zone %d must start after zone %d" % [i, i - 1])
		_check(Zones.index_at(float(start)) == i, "index_at(%d) should be zone %d" % [start, i])
		if start > 0:
			_check(Zones.index_at(start - 0.1) == i - 1, "just before zone %d should still be zone %d" % [i, i - 1])
		last_start = start
		var weights: Dictionary = Zones.LIST[i]["patterns"]
		for _n in 300:
			var p := Zones.pick_pattern(i)
			_check(weights.has(p), "zone %d picked unknown pattern %s" % [i, p])
	_check(Zones.index_at(100000.0) == Zones.LIST.size() - 1, "far distance should be the last zone")


func _test_catalog() -> void:
	var chars := Catalog.CHARACTERS
	_check(int(chars[0]["price"]) == 0, "first character must be free")
	for i in chars.size():
		var id: String = chars[i]["id"]
		if i > 0:
			_check(int(chars[i]["price"]) > int(chars[i - 1]["price"]), "%s should cost more than the previous one" % id)
		for anim: String in ["wall", "jump", "fall", "spin", "idle", "hit"]:
			var path := "res://assets/art/chars/%s/%s.png" % [id, anim]
			_check(ResourceLoader.exists(path), "missing sprite " + path)
	# Rarer fruit is worth more: sorted by points, weights never go up.
	var fruits: Array = Catalog.FRUITS.keys()
	fruits.sort_custom(func(a: String, b: String) -> bool:
		return int(Catalog.FRUITS[a]["points"]) < int(Catalog.FRUITS[b]["points"]))
	for i in range(1, fruits.size()):
		var lo: Dictionary = Catalog.FRUITS[fruits[i - 1]]
		var hi: Dictionary = Catalog.FRUITS[fruits[i]]
		_check(int(hi["weight"]) <= int(lo["weight"]), "%s is worth more than %s but spawns more often" % [fruits[i], fruits[i - 1]])
	var seen := {}
	for _n in 2000:
		seen[Catalog.pick_fruit()] = true
	_check(seen.size() == Catalog.FRUITS.size(), "pick_fruit never picked some fruit: %s" % str(seen.keys()))


## Shop rules, run once on a fresh main scene (god_mode: nothing is saved).
func _test_shop() -> void:
	var id: String = Catalog.CHARACTERS[1]["id"]
	var price := int(Catalog.CHARACTERS[1]["price"])
	main.set("owned", ["ninja_frog"] as Array[String])
	main.set("wallet", price - 1)
	_check(not main.call("try_buy", id), "buying with too few points must fail")
	_check(int(main.get("wallet")) == price - 1, "failed buy must not change the wallet")
	main.set("wallet", price + 7)
	_check(main.call("try_buy", id), "buying with enough points must work")
	_check(int(main.get("wallet")) == 7, "buy must take exactly the price")
	_check((main.get("owned") as Array).has(id), "bought character must be owned")
	_check(main.get("selected") == id, "bought character must be selected")
	_check(not main.call("try_buy", id), "buying an owned character must fail")
	_check(int(main.get("wallet")) == 7, "second buy must not take points")
	main.set("wallet", 0)
	main.call("_select_character", "ninja_frog")


## Random middle fruit trails: inside the lane, out of reach from the walls,
## neighbours spread apart, and not the same layout every time.
func _test_fruit_trail() -> void:
	var world: Node2D = main.get("world")
	var reach: float = 34.0 + main.PLAYER_R
	var xs_seen := {}
	for t in 200:
		for c in world.get_children():
			world.remove_child(c)
			c.free()
		main.call("_spawn_pattern", "fruit_trail", -100.0)
		var fruit: Array[Hazard] = []
		for c in world.get_children():
			fruit.append(c as Hazard)
		_check(fruit.size() >= 4 and fruit.size() <= 6, "trail should have 4-6 fruit, got %d" % fruit.size())
		for i in fruit.size():
			var x := fruit[i].position.x
			xs_seen[int(x / 20.0)] = true
			_check(x - main.CLING_L > reach and main.CLING_R - x > reach, "trail fruit at x=%.0f can be eaten from a wall" % x)
			if i > 0:
				var dx := absf(x - fruit[i - 1].position.x)
				var dy := fruit[i - 1].position.y - fruit[i].position.y
				_check(dx >= main.TRAIL_MIN_STEP_X - 0.01, "trail neighbours only %.0f px apart" % dx)
				_check(dy >= 120.0 and dy <= 220.0, "trail vertical gap %.0f out of range" % dy)
	_check(xs_seen.size() >= 10, "trail x positions look fixed, only %d buckets used" % xs_seen.size())
	for c in world.get_children():
		world.remove_child(c)
		c.free()


## Continue after game over: price per use, limit, wallet, no double banking, protection.
func _test_continue() -> void:
	main.set("save_enabled", false)
	main.set("god_mode", false)
	main.call("_start_game")
	var costs: Array[int] = main.CONTINUE_COSTS
	main.set("wallet", 0)
	main.set("fruit_points", 50)
	main.call("_die")
	_check(int(main.get("wallet")) == 50, "dying should bank the run's fruit points")
	_check(int(main.call("continue_cost")) == costs[0], "first continue should cost %d" % costs[0])
	_check(not main.call("try_continue"), "continue without enough points must fail")
	_check(int(main.get("mode")) == main.Mode.DEAD, "failed continue must keep the game over")

	main.set("wallet", costs[0] + 20)
	_check(main.call("try_continue"), "continue with enough points must work")
	_check(int(main.get("wallet")) == 20, "continue must take exactly its price")
	_check(int(main.get("mode")) == main.Mode.PLAY, "continue must resume the run")
	_check(float(main.get("invuln")) > 0.0, "continue must give a short protection")
	var world: Node2D = main.get("world")
	for c in world.get_children():
		_check(c.is_queued_for_deletion(), "continue must clear the hazards on screen")
		break

	main.set("fruit_points", 80)
	main.call("_die")
	_check(int(main.get("wallet")) == 50, "second death must bank only the new 30 points, wallet is %d" % int(main.get("wallet")))
	_check(int(main.call("continue_cost")) == costs[1], "second continue should cost %d" % costs[1])
	main.set("wallet", costs[1])
	_check(main.call("try_continue"), "second continue must work")
	main.call("_update_invuln", 10.0)
	_check(float(main.get("invuln")) == 0.0 and (main.get("player") as Node2D).modulate.a == 1.0, "protection must end and the player stop blinking")

	main.call("_die")
	_check(int(main.call("continue_cost")) == -1, "no continue after the limit")
	main.set("wallet", 99999)
	_check(not main.call("try_continue"), "continue past the limit must fail")

	main.call("_start_game")
	_check(int(main.get("continues_used")) == 0 and int(main.get("banked")) == 0, "a new run must reset continues")
	main.set("wallet", 0)
	main.set("god_mode", true)
	main.call("_show_title")


# ---------------------------------------------------------------- simulation

func _start_run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("god_mode", true)
	if run == 0:
		_test_shop()
		_test_fruit_trail()
		_test_continue()
	seed(1000 + run)
	main.call("_on_tap") # start the game
	step = 0
	tap_timer = 0.0
	zones_seen = {}
	kinds_seen = {}
	motions_seen = {}
	unfair_frames = 0
	ball_on_wall_frames = 0
	fireball_out_frames = 0
	center_fruit_ids = {}


func _step() -> void:
	main.call("_process", DT)
	step += 1
	tap_timer -= DT
	if tap_timer <= 0.0:
		main.call("_on_tap")
		tap_timer = randf_range(0.25, 1.2)

	zones_seen[main.get("zone")] = true
	var walls: Array[bool] = main.call("deadly_walls")
	if walls[0] and walls[1]:
		unfair_frames += 1

	var world: Node2D = main.get("world")
	for c in world.get_children():
		var h := c as Hazard
		if h.is_queued_for_deletion():
			continue
		kinds_seen[h.kind] = true
		motions_seen[h.motion] = true
		if h.kind == "ball":
			var on_l := h.touches(Vector2(main.CLING_L, main.PLAYER_Y), main.PLAYER_R)
			var on_r := h.touches(Vector2(main.CLING_R, main.PLAYER_Y), main.PLAYER_R)
			if on_l or on_r:
				ball_on_wall_frames += 1
		elif h.kind == "fireball":
			var x := h.hit_center().x
			if x < main.WALL_W or x > main.W - main.WALL_W:
				fireball_out_frames += 1
		elif h.kind == "fruit" and absf(h.position.x - main.W * 0.5) < 100.0:
			center_fruit_ids[h.get_instance_id()] = true


func _end_run() -> void:
	var meters: float = main.call("meters")
	var center_fruit := center_fruit_ids.size()
	print("run %d: %.0f m, zones %s, kinds %s, center fruit %d, bot hits %d" % [
		run, meters, str(zones_seen.keys()), str(kinds_seen.keys()), center_fruit, int(main.get("god_hits"))])
	_check(zones_seen.size() == Zones.LIST.size(), "run %d reached only zones %s" % [run, str(zones_seen.keys())])
	for k: String in ["saw", "spike", "fire", "ball", "fruit", "fireball"]:
		_check(kinds_seen.has(k), "run %d never spawned %s" % [run, k])
	for m: int in [Hazard.Motion.SLIDE, Hazard.Motion.SWING, Hazard.Motion.FIRE, Hazard.Motion.SHOOT]:
		_check(motions_seen.has(m), "run %d never used motion %d" % [run, m])
	_check(unfair_frames == 0, "run %d: both walls deadly at once in %d frames" % [run, unfair_frames])
	_check(fireball_out_frames == 0, "run %d: fireball left the shaft in %d frames" % [run, fireball_out_frames])
	_check(center_fruit >= 20, "run %d: only %d fruit spawned in the middle" % [run, center_fruit])
	_check(ball_on_wall_frames == 0, "run %d: swinging ball reached a wall in %d frames" % [run, ball_on_wall_frames])
	main.free()


func _finish() -> bool:
	if failures.is_empty():
		print("PASS: %d runs x %.0f s" % [RUNS, RUN_SECONDS])
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		quit(1)
	return true
