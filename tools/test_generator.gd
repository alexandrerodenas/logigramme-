extends SceneTree
# Lancer : godot --headless --script tools/test_generator.gd

func _init() -> void:
	var gen := PuzzleGenerator.new()
	var failures := 0
	for d in 3:
		for level in range(1, 9):
			var t0 := Time.get_ticks_msec()
			var pz := gen.generate(d, level)
			var ms := Time.get_ticks_msec() - t0
			var uniq := gen.count_solutions(pz, pz.clues, 2)
			if uniq != 1:
				failures += 1
			print("diff=%d niveau=%d indices=%d unique=%s %d ms" % [d, level, pz.clues.size(), uniq == 1, ms])
			if level == 1:
				for c in pz.cats:
					print("   ", c.name, ": ", c.values.map(func(v): return v.short))
				for cl in pz.clues:
					print("   - ", cl.text)
	var a := gen.generate(2, 5)
	var b := gen.generate(2, 5)
	print("déterministe: ", a.clues.map(func(c): return c.text) == b.clues.map(func(c): return c.text))
	print("ECHECS: ", failures)
	quit(1 if failures else 0)
