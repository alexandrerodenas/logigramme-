class_name LevelNode
extends Control
## Pastille d'un niveau sur le parcours : numéro, étoiles, cadenas ou coffre.

signal tapped(w: int, l: int)

const R := 46.0

var w := 0
var l := 1
var stars := 0
var unlocked := false
var current := false
var accent := Color.WHITE
var _t := 0.0
var _press := Vector2.ZERO
var mods: Array = []
var boss := false


func _init(world: int, level: int) -> void:
	w = world
	l = level
	custom_minimum_size = Vector2(R * 2 + 20, R * 2 + 40)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_PASS


func refresh() -> void:
	stars = Game.level_stars(w, l)
	unlocked = Game.is_level_unlocked(w, l)
	accent = Worlds.color(w, "accent")
	mods = Worlds.level_mods(w, l)
	boss = Worlds.is_boss(l)
	queue_redraw()


func _process(delta: float) -> void:
	if current:
		_t += delta
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.global_position
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(0.9, 0.9), 0.06)
		else:
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if Rect2(Vector2.ZERO, size).has_point(e.position) and e.global_position.distance_to(_press) < 24:
				tapped.emit(w, l)


func _draw() -> void:
	var c := Vector2(size.x / 2.0, R + 6)
	var solved := stars > 0
	var col := accent if unlocked else Color("b9b0c2")
	if solved:
		col = accent.lightened(0.1)
	if boss:
		# Grande énigme : halo doré et couronne.
		draw_circle(c, R + 14, Color(1.0, 0.8, 0.25, 0.9 if unlocked else 0.45))
		draw_circle(c, R + 9, Color("fff3c4"))
	if current:
		var k := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(c, R + 10 + 6 * k, Color(1, 1, 1, 0.35 + 0.25 * k))
	draw_circle(c + Vector2(0, 7), R, col.darkened(0.3))
	draw_circle(c, R, col)
	draw_circle(c, R - 7, col.lightened(0.18))
	draw_circle(c + Vector2(-R * 0.3, -R * 0.35), R * 0.18, Color(1, 1, 1, 0.35))
	var f := UI.font(700)
	if unlocked:
		var txt := str(l)
		var fs := 40
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, c + Vector2(-tw / 2.0, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, col.darkened(0.35))
		draw_string(f, c + Vector2(-tw / 2.0, 14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	else:
		var lock := UI.icon("lock")
		if lock:
			draw_texture_rect(lock, Rect2(c - Vector2(24, 24), Vector2(48, 48)), false)
	if boss:
		var crown := UI.icon("crown")
		draw_texture_rect(crown, Rect2(c + Vector2(-26, -R - 46), Vector2(52, 52)), false)
	for i in mods.size():
		var tex := UI.icon(Worlds.MODS[mods[i]].icon)
		var bc := c + Vector2(R * 0.78 + i * 6, -R * 0.78 + i * 30)
		draw_circle(bc, 19, Color.WHITE)
		draw_circle(bc, 17, Color(Worlds.MODS[mods[i]].color))
		draw_texture_rect(tex, Rect2(bc - Vector2(12, 12), Vector2(24, 24)), false)
	if solved:
		var star := UI.icon("star")
		for i in 3:
			var p := c + Vector2((i - 1) * 30, R + 12 + (-6 if i == 1 else 0))
			draw_texture_rect(star, Rect2(p - Vector2(15, 15), Vector2(30, 30)), false,
				Color.WHITE if i < stars else Color(0.3, 0.25, 0.35, 0.35))
