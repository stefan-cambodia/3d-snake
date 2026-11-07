extends SceneTree
## Headless test runner.
##   godot --headless --path . -s tests/run_tests.gd [-- --filter=<substring>]
## Runs every `test_*` method of every tests/test_*.gd suite. Exit code 0 = pass.

func _initialize() -> void:
	# Wait until the root viewport is inside the tree, so suites can instance real
	# scenes (their _ready() runs on add_child).
	await process_frame
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	var total := 0
	var failed := 0
	var checks := 0
	var t0 := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null:
			print("[LOAD ERROR] ", f)
			failed += 1
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_") and not methods.has(mname):
				methods.append(mname)
		for mname in methods:
			if filter != "" and not (f + ":" + mname).contains(filter):
				continue
			var suite: TestCase = script.new()
			suite.tree = self
			var start := Time.get_ticks_usec()
			# Awaiting also lets a test wait for frames (e.g. container layout).
			await suite.call(mname)
			var ms := float(Time.get_ticks_usec() - start) / 1000.0
			total += 1
			checks += suite.checks
			if suite.failures.is_empty():
				print("  PASS  %s :: %s  (%d checks, %.1f ms)" % [f.get_basename(), mname, suite.checks, ms])
			else:
				failed += 1
				print("  FAIL  %s :: %s" % [f.get_basename(), mname])
				for msg in suite.failures:
					print("        - ", msg)
	print("")
	print("%d tests, %d checks, %d failed  (%.2f s)" % [total, checks, failed, float(Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failed > 0 else 0)
