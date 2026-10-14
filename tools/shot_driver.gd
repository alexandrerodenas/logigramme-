extends Node
# Parcourt les écrans et enregistre des captures dans $LOGIGRAMME_SHOTS.
# xvfb-run godot --rendering-driver opengl3 --resolution 720x1280 (avec LOGIGRAMME_SHOTS=/dossier)

var out := ""


func _ready() -> void:
	out = OS.get_environment("LOGIGRAMME_SHOTS")
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)


func _run() -> void:
	var main = get_parent()
	Game.data.coins = 240
	await _wait(1.0)
	await _shot("1_accueil_bienvenue")
	main.close_popup()
	await _wait(0.6)
	await _shot("2_accueil")
	main.go("map", {"focus": [0, 1]})
	await _wait(1.5)
	await _shot("3_parcours")
	main.screen._on_node(0, 1)
	await _wait(0.8)
	await _shot("4_popup_niveau")
	main.close_popup()
	Game.data.tutorial = true
	main.go("game", {"world": 0, "level": 4})
	await _wait(2.0)
	var gs = main.screen
	var g: GridView = gs._grid
	g._tap(g._cell_at(Vector2(g._label_w + 5, g._label_w + 5)))
	g._tap(g._cell_at(Vector2(g._label_w + 5, g._label_w + 5)))
	g._tap(g._cell_at(Vector2(g._label_w + 5 + g._cell * 4, g._label_w + 5 + g._cell * 2)))
	gs._apply_aid("verify")
	await _wait(0.8)
	await _shot("5_partie")
	# Valider une grille incomplète : rien n'est compté faux.
	await _wait(2.5)
	gs._submit()
	await _wait(0.6)
	await _shot("50_valider_incomplet")
	await _wait(2.5)
	# Grille pleine mais fausse (pastilles décalées d'un cran) puis validation.
	for k in g.marks:
		if not String(k).begins_with("0_"):
			continue
		var ab: PackedStringArray = k.split("_")
		var arr: PackedByteArray = g.marks[k]
		arr.fill(GridView.EMPTY)
		for rv in g._n:
			for cv in g._n:
				if PuzzleGenerator.is_match(g.pz, int(ab[0]), rv, int(ab[1]), cv):
					arr[rv * g._n + (cv + 1) % g._n] = GridView.CHECK
		g.marks[k] = arr
	g._commit([["0_1", 0, 0]])
	await _wait(1.2)
	await _shot("51_grille_pleine")
	gs._submit()
	await _wait(0.6)
	await _shot("52_valider_faux")
	await _wait(2.5)
	# Résout la grille d'un coup pour voir la victoire.
	for k in g.marks:
		var ab: PackedStringArray = k.split("_")
		var arr: PackedByteArray = g.marks[k]
		for i in arr.size():
			arr[i] = GridView.CHECK if PuzzleGenerator.is_match(g.pz, int(ab[0]), i / g._n, int(ab[1]), i % g._n) else GridView.CROSS
		g.marks[k] = arr
	gs.elapsed = 20.0
	g._commit([["0_1", 0, 0]])
	gs._submit()
	await _wait(3.5)
	await _shot("6_victoire")
	main.close_popup()
	main.go("game", {"world": 4, "level": 2})
	await _wait(4.0)
	await _shot("7_partie_observatoire")
	Game.data.levels["0-15"] = {"stars": 3, "time": 10.0}
	main.go("map", {"focus": [1, 1]})
	await _wait(2.6)
	await _shot("8_parcours_cafe")
	main.close_popup()
	main.go("trophies")
	await _wait(1.0)
	await _shot("9_trophees")
	get_tree().quit()
