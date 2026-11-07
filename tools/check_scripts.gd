extends SceneTree
func _initialize() -> void:
	var dirs := ["res://scripts", "res://tests"]
	var bad := 0
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		var da := DirAccess.open(d)
		for sub in da.get_directories():
			dirs.append(d + "/" + sub)
		for f in da.get_files():
			if f.ends_with(".gd"):
				var s: GDScript = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					print("BAD: ", d + "/" + f)
					bad += 1
	print("checked, bad=", bad)
	quit(bad)
