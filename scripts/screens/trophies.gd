extends Control
## Salle des trophées : objectifs, progression et récompenses.

var main
var params := {}


func _ready() -> void:
	add_child(WorldBackground.new(3, 0.6))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	var home := UI.button("", Color.WHITE, "house", 30, UI.INK)
	home.pressed.connect(back)
	top.add_child(home)
	top.add_child(UI.icon_rect("trophy", 56))
	var t := UI.label("Trophées", 44, UI.INK, 700)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UI.pill("trophy", "%d/%d" % [Game.data.achievements.size(), Game.ACHIEVEMENTS.size()]))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var i := 0
	for a in Game.ACHIEVEMENTS:
		var got: bool = Game.data.achievements.has(a.id)
		var p := PanelContainer.new()
		var sb := UI.box(Color(1, 1, 1, 0.92) if got else Color(1, 1, 1, 0.6), 24)
		sb.set_content_margin_all(14)
		if got:
			sb.border_color = UI.YELLOW
			sb.set_border_width_all(4)
		p.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		p.add_child(h)
		var ic := UI.icon_rect(a.icon, 64)
		if not got:
			ic.modulate = Color(0.2, 0.15, 0.25, 0.35)
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		h.add_child(v)
		v.add_child(UI.label(a.name, 28, UI.INK if got else UI.INK_SOFT, 700))
		var d := UI.label(a.desc, 21, UI.INK_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		if not got:
			var cur: int = min(Game.stat(a.stat), int(a.goal))
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size.y = 12
			bar.max_value = float(a.goal)
			bar.value = cur
			bar.add_theme_stylebox_override("background", UI.box(Color("efe6f5"), 6))
			bar.add_theme_stylebox_override("fill", UI.box(UI.CORAL, 6))
			v.add_child(bar)
			v.add_child(UI.label("%d / %d" % [cur, a.goal], 18, UI.INK_SOFT))
		var reward := VBoxContainer.new()
		reward.alignment = BoxContainer.ALIGNMENT_CENTER
		if got:
			reward.add_child(UI.icon_rect("check", 40))
		else:
			var rh := HBoxContainer.new()
			rh.add_theme_constant_override("separation", 4)
			rh.add_child(UI.icon_rect("coin", 28))
			rh.add_child(UI.label(str(a.coins), 24, UI.INK, 700))
			reward.add_child(rh)
		h.add_child(reward)
		list.add_child(p)
		UI.pop_in(p, 0.03 * i, 0.9)
		i += 1


func back() -> void:
	main.go("home")
