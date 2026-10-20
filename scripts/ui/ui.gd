class_name UI
extends RefCounted
## Palette, polices, icônes et petits composants « bonbon » réutilisés par tous les écrans.

const CREAM := Color("fff8ec")
const PAPER := Color("fffdf8")
const INK := Color("3d3047")
const INK_SOFT := Color("66577a")
const CORAL := Color("ff7a59")
const YELLOW := Color("ffc93c")
const MINT := Color("4cc39d")
const SKY := Color("5fb8ef")
const LAVENDER := Color("9b7cf4")
const PINK := Color("f472b6")
const GREY := Color("c9c0d3")

static var _fonts := {}
static var _icons := {}


static func font(weight: int = 500) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Fredoka.ttf")
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://assets/icons/%s.svg" % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = 26
	t.set_color("font_color", "Label", INK)
	return t


static func box(bg: Color, radius: int = 24, border: Color = Color.TRANSPARENT, bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	return sb


static func label(text: String, size: int = 26, color: Color = INK, weight: int = 500) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Liseré autour du texte, pour qu'un texte clair reste lisible sur un fond clair.
static func outline(l: Label, color: Color, px: int) -> void:
	l.add_theme_color_override("font_outline_color", color)
	l.add_theme_constant_override("outline_size", px)


## Un contrôle qui consomme l'appui empêche de glisser le défilement parent : on le laisse passer.
static func pass_drags(node: Control) -> void:
	if node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for c in node.get_children():
		if c is Control:
			pass_drags(c)


static func icon_rect(name: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Bouton en relief façon bonbon : bord inférieur plus sombre qui s'écrase à l'appui.
static func button(text: String, color: Color = CORAL, icon_name: String = "", font_size: int = 28, text_color: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font(600))
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, text_color)
	b.add_theme_color_override("font_disabled_color", Color(text_color, 0.6))
	var dark := color.darkened(0.25)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := box(color.lightened(0.06) if state == "hover" else color, 22)
		if state == "disabled":
			sb.bg_color = GREY
		sb.border_color = GREY.darkened(0.2) if state == "disabled" else dark
		sb.border_width_bottom = 3 if state == "pressed" else 8
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 14 + (5 if state == "pressed" else 0)
		sb.content_margin_bottom = 12
		if state == "focus":
			sb.draw_center = false
			sb.border_width_bottom = 0
		b.add_theme_stylebox_override(state, sb)
	if icon_name != "":
		b.icon = icon(icon_name)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", int(font_size * 1.3))
		b.add_theme_constant_override("h_separation", 10)
	b.focus_mode = Control.FOCUS_NONE
	juice(b)
	return b


## Petit rebond à l'appui et son « pop ».
static func juice(b: BaseButton) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.06))
	b.button_up.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.pressed.connect(func():
		Sfx.play("pop")
		Sfx.buzz(10))


## Pastille compteur (pièces, étoiles…).
static func pill(icon_name: String, text: String, bg: Color = Color(1, 1, 1, 0.85)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(bg, 40)
	sb.content_margin_left = 10
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(icon_rect(icon_name, 34))
	var l := label(text, 26, INK, 600)
	l.name = "Value"
	h.add_child(l)
	return p


static func set_pill(p: Control, text: String) -> void:
	var l := p.find_child("Value", true, false) as Label
	if l:
		l.text = text


## Fait apparaître un nœud avec un léger rebond.
static func pop_in(c: CanvasItem, delay: float = 0.0, from: float = 0.6) -> void:
	if c is Control:
		var ctl := c as Control
		ctl.pivot_offset = ctl.size / 2.0
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(delay)


## Léger flottement continu.
static func bob(c: CanvasItem, amp: float = 8.0, period: float = 2.4, phase: float = 0.0) -> void:
	var tw := c.create_tween().set_loops()
	var p0: Vector2 = c.position
	tw.tween_interval(phase)
	tw.tween_property(c, "position:y", p0.y - amp, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "position:y", p0.y, period / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func format_time(s: float) -> String:
	var t := int(s)
	return "%d:%02d" % [t / 60, t % 60]
