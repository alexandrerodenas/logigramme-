class_name GridView
extends Control
## Grille de logigramme en escalier : chaque bloc croise deux catégories.
## Un appui fait défiler une case : vide → croix → pastille → vide.

signal changed
signal solved
## Toutes les pastilles sont posées mais la solution est fausse.
signal wrong_complete
signal marked(kind: int, cell: Array)

const EMPTY := 0
const CROSS := 1
const CHECK := 2

const COL_BG := Color("fffdf8")
const COL_BG_ALT := Color("fbf3e6")
const COL_LINE := Color("e3d8c8")
const COL_TEXT := Color("3d3047")
const COL_CROSS := Color("f0705a")
const COL_CHECK := Color("43b98f")
const COL_ERROR := Color(1, 0.3, 0.25, 0.4)
const COL_HILITE := Color(1.0, 0.82, 0.3, 0.22)
const COL_GLOW := Color(1.0, 0.85, 0.2, 0.75)

var pz: Dictionary
var marks := {}          # "a_b" (a < b) -> PackedByteArray de taille n*n
var errors := {}         # "a_b:idx" -> true
var undo_stack: Array = []
var is_solved := false
var accent := Color("ff7a59")

var _n := 0
var _row_cats: Array = []
var _col_cats: Array = []
var _cell := 40.0
var _label_w := 120.0
var _font: Font
var _font_bold: Font
## Taille unique de tout le texte de la grille (libellés, initiales, pastilles chiffrées), quel que soit le niveau.
const FONT_SIZE := 18
var _font_size := FONT_SIZE
var _was_complete := false
var _hover := Vector2i(-1, -1)
var _anims := {}         # "a_b:idx" -> instant de départ (s)
var _glow := {}          # "a_b:idx" -> instant de départ (s)
var _time := 0.0
var _press := Vector2.ZERO


func setup(puzzle: Dictionary, saved_marks: Dictionary = {}) -> void:
	pz = puzzle
	_n = pz.items
	var n_cats: int = pz.n_cats
	_col_cats = range(1, n_cats)
	_row_cats = [0]
	for c in range(n_cats - 1, 1, -1):
		_row_cats.append(c)
	marks.clear()
	for a in n_cats:
		for b in range(a + 1, n_cats):
			var arr := PackedByteArray()
			arr.resize(_n * _n)
			var key := "%d_%d" % [a, b]
			if saved_marks.has(key):
				var src: Array = saved_marks[key]
				for i in min(src.size(), arr.size()):
					var m := int(src[i])
					arr[i] = m if m <= CHECK else EMPTY
			marks[key] = arr
	undo_stack.clear()
	errors.clear()
	_anims.clear()
	_glow.clear()
	is_solved = _check_solved()
	_was_complete = is_complete()
	_font = UI.font(500)
	_font_bold = UI.font(600)
	_relayout()
	queue_redraw()


func export_marks() -> Dictionary:
	var out := {}
	for k in marks:
		out[k] = Array(marks[k])
	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not pz.is_empty():
		_relayout()
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if not _anims.is_empty() or not _glow.is_empty():
		for k in _anims.keys():
			if _time - float(_anims[k]) > 0.35:
				_anims.erase(k)
		for k in _glow.keys():
			if _time - float(_glow[k]) > 1.6:
				_glow.erase(k)
		queue_redraw()


func _relayout() -> void:
	var cols := _col_cats.size() * _n
	var w := size.x
	# La zone des libellés vaut environ 2,8 cases, et s'élargit si le plus long libellé n'y tient pas.
	_cell = floor(w / (cols + 2.8))
	var longest := 0.0
	for c in pz.cats:
		for v in c.values:
			longest = max(longest, _font.get_string_size(v.short, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x)
	for _i in 8:
		var ic: float = min(_cell * 0.72, 44.0)
		if w - cols * _cell >= longest + ic + 22 or _cell <= 24:
			break
		_cell -= 1
	_label_w = w - cols * _cell
	custom_minimum_size.y = _label_w + _row_cats.size() * _n * _cell + 4


func _block_exists(rg: int, cg: int) -> bool:
	return rg == 0 or cg < _col_cats.size() - rg


func _key_idx(rc: int, rv: int, cc: int, cv: int) -> Array:
	if rc < cc:
		return ["%d_%d" % [rc, cc], rv * _n + cv]
	return ["%d_%d" % [cc, rc], cv * _n + rv]


func get_mark(rc: int, rv: int, cc: int, cv: int) -> int:
	var ki := _key_idx(rc, rv, cc, cv)
	return marks[ki[0]][ki[1]]


func _set_mark(rc: int, rv: int, cc: int, cv: int, v: int, action: Array) -> void:
	var ki := _key_idx(rc, rv, cc, cv)
	var arr: PackedByteArray = marks[ki[0]]
	if arr[ki[1]] == v:
		return
	action.append([ki[0], ki[1], arr[ki[1]]])
	arr[ki[1]] = v
	marks[ki[0]] = arr
	_anims["%s:%d" % ki] = _time


func _cell_at(pos: Vector2) -> Array:
	var x := pos.x - _label_w
	var y := pos.y - _label_w
	if x < 0 or y < 0:
		return []
	var ci := int(x / _cell)
	var ri := int(y / _cell)
	var cg := ci / _n
	var rg := ri / _n
	if cg >= _col_cats.size() or rg >= _row_cats.size() or not _block_exists(rg, cg):
		return []
	return [_row_cats[rg], ri % _n, _col_cats[cg], ci % _n, rg, cg]


func _ready() -> void:
	# Laisse passer les glissements au défilement parent ; un appui court marque la case.
	mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = event.global_position
			return
		if event.global_position.distance_to(_press) > 22:
			return
		var hit := _cell_at(event.position)
		if hit.is_empty() or is_solved:
			return
		_tap(hit)


func _tap(hit: Array) -> void:
	var rc: int = hit[0]
	var rv: int = hit[1]
	var cc: int = hit[2]
	var cv: int = hit[3]
	var cur := get_mark(rc, rv, cc, cv)
	var nxt := (cur + 1) % 3
	var action: Array = []
	_set_mark(rc, rv, cc, cv, nxt, action)
	if nxt == CHECK:
		# Une seule pastille par ligne et par colonne d'un bloc : l'ancienne est retirée.
		var old: Array = []
		for v in _n:
			if v != cv and get_mark(rc, rv, cc, v) == CHECK:
				old.append([rv, v])
			if v != rv and get_mark(rc, v, cc, cv) == CHECK:
				old.append([v, cv])
		if Game.setting("auto_cross"):
			_exclude(rc, rv, cc, cv, action)
		for o in old:
			_set_mark(rc, o[0], cc, o[1], EMPTY, action)
	_hover = Vector2i(hit[4] * _n + rv, hit[5] * _n + cv)
	_commit(action)
	marked.emit(nxt, [rc, rv, cc, cv])


## Option « croix automatiques » : un ✓ exclut le reste de sa ligne et de sa colonne dans ce bloc.
func _exclude(rc: int, rv: int, cc: int, cv: int, action: Array) -> void:
	for v in _n:
		if v != cv and is_blank(get_mark(rc, rv, cc, v)):
			_set_mark(rc, rv, cc, v, CROSS, action)
		if v != rv and is_blank(get_mark(rc, v, cc, cv)):
			_set_mark(rc, v, cc, cv, CROSS, action)


static func is_blank(m: int) -> bool:
	return m == EMPTY


func _commit(action: Array) -> void:
	if action.is_empty():
		return
	undo_stack.append(action)
	errors.clear()
	queue_redraw()
	changed.emit()
	if _check_solved():
		is_solved = true
		solved.emit()
	else:
		_check_complete()


## Signale une seule fois le passage à « grille pleine mais fausse ».
func _check_complete() -> void:
	var full := is_complete()
	if full and not _was_complete:
		wrong_complete.emit()
	_was_complete = full


## Vrai quand chaque bloc a une pastille sur chacune de ses lignes.
func is_complete() -> bool:
	for k in marks:
		var arr: PackedByteArray = marks[k]
		var checks := 0
		for m in arr:
			if m == CHECK:
				checks += 1
		if checks < _n:
			return false
	return true


func undo() -> bool:
	if undo_stack.is_empty() or is_solved:
		return false
	var action: Array = undo_stack.pop_back()
	for i in range(action.size() - 1, -1, -1):
		var e: Array = action[i]
		var arr: PackedByteArray = marks[e[0]]
		arr[e[1]] = e[2]
		marks[e[0]] = arr
		_anims["%s:%d" % [e[0], e[1]]] = _time
	errors.clear()
	_was_complete = is_complete()
	queue_redraw()
	changed.emit()
	return true


## Fait clignoter une case en rouge (erreur signalée par un mode de jeu).
func flash_error(cell: Array) -> void:
	var id := "%s:%d" % _key_idx(cell[0], cell[1], cell[2], cell[3])
	errors[id] = true
	queue_redraw()
	await get_tree().create_timer(0.9).timeout
	errors.erase(id)
	queue_redraw()


func is_correct(cell: Array) -> bool:
	return PuzzleGenerator.is_match(pz, cell[0], cell[1], cell[2], cell[3])


func reset() -> void:
	for k in marks:
		var arr: PackedByteArray = marks[k]
		arr.fill(EMPTY)
		marks[k] = arr
	undo_stack.clear()
	errors.clear()
	is_solved = false
	queue_redraw()
	changed.emit()


func clear_all() -> void:
	var action: Array = []
	for k in marks:
		var arr: PackedByteArray = marks[k]
		for i in arr.size():
			if arr[i] != EMPTY:
				action.append([k, i, arr[i]])
				arr[i] = EMPTY
		marks[k] = arr
	is_solved = false
	_commit(action)


## Marque en rouge les cases contredisant la solution et renvoie leur nombre.
func check_errors() -> int:
	errors.clear()
	for k in marks:
		var ab: PackedStringArray = k.split("_")
		var a := int(ab[0])
		var b := int(ab[1])
		var arr: PackedByteArray = marks[k]
		for i in arr.size():
			if is_blank(arr[i]):
				continue
			var ok := PuzzleGenerator.is_match(pz, a, i / _n, b, i % _n)
			if (arr[i] == CHECK) != ok:
				errors["%s:%d" % [k, i]] = true
	queue_redraw()
	return errors.size()


## Aide « Loupe » : place un ✓ correct pas encore trouvé. Renvoie false s'il n'y en a plus.
func reveal_one() -> bool:
	var candidates: Array = []
	for rg in _row_cats.size():
		for cg in _col_cats.size():
			if not _block_exists(rg, cg):
				continue
			var rc: int = _row_cats[rg]
			var cc: int = _col_cats[cg]
			for rv in _n:
				for cv in _n:
					if PuzzleGenerator.is_match(pz, rc, rv, cc, cv) and get_mark(rc, rv, cc, cv) != CHECK:
						candidates.append([rc, rv, cc, cv, rg, cg])
	if candidates.is_empty():
		return false
	var h: Array = candidates[randi() % candidates.size()]
	var action: Array = []
	_set_mark(h[0], h[1], h[2], h[3], CHECK, action)
	for v in _n:
		if v != h[3]:
			_set_mark(h[0], h[1], h[2], v, CROSS, action)
		if v != h[1]:
			_set_mark(h[0], v, h[2], h[3], CROSS, action)
	_glow["%s:%d" % _key_idx(h[0], h[1], h[2], h[3])] = _time
	_hover = Vector2i(h[4] * _n + h[1], h[5] * _n + h[3])
	_commit(action)
	return true


## Aide « Éclair » : applique tous les indices « est » et « n'est pas ». Renvoie le nombre de cases changées.
func apply_simple_clues() -> int:
	var action: Array = []
	for cl in pz.clues:
		var t := int(cl.type)
		if t != PuzzleGenerator.ClueType.SAME and t != PuzzleGenerator.ClueType.DIFF:
			continue
		var a: Array = cl.a
		var b: Array = cl.b
		var before := action.size()
		if t == PuzzleGenerator.ClueType.SAME:
			if get_mark(a[0], a[1], b[0], b[1]) != CHECK:
				_set_mark(a[0], a[1], b[0], b[1], CHECK, action)
				for v in _n:
					if v != b[1]:
						_set_mark(a[0], a[1], b[0], v, CROSS, action)
					if v != a[1]:
						_set_mark(a[0], v, b[0], b[1], CROSS, action)
		elif is_blank(get_mark(a[0], a[1], b[0], b[1])):
			_set_mark(a[0], a[1], b[0], b[1], CROSS, action)
		for i in range(before, action.size()):
			_glow["%s:%d" % [action[i][0], action[i][1]]] = _time
	var n := action.size()
	_commit(action)
	return n


func _check_solved() -> bool:
	for k in marks:
		var ab: PackedStringArray = k.split("_")
		var a := int(ab[0])
		var b := int(ab[1])
		var arr: PackedByteArray = marks[k]
		for i in arr.size():
			var ok := PuzzleGenerator.is_match(pz, a, i / _n, b, i % _n)
			if ok != (arr[i] == CHECK):
				return false
	return true


## Part de cases remplies (0 à 1), pour la barre de progression.
func fill_ratio() -> float:
	var total := 0
	var filled := 0
	for k in marks:
		var arr: PackedByteArray = marks[k]
		total += arr.size()
		for v in arr:
			if not is_blank(v):
				filled += 1
	return float(filled) / max(1, total)


# --- Dessin -------------------------------------------------------------------

func _draw() -> void:
	if pz.is_empty():
		return
	var cats: Array = pz.cats
	var n_cols := _col_cats.size()
	var n_rows := _row_cats.size()
	var origin := Vector2(_label_w, _label_w)

	# Fond des blocs (alternance douce) et ombre portée.
	for rg in n_rows:
		for cg in n_cols:
			if not _block_exists(rg, cg):
				continue
			var r := Rect2(origin + Vector2(cg * _n, rg * _n) * _cell, Vector2(_n, _n) * _cell)
			draw_rect(Rect2(r.position + Vector2(0, 4), r.size), Color(0.24, 0.19, 0.28, 0.08))
			draw_rect(r, COL_BG if (rg + cg) % 2 == 0 else COL_BG_ALT)
	if _hover.x >= 0:
		var hr := _hover.x
		var hc := _hover.y
		var rg_h := hr / _n
		var cg_h := hc / _n
		for cg in n_cols:
			if _block_exists(rg_h, cg):
				draw_rect(Rect2(origin + Vector2(cg * _n, hr) * _cell, Vector2(_n * _cell, _cell)), COL_HILITE)
		for rg in n_rows:
			if _block_exists(rg, cg_h):
				draw_rect(Rect2(origin + Vector2(hc, rg * _n) * _cell, Vector2(_cell, _n * _cell)), COL_HILITE)

	# Lignes fines.
	for rg in n_rows:
		for cg in n_cols:
			if not _block_exists(rg, cg):
				continue
			var p0 := origin + Vector2(cg * _n, rg * _n) * _cell
			for i in range(1, _n):
				draw_line(p0 + Vector2(i * _cell, 0), p0 + Vector2(i * _cell, _n * _cell), COL_LINE, 1.5)
				draw_line(p0 + Vector2(0, i * _cell), p0 + Vector2(_n * _cell, i * _cell), COL_LINE, 1.5)

	# Marques, erreurs et halos.
	for rg in n_rows:
		for cg in n_cols:
			if not _block_exists(rg, cg):
				continue
			var rc: int = _row_cats[rg]
			var cc: int = _col_cats[cg]
			for rv in _n:
				for cv in _n:
					var p := origin + Vector2(cg * _n + cv, rg * _n + rv) * _cell
					var ki := _key_idx(rc, rv, cc, cv)
					var id := "%s:%d" % ki
					if errors.has(id):
						draw_rect(Rect2(p, Vector2(_cell, _cell)), COL_ERROR)
					if _glow.has(id):
						var g: float = 1.0 - (_time - float(_glow[id])) / 1.6
						draw_circle(p + Vector2(_cell, _cell) * 0.5, _cell * (0.45 + 0.15 * sin(_time * 10.0)), Color(COL_GLOW, COL_GLOW.a * g))
					var s := 1.0
					if _anims.has(id):
						var t: float = clamp((_time - float(_anims[id])) / 0.3, 0.0, 1.0)
						s = _back_out(t)
					var m: int = marks[ki[0]][ki[1]]
					if m == CROSS:
						_draw_cross(p, s)
					elif m == CHECK:
						_draw_check(p, s)

	# Contours arrondis des blocs, couleur du monde.
	for rg in n_rows:
		for cg in n_cols:
			if not _block_exists(rg, cg):
				continue
			var p0 := origin + Vector2(cg * _n, rg * _n) * _cell
			draw_rect(Rect2(p0, Vector2(_n, _n) * _cell), accent.darkened(0.15), false, 3.0)

	# Libellés des lignes : icône (ou avatar) collée à la grille, texte à gauche.
	var ic: float = min(_cell * 0.72, 44.0)
	for rg in n_rows:
		var rc: int = _row_cats[rg]
		for rv in _n:
			var v: Dictionary = cats[rc].values[rv]
			var cy := origin.y + (rg * _n + rv) * _cell + _cell * 0.5
			var icon_c := Vector2(_label_w - ic * 0.5 - 6, cy)
			_draw_value_icon(v, icon_c, ic)
			var asc := _font.get_ascent(_font_size)
			draw_string(_font, Vector2(4, cy + asc * 0.36), v.short, HORIZONTAL_ALIGNMENT_RIGHT, _label_w - ic - 16, _font_size, COL_TEXT)

	# Libellés des colonnes : icône en bas, texte vertical au-dessus.
	for cg in n_cols:
		var cc: int = _col_cats[cg]
		for cv in _n:
			var v: Dictionary = cats[cc].values[cv]
			var cx := origin.x + (cg * _n + cv) * _cell + _cell * 0.5
			_draw_value_icon(v, Vector2(cx, _label_w - ic * 0.5 - 6), ic)
			var asc := _font.get_ascent(_font_size)
			draw_set_transform(Vector2(cx + asc * 0.36, _label_w - ic - 14), -PI / 2.0)
			draw_string(_font, Vector2.ZERO, v.short, HORIZONTAL_ALIGNMENT_LEFT, _label_w - ic - 20, _font_size, COL_TEXT)
			draw_set_transform(Vector2.ZERO)


func _draw_value_icon(v: Dictionary, c: Vector2, sz: float) -> void:
	if v.has("avatar"):
		draw_circle(c, sz * 0.48, Color(v.avatar))
		var ch: String = String(v.short).substr(0, 1)
		var fs := _font_size
		var w := _font_bold.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font_bold, c + Vector2(-w * 0.5, _font_bold.get_ascent(fs) * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		return
	if v.has("num"):
		draw_circle(c, sz * 0.48, Color(v.num_color))
		var txt: String = v.num
		var fs := _font_size
		var w := _font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# Sur les très petites cases seulement, le chiffre rétrécit pour rester dans sa pastille.
		if w > sz * 0.82:
			fs = int(fs * sz * 0.82 / w)
			w = _font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font_bold, c + Vector2(-w * 0.5, _font_bold.get_ascent(fs) * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TEXT)
		return
	var tex := UI.icon(v.get("icon", ""))
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false)


static func _back_out(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)


func _draw_cross(p: Vector2, s: float) -> void:
	var c := p + Vector2(_cell, _cell) * 0.5
	var m := _cell * 0.2 * s
	var w: float = max(2.5, _cell * 0.09)
	draw_line(c + Vector2(-m, -m), c + Vector2(m, m), COL_CROSS, w, true)
	draw_line(c + Vector2(m, -m), c + Vector2(-m, m), COL_CROSS, w, true)


func _draw_check(p: Vector2, s: float) -> void:
	var c := p + Vector2(_cell, _cell) * 0.5
	var r := _cell * 0.36 * s
	draw_circle(c + Vector2(0, 2), r, COL_CHECK.darkened(0.25))
	draw_circle(c, r, COL_CHECK)
	var pts := PackedVector2Array([c + Vector2(-0.45, 0.02) * r, c + Vector2(-0.1, 0.36) * r, c + Vector2(0.48, -0.32) * r])
	draw_polyline(pts, Color.WHITE, max(2.0, _cell * 0.08), true)

