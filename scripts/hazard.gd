extends Node2D
## One scrolling object in the world: a hazard or a fruit.
## Hit shape: a vertical capsule around hit_center() with radius `r` and half height `half_len`.

enum Motion { NONE, SLIDE, SWING, FIRE, SHOOT }

const FIRE_PERIOD := 2.4
const FIRE_WARN := 0.45 # flicker time before burning; longer than a hop (0.36 s)
const FIRE_BURN := 0.85

var kind := "" # saw, spike, fire, ball, fruit
var r := 0.0
var half_len := 0.0
var motion: Motion = Motion.NONE
var body: Node2D # the part that moves and gets hit
var hit_offset := Vector2.ZERO
var amp := 0.0 # SLIDE / SHOOT: pixels, SWING: radians
var period := 1.0 # SHOOT: seconds for one crossing
var phase := 0.0 # seconds added to the clock
var length := 0.0 # SWING: chain length
var chain: Array[Node2D] = []
var flames: Array[AnimatedSprite2D] = []
var burning := false
var passed := false # fruit: already went below the player
var value := 0 # fruit: base points
var followers: Array[Node2D] = [] # SHOOT: nodes that stay on the fireball (glow, trail)
var glow: Node2D
var sparks: CPUParticles2D
var last_dir := 0.0
var clock := 0.0


## Moves the object down by `dy` and advances its own animation.
func tick(delta: float, dy: float) -> void:
	position.y += dy
	clock += delta
	var c := clock + phase
	match motion:
		Motion.SLIDE:
			body.position.y = sin(TAU * c / period) * amp
		Motion.SWING:
			var a := sin(TAU * c / period) * amp
			var dir := Vector2(sin(a), cos(a))
			body.position = dir * length
			for i in chain.size():
				chain[i].position = dir * length * float(i + 1) / float(chain.size() + 1)
		Motion.FIRE:
			_update_fire(fposmod(c, FIRE_PERIOD))
		Motion.SHOOT:
			# Glides wall to wall, easing in and out at each wall (one crossing per period).
			var u := PI * c / period
			body.position.x = -cos(u) * amp
			var v := sin(u) # > 0 while moving right
			# The flame tail trails behind; it stands upright for a moment when turning.
			body.rotation_degrees = -90.0 * clampf(v * 1.6, -1.0, 1.0)
			for f in followers:
				f.position = body.position
			if glow:
				glow.scale = Vector2.ONE * (1.0 + 0.12 * sin(clock * 18.0))
			var dir := signf(v)
			if sparks and last_dir != 0.0 and dir != last_dir:
				# Just touched a wall: burst of sparks bouncing back towards the middle.
				sparks.position = body.position + Vector2(-dir * 22.0, 0)
				sparks.direction = Vector2(dir, 0)
				sparks.restart()
			last_dir = dir


func _update_fire(t: float) -> void:
	var anim := &"off"
	if t < FIRE_WARN:
		anim = &"warn"
	elif t < FIRE_WARN + FIRE_BURN:
		anim = &"on"
	burning = anim == &"on"
	for f in flames:
		if f.animation != anim:
			f.play(anim)


func hit_center() -> Vector2:
	var p := position + hit_offset
	if body:
		p += body.position
	return p


func is_deadly() -> bool:
	if kind == "fruit":
		return false
	if motion == Motion.FIRE:
		return burning
	return true


func touches(p: Vector2, pr: float) -> bool:
	var c := hit_center()
	var dx := p.x - c.x
	var dy := maxf(0.0, absf(p.y - c.y) - half_len)
	var rr := r + pr
	return dx * dx + dy * dy < rr * rr
