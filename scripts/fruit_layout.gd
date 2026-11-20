extends RefCounted
## Fruit layouts that look hand-placed but come out different every time.
## Every function returns points ordered bottom to top (the order they are eaten).

const GOLDEN_ANGLE := 2.39996 # radians; spreads cluster points evenly, never in rows


## Random walk up a band: each fruit is 120-220 px above the previous one and at
## least `min_dx` to the side, so the trail never lines up into a column.
static func scatter(n: int, lo: float, hi: float, y: float, min_dx: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var x := randf_range(lo, hi)
	var fy := y
	for i in n:
		if i > 0:
			var nx := randf_range(lo, hi)
			if absf(nx - x) < min_dx:
				var dir := 1.0 if x < (lo + hi) * 0.5 else -1.0
				nx = clampf(x + dir * randf_range(min_dx, hi - lo), lo, hi)
			x = nx
			fy -= randf_range(120.0, 220.0)
		pts.append(Vector2(x, fy))
	return pts


## A gentle snake: a sine curve with random phase, bend and width, plus a little
## jitter so it does not look drawn with a ruler.
static func wave(n: int, cx: float, half_w: float, y: float, step: float, lo: float, hi: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var phase := randf() * TAU
	var bend := randf_range(0.7, 1.2) # radians per fruit
	for i in n:
		var x := cx + sin(phase + i * bend) * half_w + randf_range(-10.0, 10.0)
		var fy := y - i * step + (randf_range(-12.0, 12.0) if i > 0 else 0.0)
		pts.append(Vector2(clampf(x, lo, hi), fy))
	return pts


## Sunflower cluster: points on a golden-angle spiral, evenly spread like seeds.
static func cluster(center: Vector2, n: int, radius: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var turn := randf() * TAU
	for i in n:
		var rr := radius * sqrt((float(i) + 0.5) / float(n))
		var a := turn + i * GOLDEN_ANGLE
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	return pts


## Fruit along the path of one hop. Hop from `from_x` when the anchor height `y`
## reaches the player and every fruit meets the player in the air.
## `ts` are hop progress values (0..1); speed, fly_time and arc describe the hop.
static func swoop(from_x: float, to_x: float, y: float, ts: Array[float], speed: float, fly_time: float, arc: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for t in ts:
		var x := lerpf(from_x, to_x, t * t * (3.0 - 2.0 * t))
		# A fruit eaten later must start higher: the world moves down while the player flies.
		pts.append(Vector2(x, y - sin(t * PI) * arc - speed * fly_time * t))
	return pts
