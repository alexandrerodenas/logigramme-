class_name WorldBackground
extends Control
## Décor animé d'un monde : dégradé de ciel, collines et icônes qui flottent.

var world := 0
var intensity := 1.0   # 1 = décor complet, plus bas = plus discret (écran de jeu)
var _items: Array = []
var _t := 0.0


func _init(w: int = 0, k: float = 1.0) -> void:
	world = w
	intensity = k
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + world
	var decor: Array = Worlds.WORLDS[world].decor
	var count := int(14 * intensity)
	for i in count:
		_items.append({
			"icon": decor[rng.randi_range(0, decor.size() - 1)],
			"x": rng.randf(), "y": rng.randf(),
			"s": rng.randf_range(36, 70), "ph": rng.randf() * TAU, "sp": rng.randf_range(0.4, 1.0),
			"a": rng.randf_range(0.35, 0.7) * intensity,
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	var sky := Worlds.color(world, "sky")
	var ground := Worlds.color(world, "ground")
	if intensity < 1.0:
		sky = sky.lerp(UI.CREAM, 0.55)
		ground = ground.lerp(UI.CREAM, 0.7)
	var steps := 24
	for i in steps:
		var c := sky.lerp(ground, float(i) / (steps - 1))
		draw_rect(Rect2(0, sz.y * i / steps, sz.x, sz.y / steps + 1), c)
	# Collines douces en bas.
	var dark: bool = Worlds.WORLDS[world].get("dark", false)
	for layer in 2:
		var pts := PackedVector2Array()
		var base := sz.y * (0.86 + 0.06 * layer)
		for x in range(0, int(sz.x) + 41, 40):
			pts.append(Vector2(x, base + sin(x * 0.012 + layer * 2.0 + _t * 0.15) * 26))
		pts.append(Vector2(sz.x + 40, sz.y))
		pts.append(Vector2(0, sz.y))
		var col := Worlds.color(world, "accent").lightened(0.45 - layer * 0.15)
		col.a = (0.35 if not dark else 0.5) * intensity
		draw_colored_polygon(pts, col)
	if dark:
		for i in 40:
			var px := fmod(i * 97.3, sz.x)
			var py := fmod(i * 53.7, sz.y * 0.7)
			var tw := 0.5 + 0.5 * sin(_t * 2.0 + i)
			draw_circle(Vector2(px, py), 1.5 + tw, Color(1, 1, 1, 0.3 + 0.5 * tw))
	for it in _items:
		var tex := UI.icon(it.icon)
		if tex == null:
			continue
		var s: float = it.s
		var p := Vector2(it.x * sz.x, it.y * sz.y + sin(_t * it.sp + it.ph) * 10.0)
		draw_set_transform(p, sin(_t * 0.5 * it.sp + it.ph) * 0.15)
		draw_texture_rect(tex, Rect2(-s / 2, -s / 2, s, s), false, Color(1, 1, 1, it.a))
	draw_set_transform(Vector2.ZERO)
