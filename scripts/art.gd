extends RefCounted
## Small helpers for turning Pixel Adventure sprite sheets into Godot frames.


## Cuts a horizontal sprite sheet into AtlasTexture frames.
static func frames_from_sheet(path: String, frame_w: int, frame_h: int) -> Array[AtlasTexture]:
	var sheet: Texture2D = load(path)
	var out: Array[AtlasTexture] = []
	var count := int(float(sheet.get_width()) / float(frame_w))
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		out.append(atlas)
	return out


## anims: { "name": { "path": String, "w": int, "h": int, "fps": float, "loop": bool } }
static func build(anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim_name: String in anims:
		var d: Dictionary = anims[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, d.get("fps", 20.0))
		sf.set_animation_loop(anim_name, d.get("loop", true))
		for tex in frames_from_sheet(d["path"], d["w"], d["h"]):
			sf.add_frame(anim_name, tex)
	return sf
