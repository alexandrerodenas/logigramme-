extends Control
## Coquille de l'application : navigation entre écrans, fenêtres, notifications, confettis.

const SCREENS := {
	"home": preload("res://scripts/screens/home.gd"),
	"map": preload("res://scripts/screens/map.gd"),
	"game": preload("res://scripts/screens/game_screen.gd"),
	"trophies": preload("res://scripts/screens/trophies.gd"),
}

var screen: Control
var screen_name := ""
var _holder: Control
var _overlays: Control
var _fx: Control
var _toast_y := 0.0


func _ready() -> void:
	theme = UI.make_theme()
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)
	_overlays = Control.new()
	_overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlays)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	get_tree().root.size_changed.connect(_fit_orientation)
	_fit_orientation()
	go("home")
	# Captures d'écran automatiques pour le développement (outil exclu de l'export).
	if OS.has_environment("LOGIGRAMME_SHOTS"):
		add_child(load("res://tools/shot_driver.gd").new())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _overlays.get_child_count() > 0:
			close_popup()
		elif screen and screen.has_method("back"):
			screen.back()
		else:
			get_tree().quit()


## Taille logique selon l'orientation : 720×1280 en portrait, 1280×720 en paysage, pour garder
## la même taille de texte. Les écrans autres que la partie sont reconstruits à la rotation ;
## la partie s'adapte d'elle-même (voir game_screen.gd).
func _fit_orientation() -> void:
	var win := DisplayServer.window_get_size()
	var want := Vector2i(1280, 720) if win.x > win.y else Vector2i(720, 1280)
	var root := get_tree().root
	if root.content_scale_size == want:
		return
	root.content_scale_size = want
	if screen and screen_name != "game":
		while has_popup():
			close_popup()
		go(screen_name, _params)


var _params := {}


## Change d'écran avec un fondu.
func go(name: String, params: Dictionary = {}) -> void:
	var old := screen
	screen = Control.new()
	screen.set_script(SCREENS[name])
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_name = name
	_params = params
	screen.set("main", self)
	screen.set("params", params)
	screen.modulate.a = 0.0
	_holder.add_child(screen)
	var tw := create_tween()
	tw.tween_property(screen, "modulate:a", 1.0, 0.22)
	if old:
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw2 := create_tween()
		tw2.tween_property(old, "modulate:a", 0.0, 0.18)
		tw2.tween_callback(old.queue_free)
	Sfx.play("whoosh")


# --- Fenêtres -----------------------------------------------------------------

## Ouvre une fenêtre modale contenant `content`. Renvoie le panneau.
func popup(content: Control, dismissable: bool = true) -> PanelContainer:
	var shade := ColorRect.new()
	shade.color = Color(0.17, 0.12, 0.22, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlays.add_child(shade)
	if dismissable:
		shade.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				close_popup())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var panel := PanelContainer.new()
	var sb := UI.box(UI.CREAM, 36)
	sb.set_content_margin_all(32)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size.x = min(640.0, get_viewport_rect().size.x - 48)
	center.add_child(panel)
	# Une fenêtre plus haute que l'écran (paysage) défile.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	panel.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	UI.pass_drags(content)
	var fit := func():
		var h: float = content.get_combined_minimum_size().y
		scroll.custom_minimum_size.y = min(h, get_viewport_rect().size.y - 140.0)
	content.minimum_size_changed.connect(fit)
	fit.call()
	var tw := create_tween()
	tw.tween_property(shade, "color:a", 0.55, 0.2)
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)
	UI.pop_in(panel, 0.0, 0.7)
	return panel


func close_popup() -> void:
	var n := _overlays.get_child_count()
	if n == 0:
		return
	var shade := _overlays.get_child(n - 1)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(shade, "modulate:a", 0.0, 0.15)
	tw.tween_callback(shade.queue_free)


func has_popup() -> bool:
	for c in _overlays.get_children():
		if not c.is_queued_for_deletion() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	return false


## Fenêtre standard : grande icône, titre, texte, boutons [[texte, couleur, callable], …].
func message(icon_name: String, title: String, body: String, buttons: Array, dismissable: bool = true) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	if icon_name != "":
		var ic := UI.icon_rect(icon_name, 110)
		box.add_child(ic)
		UI.pop_in(ic, 0.15, 0.3)
	var t := UI.label(title, 44, UI.INK, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(t)
	if body != "":
		var b := UI.label(body, 26, UI.INK_SOFT)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for spec in buttons:
		var btn := UI.button(spec[0], spec[1])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = spec[2] if spec.size() > 2 else Callable()
		btn.pressed.connect(func():
			close_popup()
			if cb.is_valid():
				cb.call())
		row.add_child(btn)
	popup(box, dismissable)


# --- Réglages -----------------------------------------------------------------

## Fenêtre des réglages, ouverte depuis l'accueil ou en pleine partie.
## `full` ajoute la remise à zéro de la progression (accueil seulement).
func settings(full: bool = false) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var t := UI.label(Lang.t("Réglages"), 44, UI.INK, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for spec in [["sound", Lang.t("Sons"), "sound"], ["music", Lang.t("Musique"), "music"], ["vibration", Lang.t("Vibrations"), "phone"],
			["auto_cross", Lang.t("Croix automatiques"), "cross"]]:
		var id: String = spec[0]
		var b := UI.button("", UI.MINT, spec[2], 28)
		var refresh := func():
			b.text = "%s : %s" % [spec[1], Lang.t("oui") if Game.setting(id) else Lang.t("non")]
			var col: Color = UI.MINT if Game.setting(id) else Color("b9adc4")
			for st in ["normal", "hover", "pressed"]:
				var sb: StyleBoxFlat = b.get_theme_stylebox(st)
				sb.bg_color = col
				sb.border_color = col.darkened(0.25)
		refresh.call()
		b.pressed.connect(func():
			Game.set_setting(id, not Game.setting(id))
			refresh.call()
			Sfx.update_music())
		box.add_child(b)
	var lang := UI.button("", UI.SKY, "earth", 28)
	lang.text = "%s : %s" % [Lang.t("Langue"), Lang.t("English") if Lang.is_en() else Lang.t("Français")]
	lang.pressed.connect(func():
		Game.set_language("en" if not Lang.is_en() else "fr")
		close_popup()
		if screen_name == "game":
			# Une partie en cours garde ses textes : la langue s'applique à la grille suivante.
			toast("earth", Lang.t("Langue"), Lang.t("Appliquée à la prochaine grille."))
		else:
			go(screen_name, _params))
	box.add_child(lang)
	var note := UI.label(Lang.t("Croix automatiques : une pastille barre d'elle-même le reste de sa ligne et de sa colonne."), 20, UI.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	if full:
		var reset := UI.button(Lang.t("Recommencer à zéro"), UI.CORAL, "broom", 26)
		reset.pressed.connect(func():
			close_popup()
			message("broom", Lang.t("Tout effacer ?"), Lang.t("Étoiles, pièces, trophées et progression seront perdus."),
				[[Lang.t("Annuler"), UI.SKY], [Lang.t("Effacer"), UI.CORAL, func():
					Game.reset()
					go("home")]]))
		box.add_child(reset)
		var credits := UI.label(Lang.t("Icônes Twemoji (CC BY 4.0, Twitter et contributeurs) · Police Fredoka (SIL OFL) · Fait avec Godot"), 18, UI.INK_SOFT)
		credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(credits)
	var ok := UI.button(Lang.t("Fermer"), UI.SKY)
	ok.pressed.connect(close_popup)
	box.add_child(ok)
	popup(box)


# --- Notifications ------------------------------------------------------------

func toast(icon_name: String, title: String, sub: String = "") -> void:
	var p := PanelContainer.new()
	var sb := UI.box(UI.INK, 30)
	sb.content_margin_left = 16
	sb.content_margin_right = 26
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(UI.icon_rect(icon_name, 54))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(UI.label(title, 26, UI.YELLOW, 700))
	if sub != "":
		v.add_child(UI.label(sub, 21, Color.WHITE))
	_fx.add_child(p)
	await get_tree().process_frame
	var w := get_viewport_rect().size.x
	p.position = Vector2((w - p.size.x) / 2.0, -p.size.y - 20)
	var y := 30.0 + _toast_y
	_toast_y += p.size.y + 12
	var tw := create_tween()
	tw.tween_property(p, "position:y", y, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(p, "position:y", -p.size.y - 20, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_toast_y = max(0.0, _toast_y - p.size.y - 12)
		p.queue_free())


# --- Effets -------------------------------------------------------------------

func confetti(amount: int = 90) -> void:
	var w := get_viewport_rect().size.x
	var colors := [UI.CORAL, UI.YELLOW, UI.MINT, UI.SKY, UI.LAVENDER, UI.PINK]
	for c in colors:
		var p := CPUParticles2D.new()
		p.amount = amount / colors.size()
		p.one_shot = true
		p.explosiveness = 0.85
		p.lifetime = 3.2
		p.position = Vector2(w / 2.0, -20)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(w / 2.0, 10)
		p.direction = Vector2(0, 1)
		p.spread = 40
		p.initial_velocity_min = 250
		p.initial_velocity_max = 650
		p.gravity = Vector2(0, 520)
		p.angular_velocity_min = -540
		p.angular_velocity_max = 540
		p.angle_min = 0
		p.angle_max = 360
		p.scale_amount_min = 7
		p.scale_amount_max = 14
		p.damping_min = 40
		p.damping_max = 90
		p.color = c
		var img := Image.create(2, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		p.texture = ImageTexture.create_from_image(img)
		_fx.add_child(p)
		p.emitting = true
		get_tree().create_timer(4.0).timeout.connect(p.queue_free)


## Pièces qui volent de `from` vers `to` (coordonnées écran).
func fly_icons(icon_name: String, from: Vector2, to: Vector2, count: int = 8) -> void:
	for i in count:
		var r := UI.icon_rect(icon_name, 44)
		r.position = from - Vector2(22, 22) + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		_fx.add_child(r)
		var tw := create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(r, "position", to - Vector2(22, 22), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			Sfx.play("coin", 1.0 + i * 0.03)
			r.queue_free())
