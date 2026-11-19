extends SceneTree
## Headless simulation test. Plays several long god-mode runs with a random tapper
## and checks the fairness rules from docs/GAME_DESIGN.md.
## Run: godot --headless --path . --script tests/sim_run.gd
## Exit code 0 = pass, 1 = fail.

const Zones := preload("res://scripts/zones.gd")
const Hazard := preload("res://scripts/hazard.gd")

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


func _initialize() -> void:
	_test_zone_table()


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


# ---------------------------------------------------------------- simulation

func _start_run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set("god_mode", true)
	seed(1000 + run)
	main.call("_on_tap") # start the game
	step = 0
	tap_timer = 0.0
	zones_seen = {}
	kinds_seen = {}
	motions_seen = {}
	unfair_frames = 0
	ball_on_wall_frames = 0


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


func _end_run() -> void:
	var meters: float = main.call("meters")
	print("run %d: %.0f m, zones %s, kinds %s, bot hits %d" % [
		run, meters, str(zones_seen.keys()), str(kinds_seen.keys()), int(main.get("god_hits"))])
	_check(zones_seen.size() == Zones.LIST.size(), "run %d reached only zones %s" % [run, str(zones_seen.keys())])
	for k: String in ["saw", "spike", "fire", "ball", "fruit"]:
		_check(kinds_seen.has(k), "run %d never spawned %s" % [run, k])
	for m: int in [Hazard.Motion.SLIDE, Hazard.Motion.SWING, Hazard.Motion.FIRE]:
		_check(motions_seen.has(m), "run %d never used motion %d" % [run, m])
	_check(unfair_frames == 0, "run %d: both walls deadly at once in %d frames" % [run, unfair_frames])
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
