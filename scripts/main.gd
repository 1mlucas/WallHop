extends Node2D
## Wall Hop - v0.1
## Tap to hop to the opposite wall. Dodge saws and spikes, grab fruit.

const Art := preload("res://scripts/art.gd")

enum Mode { TITLE, PLAY, DEAD }

# --- Layout (720x1280 portrait, pixel art drawn at 3x) ---
const W := 720.0
const H := 1280.0
const S := 3.0
const TILE := 16.0 * S
const WALL_W := TILE * 2.0
const CLING_L := WALL_W + 36.0
const CLING_R := W - WALL_W - 36.0
const PLAYER_Y := 900.0

# --- Feel ---
const FLY_TIME := 0.28
const ARC := 70.0
const PLAYER_R := 24.0
const SAVE_PATH := "user://wallhop.cfg"

const FRUITS := ["apple", "bananas", "cherries", "kiwi", "melon", "orange", "pineapple", "strawberry"]
const SFX_NAMES := ["jump", "wall_jump", "fruit", "hit", "click", "highscore"]

var mode: Mode = Mode.TITLE
var flying := false
var on_left := true
var fly_t := 0.0
var fly_from := 0.0
var fly_to := 0.0
var buffered := false

var speed := 0.0
var distance := 0.0
var scroll := 0.0
var bg_scroll := 0.0
var since_row := 0.0
var fruit_count := 0
var score := 0
var best := 0
var shake := 0.0
var dead_vel := 0.0
var tap_lock_until := 0

var bg: TextureRect
var wall_l: TextureRect
var wall_r: TextureRect
var world: Node2D
var player: AnimatedSprite2D

var saw_frames: SpriteFrames
var collected_frames: SpriteFrames
var fruit_frames := {}
var spike_tex: Texture2D

var dim: ColorRect
var score_label: Label
var title_label: Label
var tap_label: Label
var best_label: Label
var over_label: Label
var result_label: Label

var sfx := {}
var music: AudioStreamPlayer
var music_title: AudioStream
var music_level: AudioStream


func _ready() -> void:
	randomize()
	_load_save()
	_build_art()
	_build_background()
	world = Node2D.new()
	add_child(world)
	_build_player()
	_build_ui()
	_build_audio()
	_show_title()


# ---------------------------------------------------------------- setup

func _build_art() -> void:
	saw_frames = Art.build({"spin": {"path": "res://assets/art/saw.png", "w": 38, "h": 38, "fps": 20.0}})
	collected_frames = Art.build({"pop": {"path": "res://assets/art/collected.png", "w": 32, "h": 32, "fps": 20.0, "loop": false}})
	for f: String in FRUITS:
		fruit_frames[f] = Art.build({"spin": {"path": "res://assets/art/fruit_%s.png" % f, "w": 32, "h": 32, "fps": 20.0}})
	spike_tex = load("res://assets/art/spikes.png")


func _tiled(path: String, size_px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.scale = Vector2(S, S)
	t.size = size_px / S
	return t


func _build_background() -> void:
	bg = _tiled("res://assets/art/bg_blue.png", Vector2(W, H + 64.0 * S))
	add_child(bg)
	wall_l = _tiled("res://assets/art/brick.png", Vector2(WALL_W, H + TILE * 2.0))
	wall_r = _tiled("res://assets/art/brick.png", Vector2(WALL_W, H + TILE * 2.0))
	wall_r.position.x = W - WALL_W
	add_child(wall_l)
	add_child(wall_r)
	for x in [WALL_W, W - WALL_W - 6.0]:
		var edge := ColorRect.new()
		edge.color = Color(0, 0, 0, 0.25)
		edge.position = Vector2(x, 0)
		edge.size = Vector2(6, H)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(edge)
	_apply_scroll()


func _build_player() -> void:
	player = AnimatedSprite2D.new()
	player.sprite_frames = Art.build({
		"wall": {"path": "res://assets/art/frog_wall.png", "w": 32, "h": 32, "fps": 10.0},
		"jump": {"path": "res://assets/art/frog_jump.png", "w": 32, "h": 32, "fps": 20.0},
		"fall": {"path": "res://assets/art/frog_fall.png", "w": 32, "h": 32, "fps": 20.0},
		"hit": {"path": "res://assets/art/frog_hit.png", "w": 32, "h": 32, "fps": 20.0, "loop": false},
	})
	player.scale = Vector2(S, S)
	add_child(player)


func _make_label(parent: Node, text: String, font_size: int, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.custom_minimum_size = Vector2(W, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	l.add_theme_constant_override("outline_size", int(font_size / 6.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	score_label = _make_label(layer, "0", 88, 70.0)
	title_label = _make_label(layer, "WALL HOP", 110, 260.0)
	tap_label = _make_label(layer, "TAP TO START", 56, 760.0)
	best_label = _make_label(layer, "BEST 0", 48, 560.0)
	over_label = _make_label(layer, "GAME OVER", 96, 330.0)
	result_label = _make_label(layer, "SCORE 0", 64, 470.0)
	var blink := create_tween().set_loops()
	blink.tween_property(tap_label, "modulate:a", 0.25, 0.6)
	blink.tween_property(tap_label, "modulate:a", 1.0, 0.6)


func _build_audio() -> void:
	for n: String in SFX_NAMES:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/sfx/%s.ogg" % n)
		p.volume_db = -4.0
		add_child(p)
		sfx[n] = p
	music = AudioStreamPlayer.new()
	music.volume_db = -8.0
	add_child(music)
	var t: AudioStreamOggVorbis = load("res://assets/audio/music/title.ogg")
	t.loop = true
	music_title = t
	var l: AudioStreamOggVorbis = load("res://assets/audio/music/level1.ogg")
	l.loop = true
	music_level = l


func _sfx(n: String) -> void:
	var p: AudioStreamPlayer = sfx[n]
	p.play()


func _play_music(stream: AudioStream) -> void:
	if music.stream != stream or not music.playing:
		music.stream = stream
		music.play()


# ---------------------------------------------------------------- save

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = int(cfg.get_value("game", "best", 0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.save(SAVE_PATH)


# ---------------------------------------------------------------- flow

func _show_title() -> void:
	mode = Mode.TITLE
	_reset_player()
	score_label.visible = false
	dim.visible = true
	title_label.visible = true
	tap_label.text = "TAP TO START"
	tap_label.visible = true
	best_label.text = "BEST %d" % best
	best_label.position.y = 560.0
	best_label.visible = true
	over_label.visible = false
	result_label.visible = false
	_play_music(music_title)


func _start_game() -> void:
	_sfx("click")
	for c in world.get_children():
		c.queue_free()
	distance = 0.0
	since_row = 0.0
	fruit_count = 0
	score = 0
	speed = 280.0
	buffered = false
	_reset_player()
	mode = Mode.PLAY
	score_label.text = "0"
	score_label.visible = true
	dim.visible = false
	title_label.visible = false
	tap_label.visible = false
	best_label.visible = false
	over_label.visible = false
	result_label.visible = false
	_play_music(music_level)


func _reset_player() -> void:
	flying = false
	on_left = true
	player.rotation = 0.0
	player.position = Vector2(CLING_L, PLAYER_Y)
	player.flip_h = false
	player.play("wall")


func _die() -> void:
	mode = Mode.DEAD
	flying = false
	player.play("hit")
	dead_vel = -520.0
	shake = 14.0
	_sfx("hit")
	music.stop()
	tap_lock_until = Time.get_ticks_msec() + 700
	var is_best := score > best
	if is_best:
		best = score
		_save()
	get_tree().create_timer(0.7).timeout.connect(_show_game_over.bind(is_best))


func _show_game_over(is_best: bool) -> void:
	if mode != Mode.DEAD:
		return
	dim.visible = true
	over_label.visible = true
	result_label.text = "SCORE %d" % score
	result_label.visible = true
	best_label.text = "NEW BEST!" if is_best else "BEST %d" % best
	best_label.position.y = 580.0
	best_label.visible = true
	tap_label.text = "TAP TO RETRY"
	tap_label.position.y = 780.0
	tap_label.visible = true
	if is_best:
		_sfx("highscore")


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		var k := event as InputEventKey
		pressed = k.pressed and not k.echo and (k.keycode == KEY_SPACE or k.keycode == KEY_ENTER)
	if pressed:
		_on_tap()


func _on_tap() -> void:
	match mode:
		Mode.TITLE:
			tap_label.position.y = 760.0
			_start_game()
		Mode.PLAY:
			if flying:
				if fly_t > 0.5:
					buffered = true
			else:
				_begin_jump()
		Mode.DEAD:
			if Time.get_ticks_msec() >= tap_lock_until:
				tap_label.position.y = 760.0
				_start_game()


func _begin_jump() -> void:
	flying = true
	buffered = false
	fly_t = 0.0
	fly_from = player.position.x
	on_left = not on_left
	fly_to = CLING_L if on_left else CLING_R
	player.flip_h = on_left
	player.play("jump")
	_sfx("jump")


func _land() -> void:
	flying = false
	player.position = Vector2(fly_to, PLAYER_Y)
	player.flip_h = not on_left
	player.play("wall")
	_sfx("wall_jump")
	if buffered:
		buffered = false
		_begin_jump()


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	match mode:
		Mode.TITLE:
			_scroll(60.0, delta)
		Mode.PLAY:
			_update_play(delta)
		Mode.DEAD:
			_update_dead(delta)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 40.0)
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	else:
		position = Vector2.ZERO


func _scroll(spd: float, delta: float) -> void:
	scroll += spd * delta
	bg_scroll += spd * 0.3 * delta
	_apply_scroll()


func _apply_scroll() -> void:
	bg.position.y = -64.0 * S + fmod(bg_scroll, 64.0 * S)
	wall_l.position.y = -TILE + fmod(scroll, TILE)
	wall_r.position.y = wall_l.position.y


func _update_play(delta: float) -> void:
	speed = 280.0 + minf(distance * 0.025, 260.0)
	distance += speed * delta
	_scroll(speed, delta)
	score = int(distance / 60.0) + fruit_count * 5
	score_label.text = str(score)

	if flying:
		fly_t += delta / FLY_TIME
		var t := minf(fly_t, 1.0)
		player.position.x = lerpf(fly_from, fly_to, t)
		player.position.y = PLAYER_Y - sin(t * PI) * ARC
		if t > 0.5 and player.animation != &"fall":
			player.play("fall")
		if fly_t >= 1.0:
			_land()

	since_row += speed * delta
	var gap := lerpf(460.0, 340.0, clampf(distance / 20000.0, 0.0, 1.0))
	if since_row >= gap:
		since_row = 0.0
		_spawn_row()

	for o in world.get_children():
		var n := o as Node2D
		n.position.y += speed * delta
		if n.position.y > H + 150.0:
			n.queue_free()
			continue
		var kind: String = n.get_meta("kind")
		if kind == "fx":
			continue
		var r: float = n.get_meta("r")
		if player.position.distance_to(n.position) < r + PLAYER_R:
			if kind == "fruit":
				_collect(n)
			else:
				_die()
				return


func _update_dead(delta: float) -> void:
	dead_vel += 2400.0 * delta
	player.position.y += dead_vel * delta
	player.rotation += (9.0 if on_left else -9.0) * delta


# ---------------------------------------------------------------- spawning

func _spawn_row() -> void:
	var left := randf() < 0.5
	var roll := randf()
	var y := -100.0
	if roll < 0.35:
		_spawn_saw(left, y)
	elif roll < 0.70:
		_spawn_spikes(left, y)
	else:
		_spawn_fruit(left, y)
		_spawn_fruit(left, y - 90.0)
		if randf() < 0.5:
			_spawn_saw(not left, y - 45.0)


func _spawn_saw(left: bool, y: float) -> void:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = saw_frames
	s.scale = Vector2(2.4, 2.4)
	var x := (WALL_W + 30.0) if left else (W - WALL_W - 30.0)
	s.position = Vector2(x, y)
	s.set_meta("kind", "saw")
	s.set_meta("r", 34.0)
	world.add_child(s)
	s.play("spin")


func _spawn_spikes(left: bool, y: float) -> void:
	for i in 3:
		var sp := Sprite2D.new()
		sp.texture = spike_tex
		sp.scale = Vector2(S, S)
		sp.rotation_degrees = 90.0 if left else -90.0
		var x := (WALL_W + 24.0) if left else (W - WALL_W - 24.0)
		sp.position = Vector2(x, y + (i - 1) * TILE)
		sp.set_meta("kind", "spike")
		sp.set_meta("r", 22.0)
		world.add_child(sp)


func _spawn_fruit(left: bool, y: float) -> void:
	var key: String = FRUITS.pick_random()
	var f := AnimatedSprite2D.new()
	f.sprite_frames = fruit_frames[key]
	f.scale = Vector2(2.5, 2.5)
	f.position = Vector2(CLING_L if left else CLING_R, y)
	f.set_meta("kind", "fruit")
	f.set_meta("r", 34.0)
	world.add_child(f)
	f.play("spin")


func _collect(fruit: Node2D) -> void:
	fruit_count += 1
	_sfx("fruit")
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = collected_frames
	fx.scale = Vector2(2.5, 2.5)
	fx.position = fruit.position
	fx.set_meta("kind", "fx")
	world.add_child(fx)
	fx.play("pop")
	fx.animation_finished.connect(fx.queue_free)
	fruit.queue_free()
