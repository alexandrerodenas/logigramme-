extends Control
## Accueil : logo, rang du joueur, bouton Jouer, défi du jour, trophées, réglages.

var main
var params := {}
var _coins: Control


func _ready() -> void:
	var nxt: Array = Game.next_level()
	var w: int = nxt[0]
	add_child(WorldBackground.new(w, 1.0))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	# Barre du haut.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	_coins = UI.pill("coin", str(Game.coins()))
	top.add_child(_coins)
	top.add_child(UI.pill("star", str(Game.total_stars())))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var gear := UI.button("", Color.WHITE, "gear", 30, UI.INK)
	gear.pressed.connect(_settings)
	top.add_child(gear)
	Game.coins_changed.connect(func(v): UI.set_pill(_coins, str(v)))

	# Logo.
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -6)
	col.add_child(logo)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 6)
	logo.add_child(icons)
	for name in ["puzzle", "loupe", "detective"]:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(96, 104)
		icons.add_child(holder)
		var ic := UI.icon_rect(name, 88)
		ic.position = Vector2(4, 10)
		holder.add_child(ic)
		UI.bob(ic, 9.0, 2.2 + randf() * 0.6, randf() * 0.5)
	var title := UI.label("Logigramme", 82, UI.INK, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.9))
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_child(title)
	var sub := UI.label("Le village des énigmes", 28, UI.INK_SOFT, 500)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(sub)

	# Carte de rang.
	col.add_child(_rank_card())

	col.add_child(_worlds_card())

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grow)

	# Bouton Jouer.
	var world: Dictionary = Worlds.WORLDS[w]
	var play := UI.button("Jouer", Worlds.color(w, "accent"), world.icon, 46)
	play.custom_minimum_size.y = 128
	play.pressed.connect(func(): main.go("map", {"focus": nxt}))
	col.add_child(play)
	var where := UI.label("%s · niveau %d" % [world.name, nxt[1]], 24, UI.INK_SOFT, 600)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(where)
	_pulse(play)

	col.add_child(_daily_card())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var map := UI.button("Parcours", UI.SKY, "map", 28)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.pressed.connect(func(): main.go("map", {"focus": nxt}))
	row.add_child(map)
	var n_ach: int = Game.data.achievements.size()
	var tro := UI.button("Trophées %d/%d" % [n_ach, Game.ACHIEVEMENTS.size()], UI.LAVENDER, "trophy", 28)
	tro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tro.pressed.connect(func(): main.go("trophies"))
	row.add_child(tro)

	if not Game.data.get("welcomed", false):
		Game.data.welcomed = true
		Game.save()
		await get_tree().create_timer(0.4).timeout
		if not is_inside_tree() or main.screen != self:
			return
		main.message("detective", "Bienvenue au village !",
			"Les habitants ont besoin d'un fin limier. Résous leurs énigmes, gagne des étoiles et des pièces, et ouvre de nouveaux quartiers.",
			[["C'est parti !", UI.CORAL]])
	Sfx.update_music()


func back() -> void:
	get_tree().quit()


func _pulse(c: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(1.03, 1.03), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UI.box(Color(1, 1, 1, 0.88), 30)
	sb.set_content_margin_all(20)
	sb.shadow_color = Color(0.2, 0.1, 0.3, 0.12)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _rank_card() -> Control:
	var p := _card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	h.add_child(UI.icon_rect("detective", 72))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var i := Game.rank_index()
	var line := HBoxContainer.new()
	v.add_child(line)
	var name := UI.label(Game.rank_name(), 32, UI.INK, 700)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	var nxt_txt := "Rang max" if i >= Game.RANKS.size() - 1 else "→ %s" % Game.RANKS[i + 1][1]
	line.add_child(UI.label(nxt_txt, 22, UI.INK_SOFT, 500))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 20
	bar.max_value = 1.0
	bar.value = 0.0
	bar.add_theme_stylebox_override("background", UI.box(Color("efe6f5"), 10))
	bar.add_theme_stylebox_override("fill", UI.box(UI.LAVENDER, 10))
	v.add_child(bar)
	create_tween().tween_property(bar, "value", Game.rank_progress(), 0.9).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	v.add_child(UI.label("%d XP" % Game.xp(), 20, UI.INK_SOFT))
	return p


func _worlds_card() -> Control:
	var p := _card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UI.label("Les quartiers", 28, UI.INK, 700)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UI.label("%d trophées · %d étoiles" % [Game.data.achievements.size(), Game.total_stars()], 20, UI.INK_SOFT))
	var row := GridContainer.new()
	row.columns = 5
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	for w in Worlds.world_count():
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		row.add_child(cell)
		var unlocked := Game.is_world_unlocked(w)
		var holder := CenterContainer.new()
		holder.custom_minimum_size.y = 64
		cell.add_child(holder)
		var ic := UI.icon_rect(Worlds.WORLDS[w].icon if unlocked else "lock", 54)
		if not unlocked:
			ic.modulate = Color(1, 1, 1, 0.55)
		holder.add_child(ic)
		var txt := "%d/%d" % [Game.world_stars(w), Worlds.LEVELS_PER_WORLD * 3] if unlocked else "%d" % int(Worlds.WORLDS[w].stars_needed)
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_theme_constant_override("separation", 2)
		line.add_child(UI.icon_rect("star", 20))
		line.add_child(UI.label(txt, 19, UI.INK if unlocked else UI.INK_SOFT, 600))
		cell.add_child(line)
		if Game.world_done(w):
			UI.bob(ic, 4.0, 2.0, w * 0.2)
	return p


func _daily_card() -> Control:
	var p := _card()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var ic := UI.icon_rect("calendar", 70)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(UI.label("Défi du jour", 30, UI.INK, 700))
	var streak := Game.daily_streak()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	v.add_child(line)
	line.add_child(UI.icon_rect("fire", 28))
	line.add_child(UI.label("Série : %d jour%s" % [streak, "s" if streak > 1 else ""], 22, UI.CORAL, 600))
	if Game.daily_done_today():
		var done := UI.label("Réussi !", 28, UI.MINT.darkened(0.2), 700)
		h.add_child(done)
	else:
		var go_btn := UI.button("+%d" % (40 + 10 * min(streak, 4)), UI.YELLOW, "coin", 26, UI.INK)
		go_btn.pressed.connect(func(): main.go("game", {"daily": Game.today_string()}))
		h.add_child(go_btn)
		UI.bob(ic, 5.0, 1.6)
	return p


func _settings() -> void:
	main.settings(true)
