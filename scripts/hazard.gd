extends Node2D
## One scrolling object in the world: a hazard or a fruit.
## Hit shape: a vertical capsule around hit_center() with radius `r` and half height `half_len`.

enum Motion { NONE, SLIDE, SWING, FIRE, SHOOT }

const FIRE_PERIOD := 2.4
const FIRE_WARN := 0.35 # flicker time before burning; longer than a hop (0.28 s)
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
			# Bounces wall to wall; the flame tail points away from the direction of travel.
			var k := fposmod(c / period, 2.0)
			var to_right := k < 1.0
			body.position.x = lerpf(-amp, amp, k if to_right else 2.0 - k)
			body.rotation_degrees = -90.0 if to_right else 90.0


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
