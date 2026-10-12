extends Control
## Écrans du jeu (menu, partie, victoire), construits en code.
## Tout fonctionne hors ligne : les grilles sont générées sur l'appareil
## et la progression est enregistrée dans user://save.json.

const SAVE_PATH := "user://save.json"
const BG := Color("f3ecdc")
const INK := Color("2b2620")
const ACCENT := Color("8a5a2b")

var save := {"next_level": [1, 1, 1], "current": {}}
var gen := PuzzleGenerator.new()
var difficulty := 0
var level := 1
var puzzle: Dictionary
var struck := {}

var _menu: Control
var _game: Control
var _grid: GridView
var _title: Label
var _status: Label
var _clue_box: VBoxContainer
var _overlay: Control
var _thread: Thread


func _ready() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_load()
	_build_menu()
	_build_game()
	_show_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _overlay and _overlay.visible:
			_overlay.queue_free()
			_overlay = null
		elif _game.visible:
			_show_menu()
		else:
			get_tree().quit()


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	t.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("fffdf7"), "hover": Color("fff6e0"), "pressed": Color("ead9b8"),
			"focus": Color("fffdf7"), "disabled": Color("e8e1d2")}[state]
		sb.border_color = ACCENT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		t.set_stylebox(state, "Button", sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	return t


# --- Sauvegarde ---------------------------------------------------------------

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		if data.get("next_level") is Array and data.next_level.size() == 3:
			save.next_level = data.next_level.map(func(x): return int(x))
		if data.get("current") is Dictionary:
			save.current = data.current


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))


func _save_progress() -> void:
	save.current[str(difficulty)] = {"level": level, "marks": _grid.export_marks(), "struck": struck.keys()}
	_save()


# --- Menu ---------------------------------------------------------------------

func _build_menu() -> void:
	_menu = MarginContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_menu.add_theme_constant_override("margin_" + side, 48)
	add_child(_menu)


func _show_menu() -> void:
	_game.hide()
	for c in _menu.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	_menu.add_child(box)

	var title := Label.new()
	title.text = "Logigramme"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Des énigmes de logique, sans connexion."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	box.add_child(_spacer(24))

	for d in 3:
		var cfg: Dictionary = PuzzleGenerator.DIFFICULTIES[d]
		var lvl := _level_for(d)
		var b := Button.new()
		b.text = "%s · niveau %d\n%d catégories × %d" % [cfg.name, lvl, cfg.cats, cfg.items]
		b.custom_minimum_size.y = 120
		b.pressed.connect(_start.bind(d, lvl))
		box.add_child(b)

	box.add_child(_spacer(12))
	var help := Button.new()
	help.text = "Comment jouer"
	help.pressed.connect(_show_help)
	box.add_child(help)
	_menu.show()


func _level_for(d: int) -> int:
	var cur = save.current.get(str(d))
	if cur is Dictionary:
		return int(cur.level)
	return int(save.next_level[d])


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	return s


func _show_help() -> void:
	_popup("Comment jouer",
		"Chaque personne possède exactement une valeur de chaque catégorie, et deux personnes n'ont jamais la même.\n\n"
		+ "Lisez les indices et déduisez qui va avec quoi.\n\n"
		+ "Touchez une case pour y mettre une croix rouge (impossible), touchez-la encore pour une pastille verte (certain), puis une troisième fois pour la vider. "
		+ "Une pastille verte barre automatiquement le reste de sa ligne et de sa colonne dans le bloc.\n\n"
		+ "Touchez un indice pour le rayer une fois utilisé.\n\n"
		+ "La grille est gagnée quand toutes les pastilles vertes sont bien placées.",
		[["Compris", Callable()]])


# --- Partie -------------------------------------------------------------------

func _build_game() -> void:
	_game = MarginContainer.new()
	_game.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		_game.add_theme_constant_override("margin_" + side, 12)
	_game.add_theme_constant_override("margin_top", 16)
	_game.add_theme_constant_override("margin_bottom", 12)
	add_child(_game)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_game.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	var back := Button.new()
	back.text = "‹ Menu"
	back.pressed.connect(_show_menu)
	top.add_child(back)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_title)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	col.add_child(tools)
	for spec in [["Annuler", _on_undo], ["Vérifier", _on_check], ["Indice", _on_hint], ["Effacer", _on_clear]]:
		var b := Button.new()
		b.text = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(spec[1])
		tools.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	_grid = GridView.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.changed.connect(_on_grid_changed)
	_grid.solved.connect(_on_solved)
	inner.add_child(_grid)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", ACCENT)
	inner.add_child(_status)

	var head := Label.new()
	head.text = "Indices"
	head.add_theme_font_size_override("font_size", 30)
	inner.add_child(head)
	_clue_box = VBoxContainer.new()
	_clue_box.add_theme_constant_override("separation", 6)
	inner.add_child(_clue_box)
	_game.hide()


func _start(d: int, lvl: int) -> void:
	difficulty = d
	level = lvl
	_menu.hide()
	_game.show()
	_title.text = "%s · niveau %d" % [PuzzleGenerator.DIFFICULTIES[d].name, lvl]
	_status.text = "Préparation de la grille…"
	for c in _clue_box.get_children():
		c.queue_free()
	_grid.hide()
	# La génération peut prendre un instant sur les grandes grilles : on la fait à côté.
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_generate.bind(d, lvl))


func _generate(d: int, lvl: int) -> void:
	var g := PuzzleGenerator.new()
	var pz := g.generate(d, lvl)
	call_deferred("_on_generated", pz)


func _on_generated(pz: Dictionary) -> void:
	_thread.wait_to_finish()
	if pz.difficulty != difficulty or pz.level != level:
		return
	puzzle = pz
	struck.clear()
	var saved_marks := {}
	var cur = save.current.get(str(difficulty))
	if cur is Dictionary and int(cur.level) == level:
		saved_marks = cur.get("marks", {})
		for i in cur.get("struck", []):
			struck[int(i)] = true
	_grid.show()
	_grid.setup(puzzle, saved_marks)
	_status.text = ""
	_build_clues()
	_save_progress()
	if _grid.is_solved:
		_on_solved()


func _build_clues() -> void:
	for c in _clue_box.get_children():
		c.queue_free()
	for i in puzzle.clues.size():
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("fffdf7")
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", sb)
		var lbl := Label.new()
		lbl.text = "%d. %s" % [i + 1, puzzle.clues[i].text]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 24)
		panel.add_child(lbl)
		panel.gui_input.connect(_on_clue_input.bind(i, panel, lbl))
		_clue_box.add_child(panel)
		_style_clue(i, panel, lbl)


func _on_clue_input(event: InputEvent, i: int, panel: PanelContainer, lbl: Label) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if struck.has(i):
			struck.erase(i)
		else:
			struck[i] = true
		_style_clue(i, panel, lbl)
		_save_progress()


func _style_clue(i: int, panel: PanelContainer, lbl: Label) -> void:
	var done := struck.has(i)
	panel.modulate = Color(1, 1, 1, 0.45) if done else Color.WHITE
	lbl.text = "%d. %s" % [i + 1, puzzle.clues[i].text]


func _on_grid_changed() -> void:
	_status.text = ""
	_save_progress()


func _on_undo() -> void:
	_grid.undo()


func _on_check() -> void:
	if puzzle.is_empty():
		return
	var e := _grid.check_errors()
	_status.text = "Aucune erreur pour l'instant." if e == 0 else "%d erreur%s en rouge." % [e, "s" if e > 1 else ""]


func _on_hint() -> void:
	if puzzle.is_empty() or _grid.is_solved:
		return
	if _grid.check_errors() > 0:
		_status.text = "Corrigez d'abord les cases en rouge."
		return
	_grid.reveal_one()


func _on_clear() -> void:
	_popup("Effacer la grille ?", "Toutes les marques de cette grille seront supprimées.",
		[["Annuler", Callable()], ["Effacer", func(): _grid.clear_all()]])


func _on_solved() -> void:
	save.next_level[difficulty] = max(int(save.next_level[difficulty]), level + 1)
	save.current.erase(str(difficulty))
	_save()
	_status.text = "Grille résolue !"
	_popup("Bravo !", "Vous avez résolu le niveau %d (%s)." % [level, PuzzleGenerator.DIFFICULTIES[difficulty].name],
		[["Menu", _show_menu], ["Niveau suivant", func(): _start(difficulty, level + 1)]])


# --- Fenêtre modale -----------------------------------------------------------

func _popup(title: String, body: String, buttons: Array) -> void:
	if _overlay:
		_overlay.queue_free()
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.x = min(620.0, get_viewport_rect().size.x - 40)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = panel.custom_minimum_size.x - 56
	box.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var ov := _overlay
	for spec in buttons:
		var btn := Button.new()
		btn.text = spec[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = spec[1]
		btn.pressed.connect(func():
			ov.queue_free()
			if _overlay == ov:
				_overlay = null
			if cb.is_valid():
				cb.call())
		row.add_child(btn)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
