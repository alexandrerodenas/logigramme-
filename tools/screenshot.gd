extends SceneTree
# Capture d'écran de contrôle : godot --script tools/screenshot.gd -- <difficulté> <sortie.png>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var d := int(args[0]) if args.size() > 0 else 1
	var out := args[1] if args.size() > 1 else "user://shot.png"
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	main._start(d, 1)
	for i in 120:
		await process_frame
		if main._grid.visible:
			break
	main._grid._tap(main._grid._cell_at(Vector2(main._grid._label_w + 5, main._grid._label_w + 5)))
	main._grid._tap(main._grid._cell_at(Vector2(main._grid._label_w + 5, main._grid._label_w + 5)))
	main._grid._tap(main._grid._cell_at(Vector2(main._grid._label_w + 5, main._grid._label_w + 5 + main._grid._cell * 2)))
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
