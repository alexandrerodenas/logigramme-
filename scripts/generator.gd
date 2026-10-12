class_name PuzzleGenerator
extends RefCounted
## Génère localement des logigrammes à solution unique, sans aucun accès réseau.
## Une grille est entièrement déterminée par sa configuration (voir Worlds).

enum ClueType { SAME, DIFF, EITHER, YOUNGER, EXACT, NEXT, PAIR }

var rng := RandomNumberGenerator.new()
var _perms: Array = []
var _inv_perms: Array = []


## Construit une grille à partir d'une configuration de Worlds (level_config ou daily_config).
## La même configuration donne toujours la même grille.
func generate(cfg: Dictionary) -> Dictionary:
	rng.seed = hash("logigramme-" + String(cfg.seed))
	var n_cats: int = cfg.n_cats
	var n: int = cfg.items
	var pz := {"cfg": cfg, "n_cats": n_cats, "items": n, "ordered": [], "hard": n_cats * n >= 16,
		"pair": cfg.get("pair", false)}

	var cats: Array = [_make_names(n)]
	var defs: Array = _shuffled(cfg.cats)
	for def in defs:
		if def.has("ordered"):
			pz.ordered.append(cats.size())
			cats.append(_make_ordered(String(def.ordered), n))
		else:
			cats.append(_make_category(def, n))
	pz.cats = cats

	# Solution : sol[c][e] = indice de la valeur de la catégorie c pour l'entité e.
	var sol: Array = []
	for c in n_cats:
		sol.append(range(n) if c == 0 else _shuffled(range(n)))
	pz.solution = sol

	_prepare_perms(n)
	var clues: Array = []
	var texts := {}
	var guard := 0
	while guard < 500:
		guard += 1
		var clue := _random_clue(pz)
		if clue.is_empty() or texts.has(clue.text):
			continue
		if int(clue.type) == ClueType.PAIR and clues.filter(func(c): return int(c.type) == ClueType.PAIR).size() >= 3:
			continue
		texts[clue.text] = true
		clues.append(clue)
		if clues.size() >= n_cats * 2 and count_solutions(pz, clues, 2) == 1:
			break

	# Retire les indices superflus tant que la solution reste unique.
	var order := _shuffled(range(clues.size()))
	var keep: Array = []
	for i in clues.size():
		keep.append(true)
	for i in order:
		keep[i] = false
		var subset: Array = []
		for j in clues.size():
			if keep[j]:
				subset.append(clues[j])
		if count_solutions(pz, subset, 2) != 1:
			keep[i] = true
	var final_clues: Array = []
	for j in clues.size():
		if keep[j]:
			final_clues.append(clues[j])

	# Les niveaux à indices scellés ont besoin d'au moins un indice direct pour démarrer.
	if cfg.get("mods", []).has("fog") and not final_clues.any(func(c): return int(c.type) == ClueType.SAME):
		var e := rng.randi_range(0, n - 1)
		var pair := _two_cats(n_cats)
		if pair[1] == 0:
			pair = [pair[1], pair[0]]
		var same := {"type": ClueType.SAME, "a": [pair[0], sol[pair[0]][e]], "b": [pair[1], sol[pair[1]][e]]}
		same.text = _clue_text(pz, same)
		final_clues.append(same)
	pz.clues = _shuffled(final_clues)
	return pz


## Vrai si la valeur `va` de la catégorie `a` et la valeur `vb` de la catégorie `b`
## appartiennent à la même personne dans la solution.
static func is_match(pz: Dictionary, a: int, va: int, b: int, vb: int) -> bool:
	var sol: Array = pz.solution
	return sol[a].find(va) == sol[b].find(vb)


# --- Catégories ---------------------------------------------------------------

func _make_names(n: int) -> Dictionary:
	var names := _shuffled(Worlds.NAMES).slice(0, n)
	names.sort()
	var values: Array = []
	for i in names.size():
		var nm: String = names[i]
		values.append({"short": nm, "pred": "est " + nm, "neg": "n'est pas " + nm, "desc": nm, "name": true,
			"avatar": Worlds.AVATAR_COLORS[i % Worlds.AVATAR_COLORS.size()]})
	return {"name": "Prénom", "icon": "detective", "values": values}


func _make_category(def: Dictionary, n: int) -> Dictionary:
	var idx := _shuffled(range(def.values.size())).slice(0, n)
	idx.sort()
	var values: Array = []
	for i in idx:
		var v: Array = def.values[i]
		values.append({"icon": v[0], "short": v[1], "pred": v[2], "neg": v[3], "desc": "la personne qui " + v[2]})
	return {"name": def.name, "icon": def.icon, "values": values}


## Catégorie ordonnée : âges (plus jeune, écart d'années) ou numéros de rue (à gauche, à côté).
func _make_ordered(kind: String, n: int) -> Dictionary:
	var values: Array = []
	if kind == "street":
		for i in n:
			values.append({"short": "n°%d" % (i + 1), "pred": "habite au n°%d" % (i + 1), "neg": "n'habite pas au n°%d" % (i + 1),
				"desc": "la personne du n°%d" % (i + 1), "num": str(i + 1), "num_color": "cfe7ff"})
		return {"name": "Rue", "icon": "house", "values": values, "kind": "street", "step": 1}
	var step: int = [1, 2, 3, 5][rng.randi_range(0, 3)]
	var base := rng.randi_range(8, 40)
	for i in n:
		var age := base + i * step
		values.append({"short": "%d ans" % age, "pred": "a %d ans" % age, "neg": "n'a pas %d ans" % age,
			"desc": "la personne de %d ans" % age, "num": str(age), "num_color": "ffe7a8"})
	return {"name": "Âge", "icon": "hourglass", "values": values, "kind": "age", "step": step}


# --- Indices ------------------------------------------------------------------

func _random_clue(pz: Dictionary) -> Dictionary:
	var n: int = pz.items
	var n_cats: int = pz.n_cats
	var sol: Array = pz.solution
	var ordered: Array = pz.ordered
	var types := [ClueType.SAME, ClueType.DIFF, ClueType.DIFF, ClueType.DIFF, ClueType.EITHER, ClueType.EITHER]
	if not ordered.is_empty():
		types += [ClueType.YOUNGER, ClueType.YOUNGER, ClueType.EXACT]
	var g: int = -1 if ordered.is_empty() else ordered[rng.randi_range(0, ordered.size() - 1)]
	if g >= 0 and pz.cats[g].kind == "street":
		types += [ClueType.NEXT, ClueType.NEXT]
	if pz.pair and n_cats >= 3:
		types.append(ClueType.PAIR)
	if not pz.hard:
		types.append(ClueType.SAME)
	var t: int = types[rng.randi_range(0, types.size() - 1)]
	var e1 := rng.randi_range(0, n - 1)
	var e2 := (e1 + rng.randi_range(1, n - 1)) % n
	var cl := {"type": t}
	match t:
		ClueType.SAME, ClueType.DIFF:
			var pair := _two_cats(n_cats)
			var e_b := e1 if t == ClueType.SAME else e2
			cl.a = [pair[0], sol[pair[0]][e1]]
			cl.b = [pair[1], sol[pair[1]][e_b]]
			if cl.b[0] == 0:
				var tmp = cl.a
				cl.a = cl.b
				cl.b = tmp
		ClueType.EITHER:
			var pair := _two_cats(n_cats)
			if pair[1] == 0:
				pair = [pair[1], pair[0]]
			cl.a = [pair[0], sol[pair[0]][e1]]
			var right := [pair[1], sol[pair[1]][e1]]
			var wrong := [pair[1], sol[pair[1]][e2]]
			if rng.randf() < 0.5:
				cl.b = right
				cl.c = wrong
			else:
				cl.b = wrong
				cl.c = right
		ClueType.YOUNGER, ClueType.EXACT, ClueType.NEXT:
			if t == ClueType.NEXT:
				# Deux entités voisines dans la rue.
				var pos: int = sol[g][e1]
				var nb := pos + (1 if pos == 0 or (pos < n - 1 and rng.randf() < 0.5) else -1)
				e2 = sol[g].find(nb)
			if sol[g][e1] > sol[g][e2]:
				var tmp := e1
				e1 = e2
				e2 = tmp
			var ca := _cat_except(n_cats, g)
			var cb := _cat_except(n_cats, g)
			if t == ClueType.YOUNGER:
				cl.a = [ca, sol[ca][e1]]
				cl.b = [cb, sol[cb][e2]]
			else:
				cl.a = [ca, sol[ca][e2]]
				cl.b = [cb, sol[cb][e1]]
				cl.d = sol[g][e2] - sol[g][e1]
				if t == ClueType.NEXT and rng.randf() < 0.5:
					var tmp = cl.a
					cl.a = cl.b
					cl.b = tmp
			cl.g = g
		ClueType.PAIR:
			# « Parmi X et Y, l'une … et l'autre … » : la troisième catégorie diffère des deux autres.
			var cc := rng.randi_range(1, n_cats - 1)
			var ca := _cat_except(n_cats, cc)
			var cb := _cat_except(n_cats, cc)
			cl.a = [ca, sol[ca][e1]]
			cl.b = [cb, sol[cb][e2]]
			var v1 := [cc, sol[cc][e1]]
			var v2 := [cc, sol[cc][e2]]
			if rng.randf() < 0.5:
				cl.c = v1
				cl.e = v2
			else:
				cl.c = v2
				cl.e = v1
	cl.text = _clue_text(pz, cl)
	return cl


func _two_cats(n_cats: int) -> Array:
	var a := rng.randi_range(0, n_cats - 1)
	var b := (a + rng.randi_range(1, n_cats - 1)) % n_cats
	return [a, b]


func _cat_except(n_cats: int, g: int) -> int:
	var c := rng.randi_range(0, n_cats - 2)
	return c + 1 if c >= g else c


func _val(pz: Dictionary, ref: Array) -> Dictionary:
	return pz.cats[ref[0]].values[ref[1]]


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


static func _vowel(s: String) -> bool:
	return "AEIOUÉÈÊaeiouéèê".contains(s.substr(0, 1))


static func _que(s: String) -> String:
	return "qu'" + s if _vowel(s) else "que " + s


static func _de(s: String) -> String:
	return "d'" + s if _vowel(s) else "de " + s


func _clue_text(pz: Dictionary, cl: Dictionary) -> String:
	var a := _val(pz, cl.a)
	var b := _val(pz, cl.b)
	match int(cl.type):
		ClueType.SAME:
			return _cap(a.desc) + " " + b.pred + "."
		ClueType.DIFF:
			return _cap(a.desc) + " " + b.neg + "."
		ClueType.EITHER:
			var c := _val(pz, cl.c)
			if b.has("name"):
				return _cap(a.desc) + " est " + b.desc + " ou " + c.desc + "."
			return _cap(a.desc) + " " + b.pred + " ou " + c.pred + "."
		ClueType.PAIR:
			var c := _val(pz, cl.c)
			var e := _val(pz, cl.e)
			return "Parmi %s et %s, l'une %s et l'autre %s." % [a.desc, b.desc, c.pred, e.pred]
	var street: bool = pz.cats[cl.g].kind == "street"
	match int(cl.type):
		ClueType.YOUNGER:
			if street:
				return _cap(a.desc) + " habite à gauche " + _de(b.desc) + "."
			return _cap(a.desc) + " est plus jeune " + _que(b.desc) + "."
		ClueType.EXACT:
			if street:
				if int(cl.d) == 1:
					return _cap(a.desc) + " habite juste à droite " + _de(b.desc) + "."
				return _cap(a.desc) + " habite %d maisons à droite " % int(cl.d) + _de(b.desc) + "."
			var years: int = int(cl.d) * int(pz.cats[cl.g].step)
			var unit := "an" if years == 1 else "ans"
			return _cap(a.desc) + " a exactement %d %s de plus " % [years, unit] + _que(b.desc) + "."
		ClueType.NEXT:
			return _cap(a.desc) + " habite à côté " + _de(b.desc) + "."
	return ""


# --- Solveur ------------------------------------------------------------------

func _prepare_perms(n: int) -> void:
	_perms = []
	_permute(range(n), 0)
	_inv_perms = []
	for p in _perms:
		var inv := PackedInt32Array()
		inv.resize(n)
		for e in n:
			inv[p[e]] = e
		_inv_perms.append(inv)


func _permute(arr: Array, k: int) -> void:
	if k == arr.size():
		_perms.append(PackedInt32Array(arr))
		return
	for i in range(k, arr.size()):
		var t = arr[k]
		arr[k] = arr[i]
		arr[i] = t
		_permute(arr, k + 1)
		arr[i] = arr[k]
		arr[k] = t


## Compte les solutions compatibles avec `clues`, en s'arrêtant à `cap`.
func count_solutions(pz: Dictionary, clues: Array, cap: int) -> int:
	var n_cats: int = pz.n_cats
	var n: int = pz.items
	if _perms.is_empty() or _perms[0].size() != n:
		_prepare_perms(n)
	var cats_of: Array = []
	for cl in clues:
		var cs := [cl.a[0], cl.b[0]]
		if cl.has("c"):
			cs.append(cl.c[0])
		if cl.has("g"):
			cs.append(cl.g)
		cats_of.append(cs)

	# Ordre de recherche : à chaque étape, la catégorie qui rend le plus d'indices vérifiables.
	var placed := {0: true}
	var order := [0]
	while order.size() < n_cats:
		var best := -1
		var best_score := -1
		for c in range(1, n_cats):
			if placed.has(c):
				continue
			var score := 0
			for cs in cats_of:
				if cs.has(c) and cs.all(func(x): return x == c or placed.has(x)):
					score += 1
			if score > best_score:
				best_score = score
				best = c
		placed[best] = true
		order.append(best)

	var buckets: Array = []
	var candidates: Array = []
	for k in n_cats:
		buckets.append([])
		candidates.append(range(_perms.size()))
	for i in clues.size():
		var cs: Array = cats_of[i]
		var depth := 0
		for x in cs:
			depth = max(depth, order.find(x))
		buckets[depth].append(clues[i])

	var p: Array = []
	var q: Array = []
	p.resize(n_cats)
	q.resize(n_cats)
	p[0] = _perms[0]
	q[0] = _inv_perms[0]

	# Pré-filtrage : indices ne portant que sur la catégorie 0 et une autre.
	for k in range(1, n_cats):
		var c: int = order[k]
		var local: Array = []
		var rest: Array = []
		for cl in buckets[k]:
			var cs: Array = cats_of[clues.find(cl)]
			if cs.all(func(x): return x == c or x == 0):
				local.append(cl)
			else:
				rest.append(cl)
		if local.is_empty():
			continue
		var kept: Array = []
		for i in _perms.size():
			p[c] = _perms[i]
			q[c] = _inv_perms[i]
			if local.all(func(cl): return _holds(cl, p, q)):
				kept.append(i)
		candidates[k] = kept
		buckets[k] = rest

	var state := {"count": 0}
	_search(1, order, buckets, candidates, p, q, cap, state)
	return state.count


func _search(k: int, order: Array, buckets: Array, candidates: Array, p: Array, q: Array, cap: int, state: Dictionary) -> void:
	if k == order.size():
		state.count += 1
		return
	var c: int = order[k]
	var bucket: Array = buckets[k]
	for i in candidates[k]:
		p[c] = _perms[i]
		q[c] = _inv_perms[i]
		var ok := true
		for cl in bucket:
			if not _holds(cl, p, q):
				ok = false
				break
		if ok:
			_search(k + 1, order, buckets, candidates, p, q, cap, state)
			if state.count >= cap:
				return


static func _holds(cl: Dictionary, p: Array, q: Array) -> bool:
	var ea: int = q[cl.a[0]][cl.a[1]]
	var eb: int = q[cl.b[0]][cl.b[1]]
	match int(cl.type):
		ClueType.SAME:
			return ea == eb
		ClueType.DIFF:
			return ea != eb
		ClueType.EITHER:
			return ea == eb or ea == q[cl.c[0]][cl.c[1]]
		ClueType.YOUNGER:
			return p[cl.g][ea] < p[cl.g][eb]
		ClueType.EXACT:
			return p[cl.g][ea] - p[cl.g][eb] == cl.d
		ClueType.NEXT:
			return abs(p[cl.g][ea] - p[cl.g][eb]) == 1
		ClueType.PAIR:
			if ea == eb:
				return false
			var cc: int = cl.c[0]
			var va: int = p[cc][ea]
			var vb: int = p[cc][eb]
			var c1: int = cl.c[1]
			var c2: int = cl.e[1]
			return (va == c1 and vb == c2) or (va == c2 and vb == c1)
	return false


func _shuffled(arr: Array) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out
