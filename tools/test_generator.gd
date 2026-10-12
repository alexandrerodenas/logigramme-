extends SceneTree
# Lancer : godot --headless --script tools/test_generator.gd
# Vérifie que chaque niveau du parcours (et quelques défis du jour) a une solution unique.

func _init() -> void:
	var gen := PuzzleGenerator.new()
	var failures := 0
	var worst := 0
	var configs: Array = []
	for w in Worlds.world_count():
		for l in range(1, Worlds.LEVELS_PER_WORLD + 1):
			configs.append(Worlds.level_config(w, l))
	for d in ["2026-01-01", "2026-06-15", "2026-10-12"]:
		configs.append(Worlds.daily_config(d))
	for cfg in configs:
		var t0 := Time.get_ticks_msec()
		var pz := gen.generate(cfg)
		var ms := Time.get_ticks_msec() - t0
		worst = max(worst, ms)
		var uniq := gen.count_solutions(pz, pz.clues, 2)
		if uniq != 1:
			failures += 1
			print("ECHEC ", cfg.seed)
		if cfg.seed.ends_with("niveau-1") or cfg.has("daily"):
			print("%s : %d×%d, %d indices, %d ms" % [cfg.seed, cfg.n_cats, cfg.items, pz.clues.size(), ms])
			for c in pz.cats:
				print("   ", c.name, ": ", c.values.map(func(v): return v.short))
			for cl in pz.clues:
				print("   - ", cl.text)
	var a := gen.generate(Worlds.level_config(3, 9))
	var b := gen.generate(Worlds.level_config(3, 9))
	print("déterministe: ", a.clues.map(func(c): return c.text) == b.clues.map(func(c): return c.text))
	print("grilles: %d, pire temps: %d ms" % [configs.size(), worst])
	print("ECHECS: ", failures)
	quit(1 if failures else 0)
