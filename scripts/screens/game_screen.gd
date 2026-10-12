extends Control
## Partie : grille, indices, chronomètre, aides payantes et écran de victoire.

var main
var params := {}

var cfg: Dictionary
var puzzle: Dictionary
var key := ""
var world := 0
var struck := {}
var elapsed := 0.0
var used_aid := false
var finished := false
var mods: Array = []
var hearts := 3
var hearts_lost := 0
var bonus_time := 0.0
var time_limit := 0.0
var keys := 0
var sealed := {}
var awarded := {}
var _failed := false
var _mod_chips := {}
var _clue_nodes := {}

var _grid: GridView
var _clue_box: VBoxContainer
var _timer_pill: Control
var _coins: Control
var _progress: ProgressBar
var _loading: Control
var _aid_buttons := {}
var _thread: Thread
var _save_acc := 0.0
var _content: VBoxContainer


func _ready() -> void:
	if params.has("daily"):
		cfg = Worlds.daily_config(params.daily)
		key = "daily-" + String(params.daily)
	else:
		cfg = Worlds.level_config(params.world, params.level)
		key = Game.level_key(params.world, params.level)
	world = cfg.world
	mods = cfg.get("mods", [])
	add_child(WorldBackground.new(world, 0.45))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 14)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	# Barre du haut.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var back_btn := UI.button("", Color.WHITE, "map", 28, UI.INK)
	back_btn.pressed.connect(back)
	top.add_child(back_btn)
	var clear_btn := UI.button("", Color.WHITE, "broom", 28, UI.INK)
	clear_btn.pressed.connect(_clear)
	top.add_child(clear_btn)
	var title := HBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 8)
	top.add_child(title)
	var boss: bool = cfg.get("boss", false)
	# Titre court : la barre porte aussi le balai et la roue des réglages.
	if cfg.get("daily", false) or boss:
		title.add_child(UI.icon_rect("calendar" if cfg.get("daily", false) else "crown", 44))
	var t_text := "Défi" if cfg.get("daily", false) else ("Énigme" if boss else "Niveau %d" % cfg.level)
	var t_lbl := UI.label(t_text, 30, UI.INK, 700)
	t_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t_lbl.clip_text = true
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(t_lbl)
	_timer_pill = UI.pill("timer", "0:00")
	top.add_child(_timer_pill)
	_coins = UI.pill("coin", str(Game.coins()))
	top.add_child(_coins)
	Game.coins_changed.connect(func(v): UI.set_pill(_coins, str(v)))
	var gear := UI.button("", Color.WHITE, "gear", 28, UI.INK)
	gear.pressed.connect(func(): main.settings())
	top.add_child(gear)

	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 14
	_progress.max_value = 1.0
	_progress.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.7), 7))
	_progress.add_theme_stylebox_override("fill", UI.box(Worlds.color(world, "accent"), 7))
	col.add_child(_progress)
	if not mods.is_empty():
		col.add_child(_mod_bar())

	var card := PanelContainer.new()
	var sb := UI.box(Color(1, 1, 1, 0.92), 28)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0.2, 0.1, 0.3, 0.12)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	card.add_theme_stylebox_override("panel", sb)
	# La grille reste fixe : seuls les indices défilent, dans leur propre zone.
	col.add_child(card)
	_grid = GridView.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.accent = Worlds.color(world, "accent")
	_grid.changed.connect(_on_grid_changed)
	_grid.solved.connect(_on_solved)
	_grid.marked.connect(_on_marked)
	_grid.wrong_complete.connect(_on_wrong_complete.bind(card))
	_grid.hide()
	card.add_child(_grid)

	_loading = VBoxContainer.new()
	_loading.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading.custom_minimum_size.y = 520
	var spin := UI.icon_rect("loupe", 110)
	_loading.add_child(spin)
	var lt := UI.label("Le village prépare ton énigme…", 26, UI.INK_SOFT, 500)
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.add_child(lt)
	card.add_child(_loading)
	UI.bob(spin, 14.0, 0.9)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UI.icon_rect("scroll", 40))
	head.add_child(UI.label("Indices", 32, UI.INK, 700))
	var hint := UI.label("touche pour rayer", 20, UI.INK_SOFT)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(hint)
	col.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_clue_box = VBoxContainer.new()
	_clue_box.add_theme_constant_override("separation", 8)
	_content.add_child(_clue_box)
	var pad := Control.new()
	pad.custom_minimum_size.y = 20
	_content.add_child(pad)

	col.add_child(_aid_bar())

	_thread = Thread.new()
	_thread.start(_generate.bind(cfg))


func _generate(c: Dictionary) -> void:
	var g := PuzzleGenerator.new()
	var pz := g.generate(c)
	call_deferred("_on_generated", pz)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _on_generated(pz: Dictionary) -> void:
	_thread.wait_to_finish()
	if not is_inside_tree():
		return
	puzzle = pz
	var cur := Game.get_current(key)
	var saved_marks: Dictionary = cur.get("marks", {})
	for i in cur.get("struck", []):
		struck[int(i)] = true
	elapsed = float(cur.get("time", 0.0))
	used_aid = bool(cur.get("aid", false))
	hearts = int(cur.get("hearts", 3))
	hearts_lost = int(cur.get("hearts_lost", 0))
	bonus_time = float(cur.get("bonus_time", 0.0))
	keys = int(cur.get("keys", 0))
	for k in cur.get("awarded", []):
		awarded[k] = true
	time_limit = round(Game.par_time(puzzle) * 1.25)
	if mods.has("fog"):
		if cur.has("sealed"):
			for i in cur.sealed:
				sealed[int(i)] = true
		else:
			_seal_clues()
	_refresh_mods()
	_loading.queue_free()
	_grid.show()
	_grid.setup(puzzle, saved_marks)
	UI.pop_in(_grid, 0.0, 0.85)
	_build_clues()
	_progress.value = _grid.fill_ratio()
	_refresh_aids()
	if not Game.data.tutorial and not cfg.get("daily", false) and world == 0 and cfg.level == 1:
		_tutorial()
	else:
		_intros()


func _process(delta: float) -> void:
	if puzzle.is_empty() or finished or _failed or main.has_popup():
		return
	elapsed += delta
	if mods.has("chrono"):
		var left := time_limit + bonus_time - elapsed
		UI.set_pill(_timer_pill, UI.format_time(max(0.0, left)))
		var l := _timer_pill.find_child("Value", true, false) as Label
		l.add_theme_color_override("font_color", UI.CORAL if left < 30.0 else UI.INK)
		if left < 30.0 and int(left * 2.0) != int((left + delta) * 2.0):
			Sfx.play("tap", 1.4)
		if left <= 0.0:
			_fail("chrono")
	else:
		UI.set_pill(_timer_pill, UI.format_time(elapsed))
	_save_acc += delta
	if _save_acc > 5.0:
		_save_acc = 0.0
		_save_progress()


func back() -> void:
	if not puzzle.is_empty() and not finished:
		_save_progress()
	if cfg.get("daily", false):
		main.go("home")
	else:
		main.go("map", {"focus": [world, cfg.level]})


func _save_progress() -> void:
	if finished or puzzle.is_empty():
		return
	Game.set_current(key, {"marks": _grid.export_marks(), "struck": struck.keys(), "time": elapsed, "aid": used_aid,
		"hearts": hearts, "hearts_lost": hearts_lost, "bonus_time": bonus_time, "keys": keys,
		"sealed": sealed.keys(), "awarded": awarded.keys()})


# --- Indices ------------------------------------------------------------------

func _build_clues() -> void:
	for c in _clue_box.get_children():
		c.queue_free()
	_clue_nodes.clear()
	for i in puzzle.clues.size():
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(h)
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var num := UI.label(str(i + 1), 24, Color.WHITE, 700)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.custom_minimum_size.x = 20
		badge.add_child(num)
		h.add_child(badge)
		var lbl := UI.label("", 25, UI.INK, 500)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lbl)
		var lock := UI.icon_rect("key", 40)
		h.add_child(lock)
		var press := [Vector2.ZERO]
		panel.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					press[0] = e.global_position
				elif e.global_position.distance_to(press[0]) < 22:
					_on_clue_tap(i))
		_clue_box.add_child(panel)
		_clue_nodes[i] = {"panel": panel, "label": lbl, "badge": badge, "lock": lock}
		_render_clue(i, false)
		UI.pop_in(panel, 0.05 * i, 0.9)


func _on_clue_tap(i: int) -> void:
	if sealed.has(i):
		_open_sealed(i)
		return
	if struck.has(i):
		struck.erase(i)
	else:
		struck[i] = true
	Sfx.play("tap", 0.8 if struck.has(i) else 1.1)
	_render_clue(i, true)
	_save_progress()


func _render_clue(i: int, animate: bool) -> void:
	var n: Dictionary = _clue_nodes[i]
	var panel: PanelContainer = n.panel
	var lbl: Label = n.label
	var is_sealed := sealed.has(i)
	var accent := Worlds.color(world, "accent")
	var sb := UI.box(Color("ece6ff") if is_sealed else Color(1, 1, 1, 0.92), 22)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	if is_sealed:
		sb.border_color = UI.LAVENDER
		sb.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", sb)
	var bsb := UI.box(UI.LAVENDER if is_sealed else accent, 20)
	bsb.content_margin_left = 12
	bsb.content_margin_right = 12
	(n.badge as PanelContainer).add_theme_stylebox_override("panel", bsb)
	(n.lock as Control).visible = is_sealed
	if is_sealed:
		lbl.text = "Indice scellé : touche pour l'ouvrir avec une clé."
		lbl.add_theme_color_override("font_color", UI.LAVENDER.darkened(0.3))
		panel.modulate = Color.WHITE
		return
	lbl.text = puzzle.clues[i].text
	var done := struck.has(i)
	var target := Color(1, 1, 1, 0.42) if done else Color.WHITE
	if animate:
		create_tween().tween_property(panel, "modulate", target, 0.2)
	else:
		panel.modulate = target
	lbl.add_theme_color_override("font_color", UI.INK_SOFT if done else UI.INK)


# --- Grille -------------------------------------------------------------------

func _on_marked(kind: int, cell: Array) -> void:
	if kind == GridView.CHECK and not finished:
		var ok := _grid.is_correct(cell)
		if mods.has("hearts") and not ok:
			_lose_heart(cell)
			return
		if mods.has("fog") and ok:
			var id := "%d-%d-%d-%d" % cell
			if not awarded.has(id):
				awarded[id] = true
				keys += 1
				_refresh_mods(true)
				Sfx.play("coin", 1.2)
	match kind:
		GridView.CROSS:
			Sfx.play("cross", randf_range(0.95, 1.05))
		GridView.CHECK:
			Sfx.play("check")
		_:
			Sfx.play("erase")
	Sfx.buzz(12)


## Grille pleine mais fausse : elle tremble, avec un son d'erreur et une vibration.
func _on_wrong_complete(card: Control) -> void:
	Sfx.play("error")
	Sfx.buzz(220)
	var x := card.position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(card, "position:x", x + 16, 0.05)
		tw.tween_property(card, "position:x", x - 16, 0.05)
	tw.tween_property(card, "position:x", x, 0.05)
	main.toast("broken", "Il y a une erreur", "La grille est pleine, mais quelque chose cloche.")


func _on_grid_changed() -> void:
	create_tween().tween_property(_progress, "value", _grid.fill_ratio(), 0.25)
	_save_progress()


# --- Aides --------------------------------------------------------------------

func _aid_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var undo := _aid_button("undo", "Annuler", "", UI.SKY)
	undo.pressed.connect(func():
		if not _grid.undo():
			Sfx.play("error"))
	row.add_child(undo)
	var colors := {"verify": UI.MINT, "loupe": UI.YELLOW, "eclair": UI.LAVENDER}
	for id in ["verify", "loupe", "eclair"]:
		var a: Dictionary = Game.AIDS[id]
		var b := _aid_button(a.icon, a.name, str(a.cost), colors[id])
		b.pressed.connect(_use_aid.bind(id))
		row.add_child(b)
		_aid_buttons[id] = b
	return row


func _aid_button(icon_name: String, text: String, cost: String, color: Color) -> Button:
	var b := UI.button("", color, "", 22, UI.INK if color == UI.YELLOW else Color.WHITE)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 112
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.offset_bottom = -6
	b.add_child(v)
	var ic := UI.icon_rect(icon_name, 46)
	ic.name = "Icon"
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var tc := UI.INK if color == UI.YELLOW else Color.WHITE
	var l := UI.label(text, 20, tc, 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	if cost != "":
		var ch := HBoxContainer.new()
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		ch.add_theme_constant_override("separation", 4)
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.name = "Cost"
		ch.add_child(UI.icon_rect("coin", 20))
		var cl := UI.label(cost, 19, tc, 700)
		cl.name = "CostLabel"
		ch.add_child(cl)
		v.add_child(ch)
	return b


func _refresh_aids() -> void:
	for id in _aid_buttons:
		var b: Button = _aid_buttons[id]
		var unlocked := Game.is_aid_unlocked(id)
		var ic := b.find_child("Icon", true, false) as TextureRect
		ic.texture = UI.icon(Game.AIDS[id].icon if unlocked else "lock")
		b.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.6)


func _use_aid(id: String) -> void:
	if puzzle.is_empty() or finished:
		return
	var a: Dictionary = Game.AIDS[id]
	if not Game.is_aid_unlocked(id):
		var u: Array = a.unlock
		main.toast("lock", "%s verrouillée" % a.name, "Se débloque après le niveau %d du %s." % [u[1], Worlds.WORLDS[u[0]].name])
		Sfx.play("error")
		return
	if Game.coins() < int(a.cost):
		main.toast("coin", "Pas assez de pièces", "Gagne-en en résolvant des grilles et des défis.")
		Sfx.play("error")
		_shake(_coins)
		return
	if not used_aid and id != "verify":
		main.message(a.icon, "%s ?" % a.name, "%s\nCoût : %d pièces. Cette grille ne pourra plus rapporter que 1 étoile." % [a.desc, a.cost],
			[["Non", UI.SKY], ["Utiliser", UI.CORAL, func(): _apply_aid(id)]])
	else:
		_apply_aid(id)


func _apply_aid(id: String) -> void:
	var a: Dictionary = Game.AIDS[id]
	var effect := 0
	match id:
		"verify":
			# Vérifier coûte des pièces mais jamais d'étoile.
			var errs := _grid.check_errors()
			Game.spend(int(a.cost))
			if errs == 0:
				main.toast("check", "Aucune erreur !", "Tout ce que tu as placé est juste.")
			else:
				main.toast("check", "%d erreur%s" % [errs, "s" if errs > 1 else ""], "Les cases fausses sont en rouge.")
				Sfx.play("error")
			return
		"loupe":
			if _grid.check_errors() > 0:
				main.toast("loupe", "Corrige d'abord", "Il y a des cases fausses (en rouge). Aucune pièce dépensée.")
				return
			effect = 1 if _grid.reveal_one() else 0
		"eclair":
			effect = _grid.apply_simple_clues()
			if effect == 0:
				main.toast("eclair", "Rien à appliquer", "Les indices simples sont déjà dans ta grille. Aucune pièce dépensée.")
				return
			Sfx.play("unlock")
	if effect == 0:
		return
	Game.spend(int(a.cost))
	used_aid = true
	_save_progress()


func _shake(c: Control) -> void:
	var x := c.position.x
	var tw := create_tween()
	for i in 3:
		tw.tween_property(c, "position:x", x + 10, 0.04)
		tw.tween_property(c, "position:x", x - 10, 0.04)
	tw.tween_property(c, "position:x", x, 0.04)


# --- Didacticiel --------------------------------------------------------------

func _tutorial() -> void:
	var steps := [
		["detective", "Ta première enquête", "Chaque habitant a exactement une valeur dans chaque catégorie, et jamais la même qu'un autre. À toi de trouver qui va avec quoi grâce aux indices."],
		["puzzle", "La grille", "Touche une case une fois pour une croix (impossible), deux fois pour une pastille verte (c'est bien ça !), trois fois pour la vider. Tu poses toi-même chaque croix, et une seule pastille est permise par ligne et par colonne d'un bloc. Le balai efface toute la grille, la roue dentée ouvre les réglages."],
		["coin", "Étoiles et pièces", "Résous vite et sans aide pour gagner 3 étoiles. Les pièces gagnées servent à acheter des aides quand tu bloques."],
	]
	_tutorial_step(steps, 0)


func _tutorial_step(steps: Array, i: int) -> void:
	if i >= steps.size():
		Game.data.tutorial = true
		Game.save()
		return
	var s: Array = steps[i]
	var label := "Compris !" if i == steps.size() - 1 else "Suivant"
	main.message(s[0], s[1], s[2], [[label, UI.CORAL, func(): _tutorial_step(steps, i + 1)]], false)


# --- Victoire -----------------------------------------------------------------

func _on_solved() -> void:
	finished = true
	_progress.value = 1.0
	Sfx.play("win")
	Sfx.buzz(60)
	var par := Game.par_time(puzzle)
	var r := Game.complete(cfg, elapsed, used_aid, par, {"hearts_lost": hearts_lost})
	await get_tree().create_timer(0.5).timeout
	main.confetti()
	_victory(r)


func _victory(r: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var words := ["Bravo !", "Élémentaire !", "Brillant !", "Quel flair !", "Magnifique !", "Bien joué !"]
	var title := UI.label(words[randi() % words.size()], 56, Worlds.color(world, "accent").darkened(0.1), 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 6)
	box.add_child(stars_row)
	var stars: Array = []
	for i in 3:
		var s := UI.icon_rect("star", 96 if i == 1 else 80)
		s.modulate = Color(0.3, 0.25, 0.35, 0.25)
		stars_row.add_child(s)
		stars.append(s)

	var crit := [
		[true, "Grille résolue"],
		[r.no_aid, "Sans Loupe ni Éclair"],
		[r.fast, "En moins de %s (toi : %s)" % [UI.format_time(r.par), UI.format_time(r.time)]],
	]
	for c in crit:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(UI.icon_rect("check" if c[0] else "lock", 30))
		h.add_child(UI.label(c[1], 23, UI.INK if c[0] else UI.INK_SOFT, 500))
		box.add_child(h)

	var rewards := HBoxContainer.new()
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", 16)
	box.add_child(rewards)
	var coin_pill := UI.pill("coin", "+0", Color("fff1c7"))
	rewards.add_child(coin_pill)
	rewards.add_child(UI.pill("glow", "+%d XP" % r.xp, Color("efe6ff")))

	var extras := VBoxContainer.new()
	extras.add_theme_constant_override("separation", 8)
	box.add_child(extras)
	if r.get("mod_bonus", 0) > 0:
		extras.add_child(_banner(Worlds.MODS[mods[0]].icon, "Bonus niveau spécial : +%d pièces" % r.mod_bonus, Color(Worlds.MODS[mods[0]].color)))
	if r.chest > 0:
		extras.add_child(_banner("gift", "Coffre ouvert : +%d pièces !" % r.chest, UI.CORAL))
	if r.get("streak", 0) > 0:
		extras.add_child(_banner("fire", "Série de %d jour%s !" % [r.streak, "s" if r.streak > 1 else ""], UI.CORAL))
	if r.rank_after != r.rank_before:
		extras.add_child(_banner("crown", "Nouveau rang : %s !" % Game.rank_name(r.rank_after), UI.LAVENDER))
	for id in r.new_aids:
		extras.add_child(_banner(Game.AIDS[id].icon, "Nouvelle aide : %s" % Game.AIDS[id].name, UI.MINT.darkened(0.2)))
	if r.world_unlocked >= 0:
		extras.add_child(_banner(Worlds.WORLDS[r.world_unlocked].icon, "Nouveau quartier : %s !" % Worlds.WORLDS[r.world_unlocked].name, UI.SKY.darkened(0.2)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var is_daily: bool = cfg.get("daily", false)
	var to_map := UI.button("Accueil" if is_daily else "Parcours", UI.SKY, "house" if is_daily else "map", 28)
	to_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to_map.pressed.connect(func():
		main.close_popup()
		if is_daily:
			main.go("home")
		else:
			main.go("map", {"focus": Game.next_level()}))
	row.add_child(to_map)
	if not is_daily:
		var nxt := _next_after()
		if not nxt.is_empty():
			var go_next := UI.button("Suivant", Worlds.color(world, "accent"), "puzzle", 28)
			go_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			go_next.pressed.connect(func():
				main.close_popup()
				main.go("game", {"world": nxt[0], "level": nxt[1]}))
			row.add_child(go_next)

	main.popup(box, false)

	# Animation des étoiles puis du gain de pièces.
	for i in 3:
		if i < r.stars:
			await get_tree().create_timer(0.35).timeout
			var s: Control = stars[i]
			s.modulate = Color.WHITE
			s.pivot_offset = s.size / 2.0
			s.scale = Vector2(1.8, 1.8)
			create_tween().tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Sfx.play("star", 1.0 + i * 0.12)
			Sfx.buzz(25)
	var total: int = r.coins
	var tw := create_tween()
	tw.tween_method(func(v: float): UI.set_pill(coin_pill, "+%d" % int(v)), 0.0, float(total), 0.8)
	if total > 0:
		main.fly_icons("coin", coin_pill.global_position + coin_pill.size / 2.0, _coins.global_position + _coins.size / 2.0, min(10, 3 + total / 10))
	for a in r.achievements:
		await get_tree().create_timer(0.6).timeout
		Sfx.play("unlock")
		main.toast(a.icon, "Trophée : %s" % a.name, "%s  +%d pièces" % [a.desc, a.coins])


func _next_after() -> Array:
	var w: int = cfg.world
	var l: int = cfg.level
	if l < Worlds.LEVELS_PER_WORLD:
		return [w, l + 1]
	if w + 1 < Worlds.world_count() and Game.is_world_unlocked(w + 1):
		return [w + 1, 1]
	return []


func _banner(icon_name: String, text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	var sb := UI.box(color, 20)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(UI.icon_rect(icon_name, 38))
	var l := UI.label(text, 24, Color.WHITE, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	UI.pop_in(p, 0.9, 0.7)
	return p


# --- Niveaux spéciaux ---------------------------------------------------------

func _mod_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for m in mods:
		var def: Dictionary = Worlds.MODS[m]
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := UI.box(Color(def.color), 20)
		sb.content_margin_left = 10
		sb.content_margin_right = 14
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		chip.add_child(h)
		h.add_child(UI.icon_rect(def.icon, 30))
		var l := UI.label(def.name, 21, Color.WHITE, 600)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var extra := HBoxContainer.new()
		extra.add_theme_constant_override("separation", 2)
		h.add_child(extra)
		chip.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				main.toast(def.icon, def.name, def.desc))
		row.add_child(chip)
		_mod_chips[m] = {"chip": chip, "extra": extra}
	return row


func _refresh_mods(pop: bool = false) -> void:
	if _mod_chips.has("hearts"):
		var extra: HBoxContainer = _mod_chips.hearts.extra
		for c in extra.get_children():
			c.queue_free()
		for i in 3:
			extra.add_child(UI.icon_rect("heart" if i < hearts else "broken", 28))
	if _mod_chips.has("fog"):
		var extra: HBoxContainer = _mod_chips.fog.extra
		for c in extra.get_children():
			c.queue_free()
		extra.add_child(UI.label("× %d" % keys, 24, Color.WHITE, 700))
		if pop:
			var chip: Control = _mod_chips.fog.chip
			chip.pivot_offset = chip.size / 2.0
			chip.scale = Vector2(1.15, 1.15)
			create_tween().tween_property(chip, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _seal_clues() -> void:
	sealed.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(cfg.seed) + "-scelles")
	var candidates: Array = []
	for i in puzzle.clues.size():
		if int(puzzle.clues[i].type) != PuzzleGenerator.ClueType.SAME:
			candidates.append(i)
	var count: int = min(candidates.size(), int(ceil(puzzle.clues.size() * 0.45)))
	for k in count:
		var j := rng.randi_range(0, candidates.size() - 1)
		sealed[int(candidates[j])] = true
		candidates.remove_at(j)


func _open_sealed(i: int) -> void:
	if keys > 0:
		keys -= 1
		_unseal(i)
		return
	main.message("key", "Pas de clé", "Place une bonne pastille verte pour gagner une clé, ou ouvre cet indice tout de suite pour 15 pièces.",
		[["Attendre", UI.SKY], ["Ouvrir (15)", UI.LAVENDER, func():
			if Game.spend(15):
				_unseal(i)
			else:
				main.toast("coin", "Pas assez de pièces", "")]])


func _unseal(i: int) -> void:
	sealed.erase(i)
	_refresh_mods(true)
	_render_clue(i, false)
	var panel: Control = _clue_nodes[i].panel
	UI.pop_in(panel, 0.0, 0.7)
	Sfx.play("unlock")
	Sfx.buzz(30)
	_save_progress()


func _lose_heart(cell: Array) -> void:
	_grid.undo()
	_grid.flash_error(cell)
	hearts -= 1
	hearts_lost += 1
	_refresh_mods()
	Sfx.play("error")
	Sfx.buzz(90)
	_shake(_mod_chips.hearts.chip)
	_save_progress()
	if hearts <= 0:
		_fail("hearts")


func _fail(kind: String) -> void:
	_failed = true
	var title := "Plus de cœurs !" if kind == "hearts" else "Temps écoulé !"
	var body := "Trois pastilles mal placées : l'enquête dérape." if kind == "hearts" else "Le sablier est vide."
	var cost := 25
	var cont := "+2 cœurs" if kind == "hearts" else "+1 minute"
	main.message("broken" if kind == "hearts" else "hourglass", title, body + "\nRecommencer la grille, ou continuer pour %d pièces ?" % cost,
		[["Recommencer", UI.SKY, _restart], ["%s (%d)" % [cont, cost], UI.CORAL, func():
			if Game.spend(cost):
				if kind == "hearts":
					hearts = 2
				else:
					bonus_time += 60.0
				_failed = false
				_refresh_mods()
				_save_progress()
			else:
				main.toast("coin", "Pas assez de pièces", "On recommence la grille.")
				_restart()]], false)


func _restart() -> void:
	_failed = false
	elapsed = 0.0
	bonus_time = 0.0
	hearts = 3
	hearts_lost = 0
	keys = 0
	awarded.clear()
	struck.clear()
	used_aid = false
	_grid.reset()
	if mods.has("fog"):
		_seal_clues()
	_build_clues()
	_refresh_mods()
	_save_progress()


## Présente la grande énigme, les modificateurs et les nouveaux types d'indices la première fois.
func _intros() -> void:
	var queue: Array = []
	var seen: Dictionary = Game.data.seen_intros
	if cfg.get("boss", false):
		queue.append(["crown", "Grande énigme !", "La dernière enquête du quartier : %d catégories à démêler. Un gros coffre attend au bout." % puzzle.n_cats])
	for m in mods:
		if not seen.has(m):
			seen[m] = true
			var def: Dictionary = Worlds.MODS[m]
			queue.append([def.icon, "Niveau spécial : %s" % def.name, def.desc + " Bonus de pièces à la clé."])
	if puzzle.clues.any(func(c): return int(c.type) == PuzzleGenerator.ClueType.PAIR) and not seen.has("pair"):
		seen.pair = true
		var d: Dictionary = Worlds.CLUE_INTROS.pair
		queue.append([d.icon, d.title, d.text])
	if puzzle.cats.any(func(c): return c.get("kind", "") == "street") and not seen.has("street"):
		seen.street = true
		var d: Dictionary = Worlds.CLUE_INTROS.street
		queue.append([d.icon, d.title, d.text])
	Game.save()
	_show_queue(queue, 0)


func _show_queue(queue: Array, i: int) -> void:
	if i >= queue.size():
		return
	var q: Array = queue[i]
	Sfx.play("unlock")
	main.message(q[0], q[1], q[2], [["Compris !", UI.CORAL, func(): _show_queue(queue, i + 1)]], false)


## Efface toutes les marques et les indices rayés pour repartir de zéro, sans confirmation
## (le bouton « annuler » ramène la grille).
func _clear() -> void:
	if puzzle.is_empty() or finished:
		return
	_grid.clear_all()
	struck.clear()
	for i in _clue_nodes:
		_render_clue(i, true)
	Sfx.play("whoosh")
	_save_progress()
