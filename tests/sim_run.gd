extends SceneTree
## Headless simulation test. Plays several long god-mode runs with a random tapper
## and checks the fairness rules from docs/GAME_DESIGN.md.
## Run: godot --headless --path . --script tests/sim_run.gd
## Exit code 0 = pass, 1 = fail.

const Zones := preload("res://scripts/zones.gd")
const Hazard := preload("res://scripts/hazard.gd")
const Catalog := preload("res://scripts/catalog.gd")
const FruitLayout := preload("res://scripts/fruit_layout.gd")

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
var shake_frames := 0
var bg_moved_frames := 0
var center_fruit_ids := {}
var fruit_checked := {}
var trapped_fruit := 0
var stacked_perch_frames := 0


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

	# v0.4 table: every fruit has its own fixed value.
	var points: Array[int] = []
	for f: String in fruits:
		points.append(int(Catalog.FRUITS[f]["points"]))
	_check(points == [5, 8, 10, 12, 15, 20, 30, 50], "fruit points should be 5/8/10/12/15/20/30/50, got %s" % str(points))

	# Shuffle bag: one full bag holds each fruit exactly `weight` times.
	for bag in 3:
		Catalog.reset_bag()
		var counts := {}
		for _n in Catalog.bag_size():
			var f := Catalog.pick_fruit()
			counts[f] = int(counts.get(f, 0)) + 1
		for f: String in Catalog.FRUITS:
			_check(int(counts.get(f, 0)) == int(Catalog.FRUITS[f]["weight"]),
				"bag gave %s %d times, expected %d" % [f, int(counts.get(f, 0)), int(Catalog.FRUITS[f]["weight"])])

	_test_layouts()


## Pure layout shapes: inside their area, spread out, different every time.
func _test_layouts() -> void:
	var shapes := {}
	for t in 200:
		var w := FruitLayout.wave(6, 360.0, 110.0, 0.0, 120.0, 250.0, 470.0)
		shapes[int(w[1].x / 10.0)] = true
		for i in w.size():
			_check(w[i].x >= 250.0 and w[i].x <= 470.0, "wave fruit outside the lane at x=%.0f" % w[i].x)
			if i > 0:
				_check(w[i - 1].distance_to(w[i]) >= 95.0, "wave fruit too close: %.0f px" % w[i - 1].distance_to(w[i]))
				_check(w[i].y < w[i - 1].y, "wave must go upwards")
		var c := FruitLayout.cluster(Vector2(360, 0), 6, 100.0)
		for i in c.size():
			_check(c[i].distance_to(Vector2(360, 0)) <= 100.0, "cluster fruit outside its radius")
			if i > 0:
				_check(c[i].y <= c[i - 1].y, "cluster must be sorted bottom to top")
			for j in range(i + 1, c.size()):
				_check(c[i].distance_to(c[j]) >= 45.0, "cluster fruit overlap: %.0f px" % c[i].distance_to(c[j]))
	_check(shapes.size() >= 8, "waves look the same every time (%d shapes)" % shapes.size())


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


func _clear_world() -> void:
	var world: Node2D = main.get("world")
	for c in world.get_children():
		world.remove_child(c)
		c.free()


func _fruit_in_world() -> Array[Hazard]:
	var out: Array[Hazard] = []
	for c in (main.get("world") as Node2D).get_children():
		if (c as Hazard).kind == "fruit" and not c.is_queued_for_deletion():
			out.append(c as Hazard)
	return out


func _finish_hop() -> void:
	var guard := 0
	while main.get("flying") and guard < 120:
		main.call("_process", DT)
		guard += 1


## Fruit is worth its fixed value: no multiplier, however many are eaten in a row.
func _test_fruit_points() -> void:
	main.call("_start_game")
	main.set("since_row", -100000.0)
	var total := 0
	for i in 8:
		main.call("_spawn_fruit", Vector2(main.W * 0.5, 300.0))
		var f: Hazard = _fruit_in_world().back()
		total += f.value
		main.call("_collect", f)
	_check(int(main.get("fruit_points")) == total, "8 fruit in a row should give %d points, got %d" % [total, int(main.get("fruit_points"))])
	_clear_world()


## Fruit is never placed inside the reach of a hazard (whole swing or slide).
func _test_fruit_clearance() -> void:
	main.call("_start_game")
	var placed := 0
	for t in 120:
		_clear_world()
		var hazard: String = ["ball", "saw_slide", "zigzag", "fireball", "perch_saws"][t % 5]
		main.call("_spawn_pattern", hazard, -100.0)
		var fruit_pattern: String = ["fruit_wave", "fruit_trail", "sky_fruit", "fruit_swoop"][t % 4]
		main.call("_spawn_pattern", fruit_pattern, -100.0 + randf_range(-200.0, 100.0))
		var fruit := _fruit_in_world()
		placed += fruit.size()
		for f in fruit:
			for c in (main.get("world") as Node2D).get_children():
				var h := c as Hazard
				if h.kind != "fruit":
					_check(not h.blocks(f.position, 0.0), "%s placed inside a %s (%s)" % [fruit_pattern, h.kind, str(f.position)])
	_check(placed > 100, "clearance removed almost all fruit (%d left)" % placed)
	_clear_world()


## A swoop ribbon is eaten completely by one hop started at the right moment.
func _test_swoop() -> void:
	var player: Node2D = main.get("player")
	for t in 30:
		main.call("_start_game")
		main.set("since_row", -100000.0)
		_clear_world()
		main.call("_spawn_pattern", "fruit_swoop", -100.0)
		var fruit := _fruit_in_world()
		_check(fruit.size() >= 3, "swoop should have 3-4 fruit, got %d" % fruit.size())
		if fruit.is_empty():
			continue
		# Stand on the wall the ribbon starts from.
		var from_left: bool = fruit[0].position.x < main.W * 0.5
		main.set("on_left", from_left)
		player.position.x = main.call("_cling_x", from_left)
		var start_y := fruit[0].position.y
		var guard := 0
		while fruit[0].position.y - start_y - 100.0 < main.PLAYER_Y and guard < 1000:
			main.call("_process", DT)
			guard += 1
		main.call("_on_tap")
		_finish_hop()
		_check(int(main.get("fruit_count")) == fruit.size(), "one hop ate %d of %d swoop fruit" % [int(main.get("fruit_count")), fruit.size()])
	_clear_world()


## Perches: reachable hop lands in the middle, the lift parks under the player,
## a tap goes on to the far wall, and it gives out on its own after LIFT_HOLD.
func _test_perch() -> void:
	var player: Node2D = main.get("player")
	main.call("_start_game")
	main.set("since_row", -100000.0)
	_clear_world()

	# Too high: a normal wall hop.
	main.call("_spawn_perch", 200.0)
	_check(main.call("catchable_perch") == null, "a far perch must not be reachable")
	main.call("_on_tap")
	_check(is_equal_approx(float(main.get("fly_to")), main.CLING_R), "hop without a perch in reach must go to the wall")
	_finish_hop()
	_clear_world()

	# In reach: stop in the middle (player is on the right wall now, heading left).
	main.call("_spawn_pattern", "perch", main.PERCH_STAND_Y - 150.0)
	var lift: Hazard = null
	for c in (main.get("world") as Node2D).get_children():
		if (c as Hazard).kind == "perch":
			lift = c
	main.call("_process", DT)
	_check(lift.lit, "a reachable perch should be highlighted")
	main.call("_on_tap")
	_check(is_equal_approx(float(main.get("fly_to")), main.W * 0.5), "hop with a perch in reach must stop in the middle")
	_finish_hop()
	_check(main.get("perch") == lift, "player should stand on the perch")
	_check(player.position == Vector2(main.W * 0.5, main.PLAYER_Y), "player should stand in the middle at PLAYER_Y")
	for i in int(1.2 / DT):
		main.call("_process", DT)
	_check(main.get("perch") == lift and not main.get("flying"), "the perch should carry the player for a while")
	_check(absf(lift.position.y - main.PERCH_STAND_Y) < 2.0, "the perch should park under the player (y=%.1f)" % lift.position.y)
	_check(int(main.get("fruit_count")) >= 2, "riding the perch should collect the fruit above it (%d)" % int(main.get("fruit_count")))

	# Tap: go on to the left wall (the one it was heading for).
	main.call("_on_tap")
	_finish_hop()
	_check(is_equal_approx(player.position.x, main.CLING_L), "from a perch the hop must go on to the far wall")
	_check(lift.spent and main.get("perch") == null, "a used perch must drop away")
	_check(main.call("catchable_perch") == null, "a used perch cannot be caught again")
	_clear_world()

	# Waiting too long: the lift gives out and the player hops on by itself.
	main.call("_spawn_perch", main.PERCH_STAND_Y - 100.0)
	main.call("_on_tap")
	_finish_hop()
	_check(main.get("perch") != null, "second perch should be caught")
	var waited := 0.0
	while main.get("perch") != null and waited < 5.0:
		main.call("_process", DT)
		waited += DT
	_check(absf(waited - Hazard.LIFT_HOLD) < 0.1, "perch should give out after %.1f s, took %.2f s" % [Hazard.LIFT_HOLD, waited])
	_finish_hop()
	_check(is_equal_approx(player.position.x, main.CLING_R), "after the perch gives out the player must be on the far wall")
	_check(int(main.get("perch_landings")) == 2, "perch_landings should be 2")
	_clear_world()

	# Spacing: no new perch until the last one is surely gone, even at top speed
	# with the player riding it for the full LIFT_HOLD.
	var top_speed: float = main.BASE_SPEED + main.MAX_EXTRA_SPEED
	# Both spawn at y=-100. Worst case: the first one is caught as late as possible
	# and ridden to the end; the next must not come within 200 px before it is gone.
	var busy: float = (main.PERCH_STAND_Y + main.PERCH_CATCH_BELOW + 100.0) + (Hazard.LIFT_HOLD + main.PERCH_FLY_TIME) * top_speed
	var next_arrives: float = main.PERCH_STAND_Y - 200.0 + 100.0
	_check(main.PERCH_SPACING + next_arrives >= busy, "PERCH_SPACING %.0f too small: perches could stack up" % main.PERCH_SPACING)
	main.set("zone", 0)
	main.set("distance", 5000.0)
	main.call("_spawn_perch", -100.0)
	_clear_world()
	var perches := 0
	for i in 300:
		if (main.call("_next_pattern") as String).begins_with("perch"):
			perches += 1
	_check(perches == 0, "a perch pattern was picked %d times right after another perch" % perches)
	main.set("distance", 5000.0 + main.PERCH_SPACING)
	for i in 300:
		if (main.call("_next_pattern") as String).begins_with("perch"):
			perches += 1
	_check(perches > 0, "perches never come back after the spacing")
	main.call("_show_title")


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


func _tap(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	main.call("_input", ev)


## Regression: tapping the character (not only its price) must buy it, and a tap
## in the shop must never start the game.
func _test_shop_taps() -> void:
	main.set("save_enabled", false)
	main.set("owned", ["ninja_frog"] as Array[String])
	main.call("_select_character", "ninja_frog")
	main.call("_show_title")
	var c: Dictionary = Catalog.CHARACTERS[1]
	var price := int(c["price"])
	var on_character := Vector2(main.W * 0.5, main.PICK_Y)
	var on_price := Vector2(main.W * 0.5, main.PICK_Y + 110.0)

	_tap((main.NEXT_RECT as Rect2).get_center())
	_check(int(main.get("preview_idx")) == 1, "tapping next should show the second character")
	main.set("wallet", price - 1)
	_tap(on_character)
	_check(int(main.get("mode")) == main.Mode.TITLE, "tapping a locked character must not start the game")
	_check(not (main.get("owned") as Array).has(c["id"]), "must not buy without enough points")

	main.set("wallet", price)
	_tap(on_character)
	_check((main.get("owned") as Array).has(c["id"]), "tapping the character must buy it")
	_check(int(main.get("wallet")) == 0, "buying by tapping must take the price")
	_check(int(main.get("mode")) == main.Mode.TITLE, "buying must not start the game")

	main.set("owned", ["ninja_frog"] as Array[String])
	main.set("wallet", price)
	main.call("_refresh_picker")
	_tap(on_price)
	_check((main.get("owned") as Array).has(c["id"]), "tapping the price must buy it")

	main.set("owned", ["ninja_frog"] as Array[String])
	main.set("wallet", 0)
	main.call("_select_character", "ninja_frog")
	main.call("_show_title")


## Comfort rules against motion sickness and eye strain (docs/GAME_DESIGN.md).
func _test_comfort() -> void:
	_check(Hazard.FIRE_WARN > main.FLY_TIME, "fire must warn longer than a hop takes")
	_check(main.BASE_SPEED + main.MAX_EXTRA_SPEED <= 420.0, "top scroll speed must stay at or below 420 px/s")
	_check(main.CLING_R - main.CLING_L <= 380.0, "a hop should cross at most 380 px")

	# Protection after a continue: a soft pulse, at most 3 dips per second, never fully hidden.
	var player: Node2D = main.get("player")
	main.set("invuln", main.INVULN_TIME)
	var alphas: Array[float] = []
	for i in int(main.INVULN_TIME * 60.0) + 2: # +2: float rounding leaves a tiny remainder
		main.call("_update_invuln", 1.0 / 60.0)
		alphas.append(player.modulate.a)
	var dips := 0
	var lowest := 1.0
	for i in range(1, alphas.size() - 1):
		lowest = minf(lowest, alphas[i])
		if alphas[i] < alphas[i - 1] and alphas[i] <= alphas[i + 1]:
			dips += 1
	_check(float(dips) / main.INVULN_TIME <= 3.0, "protection pulse is %.1f dips/s, must be <= 3" % (float(dips) / main.INVULN_TIME))
	_check(lowest >= 0.25, "player must stay visible while protected (alpha %.2f)" % lowest)
	_check(player.modulate.a == 1.0, "player must be fully visible after the protection")

	# Eased hop: slow at the start, fastest in the middle.
	main.call("_start_game")
	main.call("_begin_jump")
	var xs: Array[float] = [player.position.x]
	while main.get("flying"):
		main.call("_process", 1.0 / 60.0)
		xs.append(player.position.x)
	var first := absf(xs[1] - xs[0])
	var fastest := 0.0
	for i in range(1, xs.size()):
		fastest = maxf(fastest, absf(xs[i] - xs[i - 1]))
	_check(first < fastest * 0.35, "hop should start slowly (first step %.1f px, fastest %.1f px)" % [first, fastest])

	# Reduced motion: no afterimages, no embers or sparks.
	main.set("reduced_motion", true)
	var fx: Node2D = main.get("fx")
	for c in fx.get_children():
		fx.remove_child(c)
		c.free()
	main.call("_begin_jump")
	while main.get("flying"):
		main.call("_process", 1.0 / 60.0)
	var ghosts := 0
	for c in fx.get_children():
		if c is Sprite2D and (c as Sprite2D).texture != main.get("dust_tex"):
			ghosts += 1
	_check(ghosts == 0, "reduced motion must not leave afterimages (%d found)" % ghosts)
	main.call("_spawn_fireball", 400.0)
	var world: Node2D = main.get("world")
	var ball := world.get_child(world.get_child_count() - 1) as Hazard
	_check(ball.sparks == null, "reduced motion must not burst sparks")
	main.set("reduced_motion", false)
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
		_test_fruit_points()
		_test_fruit_clearance()
		_test_swoop()
		_test_perch()
		_test_continue()
		_test_shop_taps()
		_test_comfort()
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
	shake_frames = 0
	bg_moved_frames = 0
	center_fruit_ids = {}
	fruit_checked = {}
	trapped_fruit = 0
	stacked_perch_frames = 0


func _step() -> void:
	main.call("_process", DT)
	step += 1
	tap_timer -= DT
	if tap_timer <= 0.0:
		main.call("_on_tap")
		tap_timer = randf_range(0.25, 1.2)

	zones_seen[main.get("zone")] = true
	if main.position != Vector2.ZERO:
		shake_frames += 1
	if (main.get("bg") as Control).position.y != 0.0:
		bg_moved_frames += 1
	var walls: Array[bool] = main.call("deadly_walls")
	if walls[0] and walls[1]:
		unfair_frames += 1

	var world: Node2D = main.get("world")
	var perch_ys: Array[float] = []
	for c in world.get_children():
		var h := c as Hazard
		if h.is_queued_for_deletion():
			continue
		if h.kind == "perch" and not h.spent:
			for py in perch_ys:
				if absf(py - h.position.y) < 200.0:
					stacked_perch_frames += 1
			perch_ys.append(h.position.y)
		if h.kind == "fruit" and not fruit_checked.has(h.get_instance_id()):
			# New fruit must not sit on a hazard (fire is fine: it is only deadly while burning).
			fruit_checked[h.get_instance_id()] = true
			for o in world.get_children():
				var oh := o as Hazard
				if oh != h and oh.kind != "fire" and oh.kind != "fruit" and not oh.is_queued_for_deletion() \
						and oh.motion == Hazard.Motion.NONE and oh.touches(h.position, 0.0):
					trapped_fruit += 1
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
	var landings := int(main.get("perch_landings"))
	print("run %d: %.0f m, zones %s, kinds %s, center fruit %d, perch landings %d, bot hits %d" % [
		run, meters, str(zones_seen.keys()), str(kinds_seen.keys()), center_fruit, landings, int(main.get("god_hits"))])
	_check(landings >= 2, "run %d: the bot landed on only %d perches" % [run, landings])
	_check(stacked_perch_frames == 0, "run %d: two perches stacked up in %d frames" % [run, stacked_perch_frames])
	_check(trapped_fruit == 0, "run %d: %d fruit spawned on a hazard" % [run, trapped_fruit])
	_check(zones_seen.size() == Zones.LIST.size(), "run %d reached only zones %s" % [run, str(zones_seen.keys())])
	for k: String in ["saw", "spike", "fire", "ball", "fruit", "fireball", "perch"]:
		_check(kinds_seen.has(k), "run %d never spawned %s" % [run, k])
	for m: int in [Hazard.Motion.SLIDE, Hazard.Motion.SWING, Hazard.Motion.FIRE, Hazard.Motion.SHOOT]:
		_check(motions_seen.has(m), "run %d never used motion %d" % [run, m])
	_check(unfair_frames == 0, "run %d: both walls deadly at once in %d frames" % [run, unfair_frames])
	_check(shake_frames == 0, "run %d: the screen moved (shake) in %d frames" % [run, shake_frames])
	_check(bg_moved_frames == 0, "run %d: the background scrolled in %d frames" % [run, bg_moved_frames])
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
