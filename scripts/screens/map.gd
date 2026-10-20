extends Control
## Parcours : un chemin sinueux qui traverse les mondes, du Jardin (en bas) à l'Observatoire (en haut).

const STEP := 150.0
const HEADER := 330.0

var main
var params := {}
var _scroll: ScrollContainer
var _map: Control
var _nodes := {}
var _section_h := 0.0
var _total_h := 0.0
var _width := 720.0
var _t := 0.0
var _coins: Control
var _path := PackedVector2Array()


func _ready() -> void:
	_width = get_viewport_rect().size.x
	_section_h = HEADER + Worlds.LEVELS_PER_WORLD * STEP + 60
	_total_h = _section_h * Worlds.world_count() + 140

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(_width, _total_h)
	# Laisse passer les glissements au défilement : sinon la carte consomme l'appui et ne défile plus.
	_map.mouse_filter = Control.MOUSE_FILTER_PASS
	_map.draw.connect(_draw_map)
	_scroll.add_child(_map)

	var focus: Array = params.get("focus", Game.next_level())
	for w in Worlds.world_count():
		for l in range(1, Worlds.LEVELS_PER_WORLD + 1):
			var n := LevelNode.new(w, l)
			n.position = _node_pos(w, l) - Vector2(n.size.x / 2.0, 52)
			n.current = (w == focus[0] and l == focus[1]) and Game.is_level_unlocked(w, l)
			n.refresh()
			n.tapped.connect(_on_node)
			_map.add_child(n)
			_nodes[Vector2i(w, l)] = n
			if l % Worlds.CHEST_EVERY == 0:
				var chest := UI.icon_rect("gift", 62)
				var side := -1.0 if _node_pos(w, l).x > _width / 2.0 else 1.0
				chest.position = _node_pos(w, l) + Vector2(side * 92 - 31, -40)
				chest.modulate = Color(1, 1, 1, 0.4) if Game.is_solved(w, l) else Color.WHITE
				_map.add_child(chest)
				if not Game.is_solved(w, l):
					UI.bob(chest, 6.0, 1.4)
	# Marqueur du joueur au-dessus du niveau courant.
	var marker := UI.icon_rect("detective", 70)
	var mp := _node_pos(focus[0], focus[1])
	marker.position = mp + Vector2(-125 if mp.x > _width / 2.0 else 55, -110)
	_map.add_child(marker)
	UI.bob(marker, 10.0, 1.3)

	_build_top_bar()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var target := _node_pos(focus[0], focus[1]).y - get_viewport_rect().size.y * 0.55
	_scroll.scroll_vertical = int(target + 300)
	create_tween().tween_property(_scroll, "scroll_vertical", int(target), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_announce_worlds()


func _process(delta: float) -> void:
	_t += delta
	_map.queue_redraw()


func back() -> void:
	main.go("home")


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20
	bar.offset_right = -20
	bar.offset_top = 22
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	var home := UI.button("", Color.WHITE, "house", 30, UI.INK)
	home.pressed.connect(back)
	bar.add_child(home)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	_coins = UI.pill("coin", str(Game.coins()))
	bar.add_child(_coins)
	bar.add_child(UI.pill("star", str(Game.total_stars())))


func _section_top(w: int) -> float:
	return _total_h - (w + 1) * _section_h


func _node_pos(w: int, l: int) -> Vector2:
	var bottom := _section_top(w) + _section_h
	var y := bottom - HEADER - 40 - (l - 1) * STEP
	var x := _width / 2.0 + sin(l * 0.9 + w * 1.7) * _width * 0.27
	return Vector2(x, y)


func _draw_map() -> void:
	var font := UI.font(700)
	for w in Worlds.world_count():
		var top := _section_top(w)
		var sky := Worlds.color(w, "sky")
		var ground := Worlds.color(w, "ground")
		var steps := 30
		for i in steps:
			# Le ciel en haut de la section, le sol en bas.
			var c := sky.lerp(ground, float(i) / (steps - 1))
			_map.draw_rect(Rect2(0, top + _section_h * i / steps, _width, _section_h / steps + 1), c)
		if Worlds.WORLDS[w].get("dark", false):
			for i in 70:
				var px := fmod(i * 97.3 + w * 13.0, _width)
				var py := top + fmod(i * 173.7, _section_h)
				var k := 0.5 + 0.5 * sin(_t * 2.0 + i)
				_map.draw_circle(Vector2(px, py), 1.5 + k * 1.5, Color(1, 1, 1, 0.3 + 0.5 * k))
		# Décor : icônes du monde de part et d'autre du chemin.
		var rng := RandomNumberGenerator.new()
		rng.seed = 99 + w
		var decor: Array = Worlds.WORLDS[w].decor
		for i in 22:
			var y := top + 20 + rng.randf() * (_section_h - HEADER - 40)
			var l_near := clampi(int((top + _section_h - HEADER - 40 - y) / STEP) + 1, 1, Worlds.LEVELS_PER_WORLD)
			var path_x := _node_pos(w, l_near).x
			var x := rng.randf_range(30, _width - 30)
			if abs(x - path_x) < 150:
				x = path_x + (170 if x >= path_x else -170)
				if x < 30 or x > _width - 30:
					x = path_x - (x - path_x)
			var s := rng.randf_range(44, 84)
			var tex := UI.icon(decor[rng.randi_range(0, decor.size() - 1)])
			var bobv := sin(_t * 1.2 + i) * 5.0
			if tex:
				_map.draw_texture_rect(tex, Rect2(x - s / 2, y - s / 2 + bobv, s, s), false, Color(1, 1, 1, 0.85))

	# Chemin : ombre, bord, centre clair et pointillés.
	var pts := PackedVector2Array()
	for w in Worlds.world_count():
		for l in range(1, Worlds.LEVELS_PER_WORLD + 1):
			pts.append(_node_pos(w, l))
	if _path.is_empty():
		_path = _smooth(pts)
	var smooth := _path
	_map.draw_polyline(_offset(smooth, Vector2(0, 8)), Color(0, 0, 0, 0.12), 46, true)
	_map.draw_polyline(smooth, Color(0.35, 0.25, 0.2, 0.35), 46, true)
	_map.draw_polyline(smooth, Color("fbefd6"), 36, true)
	var dash := 0
	for i in range(0, smooth.size() - 1, 1):
		dash += 1
		if dash % 4 < 2:
			_map.draw_line(smooth[i], smooth[i + 1], Color("e7c98e"), 8, true)

	# Bannières des mondes, et voile sur les mondes verrouillés.
	for w in Worlds.world_count():
		var top := _section_top(w)
		var world: Dictionary = Worlds.WORLDS[w]
		var locked := not Game.is_world_unlocked(w)
		if locked:
			_map.draw_rect(Rect2(0, top, _width, _section_h - HEADER + 30), Color(0.3, 0.25, 0.35, 0.22))
		var banner := Rect2(60, top + _section_h - HEADER + 90, _width - 120, 150)
		var sb := UI.box(Color(1, 1, 1, 0.92), 40)
		sb.shadow_color = Color(0.2, 0.1, 0.3, 0.18)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 6)
		sb.border_color = Worlds.color(w, "accent")
		sb.set_border_width_all(5)
		_map.draw_style_box(sb, banner)
		var ic := UI.icon(world.icon)
		var bob_y := sin(_t * 2.0 + w) * 6.0
		if ic:
			_map.draw_texture_rect(ic, Rect2(banner.position + Vector2(-30, -50 + bob_y), Vector2(110, 110)), false)
		var title: String = Lang.t(world.name)
		var fs := 46
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := banner.position.x + (banner.size.x - tw) / 2.0 + 20
		_map.draw_string(font, Vector2(tx, banner.position.y + 62), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Worlds.color(w, "accent").darkened(0.2))
		var sub: String
		if locked:
			var need := int(world.stars_needed)
			sub = Lang.t("Finis le monde précédent") + (Lang.t(" et réunis %d étoiles") % need if need > 0 else "")
		else:
			sub = Lang.t("%s  ·  %d/%d étoiles") % [Lang.t(world.tagline), Game.world_stars(w), Worlds.LEVELS_PER_WORLD * 3]
		var f2 := UI.font(500)
		var fs2 := 23
		var sw := f2.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		_map.draw_string(f2, Vector2(banner.position.x + (banner.size.x - sw) / 2.0 + 20, banner.position.y + 108), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, UI.INK_SOFT)
		if locked:
			var lock := UI.icon("lock")
			if lock:
				_map.draw_texture_rect(lock, Rect2(Vector2(banner.end.x - 52, banner.position.y - 34), Vector2(64, 64)), false)


func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	# Courbe de Catmull-Rom passant par chaque niveau.
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0 := pts[max(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[min(i + 2, pts.size() - 1)]
		for k in 12:
			var t := k / 12.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out


func _on_node(w: int, l: int) -> void:
	if not Game.is_level_unlocked(w, l):
		Sfx.play("error")
		var n: Control = _nodes[Vector2i(w, l)]
		var tw := create_tween()
		for i in 3:
			tw.tween_property(n, "rotation", 0.15, 0.05)
			tw.tween_property(n, "rotation", -0.15, 0.05)
		tw.tween_property(n, "rotation", 0.0, 0.05)
		if not Game.is_world_unlocked(w):
			var need := int(Worlds.WORLDS[w].stars_needed)
			main.toast("lock", Lang.t("Quartier verrouillé"), Lang.t("Termine le monde précédent") + (Lang.t(" et réunis %d étoiles.") % need if need > 0 else "."))
		else:
			main.toast("lock", Lang.t("Pas encore !"), Lang.t("Termine d'abord le niveau %d.") % (l - 1))
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var world: Dictionary = Worlds.WORLDS[w]
	var ic := UI.icon_rect(world.icon, 100)
	box.add_child(ic)
	var boss := Worlds.is_boss(l)
	if boss:
		ic.texture = UI.icon("crown")
	var t := UI.label(Lang.t("Grande énigme") if boss else Lang.t("Niveau %d") % l, 48, UI.INK, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var size_arr := Worlds.level_size(w, l)
	var sub := UI.label(Lang.t("%s · %d catégories × %d") % [Lang.t(world.name), size_arr[0], size_arr[1]], 24, UI.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 10)
	box.add_child(stars_row)
	var got := Game.level_stars(w, l)
	for i in 3:
		var s := UI.icon_rect("star", 64)
		s.self_modulate = Color.WHITE if i < got else Color(0.3, 0.25, 0.35, 0.3)
		stars_row.add_child(s)
		UI.pop_in(s, 0.1 + i * 0.08)
	for m in Worlds.level_mods(w, l):
		var def: Dictionary = Worlds.MODS[m]
		var chip := PanelContainer.new()
		var csb := UI.box(Color(def.color), 20)
		csb.set_content_margin_all(12)
		chip.add_theme_stylebox_override("panel", csb)
		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 10)
		chip.add_child(ch)
		ch.add_child(UI.icon_rect(def.icon, 44))
		var cl := UI.label("%s : %s" % [Lang.t(def.name), Lang.t(def.desc)], 21, Color.WHITE, 600)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.add_child(cl)
		box.add_child(chip)
	var rules := UI.label(Lang.t("1 étoile : résoudre la grille\n2 étoiles : sans Loupe ni Éclair\n3 étoiles : sans aide et sous le temps de référence"), 21, UI.INK_SOFT)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules)
	if l % Worlds.CHEST_EVERY == 0 and not Game.is_solved(w, l):
		var chest := HBoxContainer.new()
		chest.alignment = BoxContainer.ALIGNMENT_CENTER
		chest.add_child(UI.icon_rect("gift", 44))
		chest.add_child(UI.label(Lang.t("Coffre au trésor à la clé !"), 24, UI.CORAL, 600))
		box.add_child(chest)
	var play := UI.button(Lang.t("Jouer"), Worlds.color(w, "accent"), "puzzle", 36)
	play.custom_minimum_size.y = 100
	play.pressed.connect(func():
		main.close_popup()
		main.go("game", {"world": w, "level": l}))
	box.add_child(play)
	main.popup(box)


func _announce_worlds() -> void:
	for w in Worlds.world_count():
		if Game.is_world_unlocked(w) and not Game.data.seen_worlds.has(str(w)):
			Game.data.seen_worlds[str(w)] = true
			Game.save()
			await get_tree().create_timer(0.8).timeout
			if not is_inside_tree() or main.screen != self:
				return
			Sfx.play("unlock")
			main.confetti(60)
			var world: Dictionary = Worlds.WORLDS[w]
			main.message(world.icon, Lang.t("Nouveau quartier : %s !") % Lang.t(world.name), Lang.t(world.tagline) + Lang.t(". De nouvelles catégories t'attendent."), [[Lang.t("En route !"), Worlds.color(w, "accent")]])
			return
