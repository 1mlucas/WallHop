extends Node2D
## Wall Hop - v0.3
## Tap to hop to the opposite wall. Dodge hazards, grab fruit, travel through zones.

const Art := preload("res://scripts/art.gd")
const Zones := preload("res://scripts/zones.gd")
const Hazard := preload("res://scripts/hazard.gd")
const Catalog := preload("res://scripts/catalog.gd")

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
const BASE_SPEED := 280.0
const MAX_EXTRA_SPEED := 260.0
const BREATHER := 450.0 # empty space after a zone change
const MAX_COMBO := 5
const SAVE_PATH := "user://wallhop.cfg"

const SFX_NAMES := ["jump", "wall_jump", "fruit", "hit", "click", "highscore"]
const MUTE_RECT := Rect2(W - 100.0, 30.0, 80.0, 80.0)
# Character picker on the title screen
const PICK_Y := 1010.0
const PREV_RECT := Rect2(110.0, PICK_Y - 60.0, 120.0, 120.0)
const NEXT_RECT := Rect2(W - 230.0, PICK_Y - 60.0, 120.0, 120.0)
# Tapping the character itself or its price buys / selects it (between the arrows).
const BUY_RECT := Rect2(W * 0.5 - 130.0, PICK_Y - 90.0, 260.0, 280.0)
const BACK_RECT := Rect2(24.0, H - 150.0, 120.0, 120.0)
const GOLD := Color(1, 0.85, 0.3)
# Game over buttons (centres); each button reacts inside a square of BUTTON_SIZE.
const OVER_BUTTONS_Y := 820.0
const BUTTON_SIZE := 200.0
# Continue: fruit-point price of the 1st, 2nd... continue in one run. Its size is the limit.
const CONTINUE_COSTS: Array[int] = [100, 250]
const INVULN_TIME := 1.5 # seconds of protection after a continue
const TRAIL_EVERY := 0.03
# Middle fruit trails: fruit stays out of reach of a player holding a wall.
const TRAIL_HALF_WIDTH := 150.0
const TRAIL_MIN_STEP_X := 80.0

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
var zone := 0
var combo := 0
var fruit_count := 0
var fruit_points := 0
var score := 0
var best := 0
var best_zone := 0
var muted := false
var wallet := 0 # fruit points to spend in the shop
var owned: Array[String] = ["ninja_frog"]
var selected := "ninja_frog"
var preview_idx := 0
var trail_timer := 0.0
var shake := 0.0
var dead_vel := 0.0
var tap_lock_until := 0
var continues_used := 0
var banked := 0 # fruit points of this run already added to the wallet
var invuln := 0.0
## Test hook: when true, hits are counted instead of killing the player.
var god_mode := false
## Test hook: when false, nothing is written to the save file.
var save_enabled := true
var god_hits := 0

var bg: TextureRect
var bg_next: TextureRect
var wall_l: TextureRect
var wall_r: TextureRect
var world: Node2D
var fx: Node2D
var player: AnimatedSprite2D

var saw_frames: SpriteFrames
var collected_frames: SpriteFrames
var fire_frames: SpriteFrames
var fireball_frames: SpriteFrames
var launcher_tex: AtlasTexture
var glow_tex: GradientTexture2D
var additive: CanvasItemMaterial
var ember_ramp: Gradient
var spark_ramp: Gradient
var shrink_curve: Curve
var fruit_frames := {}
var spike_tex: Texture2D
var saw_chain_tex: Texture2D
var ball_tex: Texture2D
var ball_chain_tex: Texture2D
var dust_tex: Texture2D
var bg_textures := {}

var dim: ColorRect
var hud: Control
var score_label: Label
var fruit_label: Label
var combo_label: Label
var title_screen: Control
var over_screen: Control
var title_label: Label
var best_label: Label
var title_dots: Array[ColorRect] = []
var result_label: Label
var new_best_label: Label
var over_best_label: Label
var over_dots: Array[ColorRect] = []
var trophy_tex: Texture2D
var apple_tex: Texture2D
var banner_small: Label
var banner_big: Label
var banner_tweens: Array[Tween] = []
var mute_btn: TextureRect
var mute_slash: ColorRect
var picker: Control
var preview: AnimatedSprite2D
var price_label: Label
var wallet_label: Label
var earned_label: Label
var restart_icon: Sprite2D
var continue_icon: Sprite2D
var continue_cost_label: Label

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
	fx = Node2D.new()
	add_child(fx)
	_build_player()
	_build_ui()
	_build_audio()
	_apply_mute()
	_show_title()


# ---------------------------------------------------------------- setup

func _build_art() -> void:
	saw_frames = Art.build({"spin": {"path": "res://assets/art/saw.png", "w": 38, "h": 38, "fps": 20.0}})
	collected_frames = Art.build({"pop": {"path": "res://assets/art/collected.png", "w": 32, "h": 32, "fps": 20.0, "loop": false}})
	fire_frames = Art.build({
		"off": {"path": "res://assets/art/fire_off.png", "w": 16, "h": 32, "fps": 1.0},
		"warn": {"path": "res://assets/art/fire_warn.png", "w": 16, "h": 32, "fps": 16.0},
		"on": {"path": "res://assets/art/fire_on.png", "w": 16, "h": 32, "fps": 14.0},
	})
	# Fireball: only the flame (top half) of the fire sprite. Launcher: only the block (bottom half).
	fireball_frames = Art.build({"fly": {"path": "res://assets/art/fire_on.png", "w": 16, "h": 16, "fps": 20.0}})
	_build_fire_fx()
	launcher_tex = AtlasTexture.new()
	launcher_tex.atlas = load("res://assets/art/fire_off.png")
	launcher_tex.region = Rect2(0, 16, 16, 16)
	for f: String in Catalog.FRUITS:
		fruit_frames[f] = Art.build({"spin": {"path": "res://assets/art/fruit_%s.png" % f, "w": 32, "h": 32, "fps": 20.0}})
	spike_tex = load("res://assets/art/spikes.png")
	saw_chain_tex = load("res://assets/art/saw_chain.png")
	ball_tex = load("res://assets/art/spiked_ball.png")
	ball_chain_tex = load("res://assets/art/ball_chain.png")
	dust_tex = load("res://assets/art/dust.png")
	for z: Dictionary in Zones.LIST:
		bg_textures[z["bg"]] = load(z["bg"])


## Shared resources for the fireball: soft glow, additive blending, ember colours.
func _build_fire_fx() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.35, 0.8))
	g.set_color(1, Color(1.0, 0.3, 0.0, 0.0))
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = g
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 128
	glow_tex.height = 128
	additive = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ember_ramp = Gradient.new()
	ember_ramp.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	ember_ramp.add_point(0.35, Color(1.0, 0.45, 0.1, 0.95))
	ember_ramp.set_color(1, Color(0.55, 0.1, 0.05, 0.0))
	spark_ramp = Gradient.new()
	spark_ramp.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	spark_ramp.set_color(1, Color(1.0, 0.4, 0.0, 0.0))
	shrink_curve = Curve.new()
	shrink_curve.add_point(Vector2(0.0, 1.0))
	shrink_curve.add_point(Vector2(1.0, 0.0))


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
	bg_next = _tiled("res://assets/art/bg_blue.png", Vector2(W, H + 64.0 * S))
	bg_next.modulate.a = 0.0
	add_child(bg_next)
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
	player.sprite_frames = Catalog.character_frames(selected)
	player.scale = Vector2(S, S)
	add_child(player)


func _style_label(l: Label, font_size: int) -> void:
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	l.add_theme_constant_override("outline_size", int(font_size / 6.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_label(parent: Node, text: String, font_size: int, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.custom_minimum_size = Vector2(W, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(l, font_size)
	parent.add_child(l)
	return l


## A row with an icon and a number. Centred across the screen unless `centered` is false.
## Returns the label; its parent is the row (hide the row to hide both).
func _icon_row(parent: Control, tex: Texture2D, icon_scale: float, font_size: int, pos: Vector2, centered: bool = true) -> Label:
	var row := HBoxContainer.new()
	row.position = pos
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		row.custom_minimum_size = Vector2(W, 0)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = tex.get_size() * icon_scale
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var l := Label.new()
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(l, font_size)
	row.add_child(l)
	return l


## One small coloured bar per zone; filled up to the zone reached.
func _zone_dots(parent: Control, y: float) -> Array[ColorRect]:
	var row := HBoxContainer.new()
	row.position = Vector2(0, y)
	row.custom_minimum_size = Vector2(W, 0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var dots: Array[ColorRect] = []
	for i in Zones.LIST.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(48, 18)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(d)
		dots.append(d)
	return dots


func _fill_zone_dots(dots: Array[ColorRect], reached: int) -> void:
	for i in dots.size():
		dots[i].color = (Zones.LIST[i]["color"] as Color) if i <= reached else Color(0, 0, 0, 0.35)


## A big icon that gently pulses, used as the "tap" hint instead of text.
func _pulse_icon(parent: Node, path: String, pos: Vector2, sc: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	sp.position = pos
	sp.scale = Vector2(sc, sc)
	parent.add_child(sp)
	var tw := sp.create_tween().set_loops()
	tw.tween_property(sp, "scale", Vector2(sc, sc) * 1.12, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sp, "scale", Vector2(sc, sc), 0.5).set_trans(Tween.TRANS_SINE)
	return sp


func _screen(layer: CanvasLayer) -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	return c


func _build_ui() -> void:
	trophy_tex = load("res://assets/art/icon_trophy.png")
	apple_tex = (fruit_frames["apple"] as SpriteFrames).get_frame_texture("spin", 0)
	var layer := CanvasLayer.new()
	add_child(layer)
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	_build_hud(layer)
	_build_title_screen(layer)
	_build_over_screen(layer)
	banner_small = _make_label(layer, "", 40, 330.0)
	banner_big = _make_label(layer, "", 84, 380.0)
	banner_small.modulate.a = 0.0
	banner_big.modulate.a = 0.0

	mute_btn = TextureRect.new()
	mute_btn.texture = load("res://assets/art/btn_volume.png")
	mute_btn.scale = Vector2(S, S)
	mute_btn.position = MUTE_RECT.position + Vector2(8, 8)
	mute_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(mute_btn)
	mute_slash = ColorRect.new()
	mute_slash.color = Color(0.9, 0.15, 0.15)
	mute_slash.size = Vector2(28, 3)
	mute_slash.pivot_offset = Vector2(14, 1.5)
	mute_slash.position = Vector2(-3.5, 9.5)
	mute_slash.rotation_degrees = 45.0
	mute_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mute_btn.add_child(mute_slash)


## Title: logo, trophy + best, zone bars, pulsing play icon, character picker, wallet.
func _build_title_screen(layer: CanvasLayer) -> void:
	title_screen = _screen(layer)
	title_label = _make_label(title_screen, "WALL HOP", 110, 230.0)
	best_label = _icon_row(title_screen, trophy_tex, S, 52, Vector2(0, 400))
	title_dots = _zone_dots(title_screen, 500.0)
	_pulse_icon(title_screen, "res://assets/art/btn_play.png", Vector2(W * 0.5, 690.0), 5.0)
	wallet_label = _icon_row(title_screen, apple_tex, 2.4, 44, Vector2(20, 28), false)
	wallet_label.add_theme_color_override("font_color", GOLD)
	_build_picker(title_screen)


## Game over: big score, best (or NEW BEST!), zone bars, fruit earned, restart / back icons.
func _build_over_screen(layer: CanvasLayer) -> void:
	over_screen = _screen(layer)
	result_label = _make_label(over_screen, "0", 140, 230.0)
	new_best_label = _make_label(over_screen, "NEW BEST!", 56, 430.0)
	new_best_label.add_theme_color_override("font_color", GOLD)
	over_best_label = _icon_row(over_screen, trophy_tex, S, 48, Vector2(0, 430))
	over_dots = _zone_dots(over_screen, 530.0)
	earned_label = _icon_row(over_screen, apple_tex, 3.0, 56, Vector2(0, 575))
	earned_label.add_theme_color_override("font_color", GOLD)
	restart_icon = _pulse_icon(over_screen, "res://assets/art/btn_restart.png", Vector2(W * 0.5, OVER_BUTTONS_Y), 4.5)
	continue_icon = _pulse_icon(over_screen, "res://assets/art/btn_play.png", Vector2(W * 0.5, OVER_BUTTONS_Y), 4.5)
	continue_cost_label = _icon_row(over_screen, apple_tex, 2.2, 40, Vector2(0, OVER_BUTTONS_Y + 70.0))
	continue_cost_label.add_theme_color_override("font_color", GOLD)
	var back := Sprite2D.new()
	back.texture = load("res://assets/art/btn_back.png")
	back.scale = Vector2(S, S) * 1.2
	back.position = BACK_RECT.get_center()
	over_screen.add_child(back)


## Top-left corner: score, fruit count and combo, so the middle stays clear for fruit.
func _build_hud(layer: CanvasLayer) -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var panel := ColorRect.new()
	panel.color = Color(0, 0, 0, 0.3)
	panel.position = Vector2(16, 24)
	panel.size = Vector2(230, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	score_label = _make_corner_label("0", 60, Vector2(32, 26))
	var icon := TextureRect.new()
	icon.texture = (fruit_frames["apple"] as SpriteFrames).get_frame_texture("spin", 0)
	icon.scale = Vector2(2.2, 2.2)
	icon.position = Vector2(14, 92)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(icon)
	fruit_label = _make_corner_label("0", 40, Vector2(86, 108))
	combo_label = _make_corner_label("", 34, Vector2(28, 182))
	combo_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))


## Character picker: preview, arrows to browse, price (apple + number) when locked.
func _build_picker(parent: Control) -> void:
	picker = Control.new()
	picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picker)
	preview = AnimatedSprite2D.new()
	preview.scale = Vector2(4, 4)
	preview.position = Vector2(W * 0.5, PICK_Y)
	picker.add_child(preview)
	for pair: Array in [["res://assets/art/btn_prev.png", PREV_RECT], ["res://assets/art/btn_next.png", NEXT_RECT]]:
		var arrow := Sprite2D.new()
		arrow.texture = load(pair[0])
		arrow.scale = Vector2(S, S)
		arrow.position = (pair[1] as Rect2).get_center()
		picker.add_child(arrow)
	price_label = _icon_row(picker, apple_tex, 2.6, 48, Vector2(0, PICK_Y + 90.0))


func _refresh_picker() -> void:
	var c: Dictionary = Catalog.CHARACTERS[preview_idx]
	var id: String = c["id"]
	preview.sprite_frames = Catalog.character_frames(id)
	preview.play("idle")
	var price_row := price_label.get_parent() as Control
	if owned.has(id):
		preview.modulate = Color.WHITE
		price_row.visible = false
	else:
		preview.modulate = Color(0.15, 0.15, 0.2)
		var price := int(c["price"])
		price_label.text = str(price)
		price_label.add_theme_color_override("font_color", GOLD if wallet >= price else Color(0.6, 0.6, 0.6))
		price_row.visible = true
	wallet_label.text = str(wallet)


func _browse(step: int) -> void:
	preview_idx = posmod(preview_idx + step, Catalog.CHARACTERS.size())
	var id: String = Catalog.CHARACTERS[preview_idx]["id"]
	if owned.has(id):
		_select_character(id)
	_sfx("click")
	_refresh_picker()


func _select_character(id: String) -> void:
	selected = id
	player.sprite_frames = Catalog.character_frames(id)
	player.play("wall")
	_save()


## Buys the character shown in the picker. Returns true on success.
func try_buy(id: String) -> bool:
	var price := int(Catalog.character(id)["price"])
	if owned.has(id) or wallet < price:
		return false
	wallet -= price
	owned.append(id)
	_select_character(id)
	return true


func _on_buy_pressed() -> void:
	var id: String = Catalog.CHARACTERS[preview_idx]["id"]
	if owned.has(id):
		_select_character(id)
		_sfx("click")
	elif try_buy(id):
		_sfx("highscore")
		_refresh_picker()
		_pop_preview()
		return
	else:
		_sfx("hit")
		_shake_price()
	_refresh_picker()


## Bought: the character lights up with a little bounce.
func _pop_preview() -> void:
	var base := Vector2(4, 4)
	preview.modulate = Color(2.0, 2.0, 2.0)
	var tw := preview.create_tween().set_parallel()
	tw.tween_property(preview, "scale", base * 1.35, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(preview, "modulate", Color.WHITE, 0.45)
	tw.chain().tween_property(preview, "scale", base, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Not enough points: the price shakes and flashes red.
func _shake_price() -> void:
	var row := price_label.get_parent() as Control
	var x := 0.0 # the price row spans the screen width, so it rests at x = 0
	row.modulate = Color(1.0, 0.35, 0.35)
	var tw := row.create_tween()
	for dx: float in [-18.0, 18.0, -12.0, 12.0, -6.0, 0.0]:
		tw.tween_property(row, "position:x", x + dx, 0.04)
	tw.tween_property(row, "modulate", Color.WHITE, 0.2)


func _make_corner_label(text: String, font_size: int, pos: Vector2) -> Label:
	var l := _make_label(hud, text, font_size, pos.y)
	l.position.x = pos.x
	l.custom_minimum_size = Vector2(300, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


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


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	mute_slash.visible = muted
	mute_btn.modulate.a = 0.6 if muted else 1.0


func _toggle_mute() -> void:
	muted = not muted
	_apply_mute()
	_save()
	if not muted:
		_sfx("click")


# ---------------------------------------------------------------- save

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = int(cfg.get_value("game", "best", 0))
		best_zone = int(cfg.get_value("game", "best_zone", 0))
		muted = bool(cfg.get_value("settings", "muted", false))
		wallet = int(cfg.get_value("shop", "wallet", 0))
		owned.assign(cfg.get_value("shop", "owned", ["ninja_frog"]))
		selected = str(cfg.get_value("shop", "selected", "ninja_frog"))
	if not owned.has(selected):
		selected = "ninja_frog"


func _save() -> void:
	if god_mode or not save_enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.set_value("game", "best_zone", best_zone)
	cfg.set_value("settings", "muted", muted)
	cfg.set_value("shop", "wallet", wallet)
	cfg.set_value("shop", "owned", owned)
	cfg.set_value("shop", "selected", selected)
	cfg.save(SAVE_PATH)


# ---------------------------------------------------------------- flow

func _show_title() -> void:
	mode = Mode.TITLE
	_reset_player()
	_enter_zone(0, true)
	hud.visible = false
	over_screen.visible = false
	_hide_banner()
	preview_idx = Catalog.character_index(selected)
	_refresh_picker()
	best_label.text = str(best)
	(best_label.get_parent() as Control).visible = best > 0
	_fill_zone_dots(title_dots, best_zone)
	(title_dots[0].get_parent() as Control).visible = best > 0
	title_screen.visible = true
	dim.visible = true
	_play_music(music_title)


func _start_game() -> void:
	_sfx("click")
	for c in world.get_children():
		c.queue_free()
	for c in fx.get_children():
		c.queue_free()
	distance = 0.0
	since_row = 0.0
	combo = 0
	fruit_count = 0
	fruit_points = 0
	banked = 0
	continues_used = 0
	invuln = 0.0
	player.modulate.a = 1.0
	score = 0
	speed = BASE_SPEED
	buffered = false
	_reset_player()
	_enter_zone(0, true)
	mode = Mode.PLAY
	score_label.text = "0"
	fruit_label.text = "0"
	combo_label.visible = false
	hud.visible = true
	title_screen.visible = false
	over_screen.visible = false
	dim.visible = false
	_play_music(music_level)


func _reset_player() -> void:
	flying = false
	on_left = true
	player.rotation = 0.0
	player.position = Vector2(CLING_L, PLAYER_Y)
	player.flip_h = false
	player.play("wall")


## Switches the look and hazard mix. `instant` skips the banner and breather.
func _enter_zone(z: int, instant: bool) -> void:
	zone = z
	var data: Dictionary = Zones.LIST[z]
	var tex: Texture2D = bg_textures[data["bg"]]
	var bg_tint: Color = data["bg_tint"]
	var wall_tint: Color = data["wall_tint"]
	if instant:
		bg.texture = tex
		bg.modulate = bg_tint
		bg_next.modulate.a = 0.0
		wall_l.modulate = wall_tint
		wall_r.modulate = wall_tint
		return
	since_row = -BREATHER
	bg_next.texture = tex
	bg_next.modulate = Color(bg_tint, 0.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(bg_next, "modulate:a", 1.0, 0.8)
	tw.tween_property(wall_l, "modulate", wall_tint, 0.8)
	tw.tween_property(wall_r, "modulate", wall_tint, 0.8)
	tw.chain().tween_callback(_finish_bg_swap.bind(tex, bg_tint))
	_show_banner("ZONE %d" % (z + 1), data["name"])
	_sfx("highscore")


func _finish_bg_swap(tex: Texture2D, tint: Color) -> void:
	bg.texture = tex
	bg.modulate = tint
	bg_next.modulate.a = 0.0


func _show_banner(small: String, big: String) -> void:
	_hide_banner()
	banner_small.text = small
	banner_big.text = big
	for l: Label in [banner_small, banner_big]:
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.25)
		tw.tween_interval(1.3)
		tw.tween_property(l, "modulate:a", 0.0, 0.4)
		banner_tweens.append(tw)


## Removes the zone banner at once (so it never covers the game over screen).
func _hide_banner() -> void:
	for tw in banner_tweens:
		tw.kill()
	banner_tweens.clear()
	banner_small.modulate.a = 0.0
	banner_big.modulate.a = 0.0


func _die() -> void:
	if god_mode:
		god_hits += 1
		return
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
	best_zone = maxi(best_zone, zone)
	wallet += fruit_points - banked
	banked = fruit_points
	_save()
	get_tree().create_timer(0.7).timeout.connect(_show_game_over.bind(is_best))


## Restart on the left, continue (with its price) on the right. Without any
## continue left, restart sits alone in the middle.
func _layout_over_buttons() -> void:
	var cost := continue_cost()
	var cost_row := continue_cost_label.get_parent() as HBoxContainer
	continue_icon.visible = cost >= 0
	cost_row.visible = cost >= 0
	if cost < 0:
		restart_icon.position.x = W * 0.5
		return
	restart_icon.position.x = W * 0.5 - 150.0
	continue_icon.position.x = W * 0.5 + 150.0
	# Centre the price under the continue icon (the row spans the screen width).
	cost_row.position.x = 150.0
	continue_cost_label.text = str(cost)
	var can_pay := wallet >= cost
	continue_icon.modulate = Color.WHITE if can_pay else Color(0.45, 0.45, 0.45)
	continue_cost_label.add_theme_color_override("font_color", GOLD if can_pay else Color(0.6, 0.6, 0.6))


func _button_rect(icon: Sprite2D) -> Rect2:
	return Rect2(icon.position - Vector2.ONE * BUTTON_SIZE * 0.5, Vector2.ONE * BUTTON_SIZE)


## Price of the next continue in this run, or -1 if no continue is left.
func continue_cost() -> int:
	if continues_used >= CONTINUE_COSTS.size():
		return -1
	return CONTINUE_COSTS[continues_used]


## Pays for a continue and resumes the run where it ended. Returns true on success.
func try_continue() -> bool:
	var cost := continue_cost()
	if mode != Mode.DEAD or cost < 0 or wallet < cost:
		return false
	wallet -= cost
	continues_used += 1
	_save()
	_revive()
	return true


## Back into the same run: same score, zone and distance; the screen is cleared,
## the next hazards come after a breather and the player is briefly protected.
func _revive() -> void:
	for c in world.get_children():
		c.queue_free()
	since_row = -BREATHER
	combo = 0
	combo_label.visible = false
	flying = false
	buffered = false
	player.rotation = 0.0
	player.position = Vector2(_cling_x(on_left), PLAYER_Y)
	player.flip_h = not on_left
	player.play("wall")
	invuln = INVULN_TIME
	mode = Mode.PLAY
	over_screen.visible = false
	dim.visible = false
	hud.visible = true
	_play_music(music_level)


func _on_continue_pressed() -> void:
	if Time.get_ticks_msec() < tap_lock_until or not continue_icon.visible:
		return
	if try_continue():
		_sfx("highscore")
	else:
		_sfx("hit")


func _show_game_over(is_best: bool) -> void:
	if mode != Mode.DEAD:
		return
	dim.visible = true
	hud.visible = false
	_hide_banner()
	result_label.text = str(score)
	new_best_label.visible = is_best
	over_best_label.text = str(best)
	(over_best_label.get_parent() as Control).visible = not is_best
	_fill_zone_dots(over_dots, zone)
	earned_label.text = "+%d" % fruit_points
	_layout_over_buttons()
	over_screen.visible = true
	if is_best:
		_sfx("highscore")


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if MUTE_RECT.has_point(mb.position):
				_toggle_mute()
				get_viewport().set_input_as_handled()
				return
			if mode == Mode.TITLE and _picker_click(mb.position):
				get_viewport().set_input_as_handled()
				return
			if mode == Mode.DEAD:
				if BACK_RECT.has_point(mb.position):
					_back_to_title()
				elif continue_icon.visible and _button_rect(continue_icon).has_point(mb.position):
					_on_continue_pressed()
				elif _button_rect(restart_icon).has_point(mb.position):
					_on_tap()
				get_viewport().set_input_as_handled()
				return
			pressed = true
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_M:
				_toggle_mute()
				return
			if mode == Mode.DEAD and (k.keycode == KEY_ESCAPE or k.keycode == KEY_BACKSPACE):
				_back_to_title()
				return
			if mode == Mode.DEAD and k.keycode == KEY_C:
				_on_continue_pressed()
				return
			if mode == Mode.TITLE:
				match k.keycode:
					KEY_LEFT:
						_browse(-1)
						return
					KEY_RIGHT:
						_browse(1)
						return
					KEY_B:
						_on_buy_pressed()
						return
			pressed = k.keycode == KEY_SPACE or k.keycode == KEY_ENTER
	if pressed:
		_on_tap()


## Handles taps on the title screen picker. Returns true if the tap was used.
func _picker_click(pos: Vector2) -> bool:
	if PREV_RECT.has_point(pos):
		_browse(-1)
	elif NEXT_RECT.has_point(pos):
		_browse(1)
	elif BUY_RECT.has_point(pos):
		_on_buy_pressed()
	else:
		return false
	return true


func _on_tap() -> void:
	match mode:
		Mode.TITLE:
			_start_game()
		Mode.PLAY:
			if flying:
				if fly_t > 0.5:
					buffered = true
			else:
				_begin_jump()
		Mode.DEAD:
			if Time.get_ticks_msec() >= tap_lock_until:
				_start_game()


## Game over -> title screen (where the character shop is).
func _back_to_title() -> void:
	if Time.get_ticks_msec() < tap_lock_until:
		return
	_sfx("click")
	_show_title()


func _begin_jump() -> void:
	flying = true
	buffered = false
	fly_t = 0.0
	fly_from = player.position.x
	on_left = not on_left
	fly_to = CLING_L if on_left else CLING_R
	player.flip_h = on_left
	player.play("spin")
	trail_timer = 0.0
	_sfx("jump")


func _land() -> void:
	flying = false
	player.position = Vector2(fly_to, PLAYER_Y)
	player.flip_h = not on_left
	player.play("wall")
	_sfx("wall_jump")
	_spawn_dust()
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
	var y := -64.0 * S + fmod(bg_scroll, 64.0 * S)
	bg.position.y = y
	bg_next.position.y = y
	wall_l.position.y = -TILE + fmod(scroll, TILE)
	wall_r.position.y = wall_l.position.y


func meters() -> float:
	return distance / Zones.METERS_PX


func _update_play(delta: float) -> void:
	speed = BASE_SPEED + minf(distance * 0.025, MAX_EXTRA_SPEED)
	var dy := speed * delta
	distance += dy
	_scroll(speed, delta)
	score = int(meters()) + fruit_points
	score_label.text = str(score)
	_update_invuln(delta)

	var z := Zones.index_at(meters())
	if z != zone:
		_enter_zone(z, false)

	if flying:
		fly_t += delta / FLY_TIME
		var t := minf(fly_t, 1.0)
		player.position.x = lerpf(fly_from, fly_to, t)
		player.position.y = PLAYER_Y - sin(t * PI) * ARC
		trail_timer -= delta
		if trail_timer <= 0.0:
			trail_timer = TRAIL_EVERY
			_spawn_ghost()
		if fly_t >= 1.0:
			_land()

	since_row += dy
	var gap := lerpf(460.0, 340.0, clampf(distance / 20000.0, 0.0, 1.0))
	if since_row >= gap:
		since_row = -_spawn_pattern(Zones.pick_pattern(zone), -100.0)

	for c in fx.get_children():
		(c as Node2D).position.y += dy

	for c in world.get_children():
		var h := c as Hazard
		if h.is_queued_for_deletion():
			continue
		h.tick(delta, dy)
		if h.position.y > H + 400.0:
			h.queue_free()
			continue
		if h.kind == "fruit" and not h.passed and h.position.y > PLAYER_Y + 120.0:
			h.passed = true
			_break_combo()
		if h.touches(player.position, PLAYER_R):
			if h.kind == "fruit":
				_collect(h)
			elif h.is_deadly() and invuln <= 0.0:
				_die()
				if mode != Mode.PLAY:
					return


## Blinks the player while the post-continue protection lasts.
func _update_invuln(delta: float) -> void:
	if invuln <= 0.0:
		return
	invuln = maxf(0.0, invuln - delta)
	player.modulate.a = 1.0 if invuln <= 0.0 or int(invuln * 10.0) % 2 == 0 else 0.35


func _update_dead(delta: float) -> void:
	dead_vel += 2400.0 * delta
	player.position.y += dead_vel * delta
	player.rotation += (9.0 if on_left else -9.0) * delta


## For tests: which walls would kill a player holding them right now.
func deadly_walls() -> Array[bool]:
	var left := false
	var right := false
	for c in world.get_children():
		var h := c as Hazard
		if h.is_queued_for_deletion() or not h.is_deadly():
			continue
		left = left or h.touches(Vector2(CLING_L, PLAYER_Y), PLAYER_R)
		right = right or h.touches(Vector2(CLING_R, PLAYER_Y), PLAYER_R)
	return [left, right]


# ---------------------------------------------------------------- spawning

## Spawns one pattern with its lowest point at `y`. Returns the extra height it
## uses above `y`, so the next row keeps a full gap after it.
func _spawn_pattern(pattern: String, y: float) -> float:
	var left := randf() < 0.5
	match pattern:
		"saw":
			_spawn_saw(left, y)
		"spikes":
			_spawn_spikes(left, y)
		"fruit":
			_spawn_fruit(Vector2(_cling_x(left), y))
			_spawn_fruit(Vector2(_cling_x(left), y - 90.0))
			if randf() < 0.5:
				_spawn_saw(not left, y - 45.0)
			return 90.0
		"saw_slide":
			var amp := 100.0
			_spawn_saw(left, y - amp, amp)
			return amp * 2.0
		"zigzag":
			_spawn_saw(left, y)
			_spawn_saw(not left, y - 300.0)
			return 300.0
		"fire":
			_spawn_fire(left, y, randf() * Hazard.FIRE_PERIOD)
			_spawn_fruit(Vector2(_cling_x(left), y))
		"fire_dual":
			var ph := randf() * Hazard.FIRE_PERIOD
			_spawn_fire(true, y, ph)
			_spawn_fire(false, y, ph + Hazard.FIRE_PERIOD * 0.5)
		"ball":
			_spawn_ball(y - 230.0)
			return 230.0
		"fruit_trail":
			# Fruit scattered at random down the middle: hop back and forth to collect it.
			var n := randi_range(4, 6)
			var lo := W * 0.5 - TRAIL_HALF_WIDTH
			var hi := W * 0.5 + TRAIL_HALF_WIDTH
			var fy := y
			var last_x := randf_range(lo, hi)
			for i in n:
				var x := last_x
				if i > 0:
					# Keep neighbours apart so it never collapses into a straight column.
					x = randf_range(lo, hi)
					if absf(x - last_x) < TRAIL_MIN_STEP_X:
						var dir := 1.0 if last_x < W * 0.5 else -1.0
						x = clampf(last_x + dir * randf_range(TRAIL_MIN_STEP_X, TRAIL_HALF_WIDTH * 2.0), lo, hi)
					fy -= randf_range(120.0, 220.0)
				_spawn_fruit(Vector2(x, fy))
				last_x = x
			return y - fy
		"fireball":
			_spawn_fireball(y)
		"sky_fruit":
			for i in 3:
				_spawn_fruit(Vector2(W * 0.5 + (i - 1) * 90.0, y - absf(i - 1) * 30.0))
			return 30.0
		_:
			push_error("Unknown pattern: %s" % pattern)
	return 0.0


func _cling_x(left: bool) -> float:
	return CLING_L if left else CLING_R


func _make_hazard(kind: String, pos: Vector2, r: float) -> Hazard:
	var h := Hazard.new()
	h.kind = kind
	h.position = pos
	h.r = r
	world.add_child(h)
	return h


func _spawn_saw(left: bool, y: float, slide_amp: float = 0.0) -> void:
	var x := (WALL_W + 30.0) if left else (W - WALL_W - 30.0)
	var h := _make_hazard("saw", Vector2(x, y), 34.0)
	if slide_amp > 0.0:
		h.motion = Hazard.Motion.SLIDE
		h.amp = slide_amp
		h.period = randf_range(1.4, 1.9)
		h.phase = randf() * h.period
		var step := 24.0
		var n := int(slide_amp * 2.0 / step)
		for i in n + 1:
			var dot := Sprite2D.new()
			dot.texture = saw_chain_tex
			dot.scale = Vector2(S, S)
			dot.position = Vector2(0, -slide_amp + i * step)
			h.add_child(dot)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = saw_frames
	s.scale = Vector2(2.4, 2.4)
	s.play("spin")
	h.add_child(s)
	h.body = s
	h.tick(0.0, 0.0)


func _spawn_spikes(left: bool, y: float) -> void:
	var x := (WALL_W + 24.0) if left else (W - WALL_W - 24.0)
	var h := _make_hazard("spike", Vector2(x, y), 22.0)
	h.half_len = TILE
	for i in 3:
		var sp := Sprite2D.new()
		sp.texture = spike_tex
		sp.scale = Vector2(S, S)
		sp.rotation_degrees = 90.0 if left else -90.0
		sp.position = Vector2(0, (i - 1) * TILE)
		h.add_child(sp)


func _spawn_fire(left: bool, y: float, phase: float) -> void:
	var x := (WALL_W + 24.0) if left else (W - WALL_W - 24.0)
	var h := _make_hazard("fire", Vector2(x, y), 22.0)
	h.motion = Hazard.Motion.FIRE
	h.half_len = TILE
	h.hit_offset = Vector2(24.0 if left else -24.0, 0)
	h.phase = phase
	for i in 3:
		var f := AnimatedSprite2D.new()
		f.sprite_frames = fire_frames
		f.scale = Vector2(S, S)
		f.rotation_degrees = 90.0 if left else -90.0
		f.position = Vector2(0, (i - 1) * TILE)
		h.add_child(f)
		h.flames.append(f)
	h.tick(0.0, 0.0)


func _spawn_ball(y: float) -> void:
	var h := _make_hazard("ball", Vector2(W * 0.5, y), 30.0)
	h.motion = Hazard.Motion.SWING
	h.length = 190.0
	h.amp = deg_to_rad(50.0)
	h.period = randf_range(1.6, 2.1)
	h.phase = randf() * h.period
	var anchor := Sprite2D.new()
	anchor.texture = ball_chain_tex
	anchor.scale = Vector2(S, S)
	h.add_child(anchor)
	for i in 6:
		var link := Sprite2D.new()
		link.texture = ball_chain_tex
		link.scale = Vector2(S, S)
		h.add_child(link)
		h.chain.append(link)
	var b := Sprite2D.new()
	b.texture = ball_tex
	b.scale = Vector2(2.4, 2.4)
	h.add_child(b)
	h.body = b
	h.tick(0.0, 0.0)


## A fireball bouncing wall to wall between two launchers. It can hit a player
## holding either wall, but only one wall at a time.
func _spawn_fireball(y: float) -> void:
	var h := _make_hazard("fireball", Vector2(W * 0.5, y), 20.0)
	h.motion = Hazard.Motion.SHOOT
	h.amp = W * 0.5 - WALL_W - 24.0
	h.period = randf_range(0.95, 1.25)
	h.phase = randf() * h.period * 2.0
	for left: bool in [true, false]:
		var base := Sprite2D.new()
		base.texture = launcher_tex
		base.scale = Vector2(S, S)
		base.rotation_degrees = 90.0 if left else -90.0
		base.position = Vector2((-1.0 if left else 1.0) * (W * 0.5 - WALL_W - 12.0), 0)
		h.add_child(base)
	# Soft additive glow behind the flame.
	var glow := Sprite2D.new()
	glow.texture = glow_tex
	glow.material = additive
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	h.add_child(glow)
	h.glow = glow
	# Embers left behind in world space: they rise and fade as the ball moves on.
	var trail := CPUParticles2D.new()
	trail.local_coords = false
	trail.amount = 60
	trail.lifetime = 0.45
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 10.0
	trail.spread = 180.0
	trail.gravity = Vector2(0, -140)
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 45.0
	trail.scale_amount_min = 8.0
	trail.scale_amount_max = 15.0
	trail.scale_amount_curve = shrink_curve
	trail.color_ramp = ember_ramp
	h.add_child(trail)
	var ball := AnimatedSprite2D.new()
	ball.sprite_frames = fireball_frames
	ball.scale = Vector2(S, S)
	ball.play("fly")
	h.add_child(ball)
	h.body = ball
	# Burst of sparks each time the ball touches a wall.
	var sparks := CPUParticles2D.new()
	sparks.local_coords = false
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 14
	sparks.lifetime = 0.35
	sparks.spread = 70.0
	sparks.gravity = Vector2(0, 500)
	sparks.initial_velocity_min = 140.0
	sparks.initial_velocity_max = 300.0
	sparks.scale_amount_min = 4.0
	sparks.scale_amount_max = 7.0
	sparks.scale_amount_curve = shrink_curve
	sparks.color_ramp = spark_ramp
	h.add_child(sparks)
	h.sparks = sparks
	h.followers.assign([glow, trail])
	h.tick(0.0, 0.0)


func _spawn_fruit(pos: Vector2) -> void:
	var key := Catalog.pick_fruit()
	var h := _make_hazard("fruit", pos, 34.0)
	h.value = int(Catalog.FRUITS[key]["points"])
	var f := AnimatedSprite2D.new()
	f.sprite_frames = fruit_frames[key]
	f.scale = Vector2(2.5, 2.5)
	f.play("spin")
	h.add_child(f)


# ---------------------------------------------------------------- fruit and effects

func _collect(fruit: Hazard) -> void:
	combo = mini(combo + 1, MAX_COMBO)
	fruit_count += 1
	var pts := fruit.value * combo
	fruit_points += pts
	fruit_label.text = str(fruit_points)
	_sfx("fruit")
	var pop := AnimatedSprite2D.new()
	pop.sprite_frames = collected_frames
	pop.scale = Vector2(2.5, 2.5)
	pop.position = fruit.position
	fx.add_child(pop)
	pop.play("pop")
	pop.animation_finished.connect(pop.queue_free)
	_float_text("+%d" % pts, fruit.position)
	if combo >= 2:
		combo_label.text = "COMBO x%d" % combo
		combo_label.visible = true
	fruit.queue_free()


func _break_combo() -> void:
	combo = 0
	combo_label.visible = false


func _float_text(text: String, pos: Vector2) -> void:
	var holder := Node2D.new()
	holder.position = pos
	fx.add_child(holder)
	var l := Label.new()
	l.text = text
	l.position = Vector2(-60, -60)
	l.custom_minimum_size = Vector2(120, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	l.add_theme_constant_override("outline_size", 6)
	holder.add_child(l)
	var tw := holder.create_tween().set_parallel()
	tw.tween_property(l, "position:y", -130.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(holder.queue_free)


## Afterimage of the player while hopping, tinted with the character's colour.
func _spawn_ghost() -> void:
	var g := Sprite2D.new()
	g.texture = player.sprite_frames.get_frame_texture(player.animation, player.frame)
	g.flip_h = player.flip_h
	g.scale = player.scale
	g.position = player.position
	var trail: Color = Catalog.character(selected)["trail"]
	g.modulate = Color(trail, 0.55)
	fx.add_child(g)
	var tw := g.create_tween().set_parallel()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_property(g, "scale", player.scale * 0.8, 0.22)
	tw.chain().tween_callback(g.queue_free)


func _spawn_dust() -> void:
	var side := -1.0 if on_left else 1.0
	var origin := Vector2(player.position.x + side * 30.0, PLAYER_Y + 20.0)
	for i in 4:
		var d := Sprite2D.new()
		d.texture = dust_tex
		d.scale = Vector2(1.5, 1.5)
		d.position = origin + Vector2(0, randf_range(-20.0, 20.0))
		fx.add_child(d)
		var target := d.position + Vector2(-side * randf_range(20.0, 50.0), randf_range(-40.0, 10.0))
		var tw := d.create_tween().set_parallel()
		tw.tween_property(d, "position", target, 0.35)
		tw.tween_property(d, "scale", Vector2(2.5, 2.5), 0.35)
		tw.tween_property(d, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(d.queue_free)
