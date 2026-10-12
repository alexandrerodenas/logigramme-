class_name GridView
extends Control
## Grille de logigramme en escalier : chaque bloc croise deux catégories.
## Un appui fait défiler une case : vide → ✗ → ✓ → vide.

signal changed
signal solved

const EMPTY := 0
const CROSS := 1
const CHECK := 2

const COL_BG := Color("fffdf7")
const COL_LINE := Color("c9c2b0")
const COL_LINE_STRONG := Color("4a4335")
const COL_TEXT := Color("2b2620")
const COL_CROSS := Color("b23a2e")
const COL_CHECK := Color("2e7d4f")
const COL_ERROR := Color(1, 0.3, 0.25, 0.35)
const COL_HILITE := Color(0.95, 0.8, 0.35, 0.25)

var pz: Dictionary
var marks := {}          # "a_b" (a < b) -> PackedByteArray de taille n*n
var errors := {}         # "a_b:idx" -> true
var undo_stack: Array = []
var is_solved := false

var _n := 0
var _row_cats: Array = []
var _col_cats: Array = []
var _cell := 40.0
var _label_w := 120.0
var _font: Font
var _font_size := 16
var _hover := Vector2i(-1, -1)


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
					arr[i] = int(src[i])
			marks[key] = arr
	undo_stack.clear()
	errors.clear()
	is_solved = _check_solved()
	_font = get_theme_default_font()
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


func _relayout() -> void:
	var cols := _col_cats.size() * _n
	var w := size.x
	# La zone des libellés vaut environ 2,6 cases.
	_cell = floor(w / (cols + 2.6))
	_label_w = w - cols * _cell
	_font_size = int(clamp(_cell * 0.3, 11, 22))
	custom_minimum_size.y = _label_w + _row_cats.size() * _n * _cell + 2


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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _cell_at(event.position)
		if hit.is_empty() or is_solved:
			return
		_tap(hit)
		accept_event()


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
		# Un ✓ exclut le reste de sa ligne et de sa colonne dans ce bloc.
		for v in _n:
			if v != cv and get_mark(rc, rv, cc, v) == EMPTY:
				_set_mark(rc, rv, cc, v, CROSS, action)
			if v != rv and get_mark(rc, v, cc, cv) == EMPTY:
				_set_mark(rc, v, cc, cv, CROSS, action)
	_hover = Vector2i(hit[4] * _n + rv, hit[5] * _n + cv)
	_commit(action)


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


func undo() -> void:
	if undo_stack.is_empty() or is_solved:
		return
	var action: Array = undo_stack.pop_back()
	for i in range(action.size() - 1, -1, -1):
		var e: Array = action[i]
		var arr: PackedByteArray = marks[e[0]]
		arr[e[1]] = e[2]
		marks[e[0]] = arr
	errors.clear()
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
			if arr[i] == EMPTY:
				continue
			var ok := PuzzleGenerator.is_match(pz, a, i / _n, b, i % _n)
			if (arr[i] == CHECK) != ok:
				errors["%s:%d" % [k, i]] = true
	queue_redraw()
	return errors.size()


## Fait apparaître un ✓ correct pas encore trouvé. Renvoie false s'il n'y en a plus.
func reveal_one() -> bool:
	for rg in _row_cats.size():
		for cg in _col_cats.size():
			if not _block_exists(rg, cg):
				continue
			var rc: int = _row_cats[rg]
			var cc: int = _col_cats[cg]
			for rv in _n:
				for cv in _n:
					if PuzzleGenerator.is_match(pz, rc, rv, cc, cv) and get_mark(rc, rv, cc, cv) != CHECK:
						var action: Array = []
						_set_mark(rc, rv, cc, cv, CHECK, action)
						for v in _n:
							if v != cv:
								_set_mark(rc, rv, cc, v, CROSS, action)
							if v != rv:
								_set_mark(rc, v, cc, cv, CROSS, action)
						_hover = Vector2i(rg * _n + rv, cg * _n + cv)
						_commit(action)
						return true
	return false


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


# --- Dessin -------------------------------------------------------------------

func _draw() -> void:
	if pz.is_empty():
		return
	var cats: Array = pz.cats
	var n_cols := _col_cats.size()
	var n_rows := _row_cats.size()
	var origin := Vector2(_label_w, _label_w)

	# Fond des blocs et surbrillance de la ligne/colonne active.
	for rg in n_rows:
		for cg in n_cols:
			if not _block_exists(rg, cg):
				continue
			var r := Rect2(origin + Vector2(cg * _n, rg * _n) * _cell, Vector2(_n, _n) * _cell)
			draw_rect(r, COL_BG)
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

	# Marques.
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
					if errors.has("%s:%d" % ki):
						draw_rect(Rect2(p, Vector2(_cell, _cell)), COL_ERROR)
					var m: int = marks[ki[0]][ki[1]]
					if m == CROSS:
						_draw_cross(p)
					elif m == CHECK:
						_draw_check(p)

	# Lignes fines puis contours épais des blocs.
	for rg in n_rows:
		for cg in n_cols:
			if not _block_exists(rg, cg):
				continue
			var p0 := origin + Vector2(cg * _n, rg * _n) * _cell
			for i in range(1, _n):
				draw_line(p0 + Vector2(i * _cell, 0), p0 + Vector2(i * _cell, _n * _cell), COL_LINE, 1.0)
				draw_line(p0 + Vector2(0, i * _cell), p0 + Vector2(_n * _cell, i * _cell), COL_LINE, 1.0)
			draw_rect(Rect2(p0, Vector2(_n, _n) * _cell), COL_LINE_STRONG, false, 2.0)

	# Libellés des lignes (à gauche).
	var asc := _font.get_ascent(_font_size)
	for rg in n_rows:
		var rc: int = _row_cats[rg]
		for rv in _n:
			var txt: String = cats[rc].values[rv].short
			var y := origin.y + (rg * _n + rv) * _cell + _cell * 0.5 + asc * 0.35
			draw_string(_font, Vector2(6, y), txt, HORIZONTAL_ALIGNMENT_RIGHT, _label_w - 14, _font_size, COL_TEXT)
		draw_line(Vector2(4, origin.y + rg * _n * _cell), Vector2(_label_w, origin.y + rg * _n * _cell), COL_LINE_STRONG, 2.0)
	draw_line(Vector2(4, origin.y + n_rows * _n * _cell), Vector2(_label_w, origin.y + n_rows * _n * _cell), COL_LINE_STRONG, 2.0)

	# Libellés des colonnes (en haut, verticaux).
	for cg in n_cols:
		var cc: int = _col_cats[cg]
		for cv in _n:
			var txt: String = cats[cc].values[cv].short
			var x := origin.x + (cg * _n + cv) * _cell + _cell * 0.5 + asc * 0.35
			draw_set_transform(Vector2(x, _label_w - 8), -PI / 2.0)
			draw_string(_font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, _label_w - 14, _font_size, COL_TEXT)
		draw_set_transform(Vector2.ZERO)
		draw_line(Vector2(origin.x + cg * _n * _cell, 4), Vector2(origin.x + cg * _n * _cell, _label_w), COL_LINE_STRONG, 2.0)
	draw_line(Vector2(origin.x + n_cols * _n * _cell, 4), Vector2(origin.x + n_cols * _n * _cell, _label_w), COL_LINE_STRONG, 2.0)


func _draw_cross(p: Vector2) -> void:
	var m := _cell * 0.3
	var w: float = max(2.0, _cell * 0.07)
	draw_line(p + Vector2(m, m), p + Vector2(_cell - m, _cell - m), COL_CROSS, w, true)
	draw_line(p + Vector2(_cell - m, m), p + Vector2(m, _cell - m), COL_CROSS, w, true)


func _draw_check(p: Vector2) -> void:
	var c := p + Vector2(_cell, _cell) * 0.5
	draw_circle(c, _cell * 0.36, COL_CHECK)
	var s := _cell * 0.36
	var pts := PackedVector2Array([c + Vector2(-0.5, 0.0) * s, c + Vector2(-0.12, 0.38) * s, c + Vector2(0.52, -0.36) * s])
	draw_polyline(pts, Color.WHITE, max(2.0, _cell * 0.08), true)
