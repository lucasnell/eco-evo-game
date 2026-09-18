extends SceneTree

## Drives the real game scene and saves screenshots, so UI problems are visible and
## separable from simulation problems. Run:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://test/capture.gd
##   ... --headless is NOT used here: we need real rendering.
## Add `-- fail` to play a deliberately bad landscape and capture the failure read-out.
## Screenshots land in shots/.

var frames := 0
var game: Node = null
var shots_taken := 0
var errors: Array[String] = []
var failing := false
var prefix := "ok"


func _initialize() -> void:
	failing = OS.get_cmdline_user_args().has("fail")
	prefix = "fail" if failing else "ok"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1

	if frames == 8 and not failing:
		_shot("01-briefing")

	if frames == 12:
		game._on_begin()
		if failing:
			# No corridors at all, and shelter spread evenly over every field: the two
			# ways to kill the parasitoid.
			for i in 6:
				game._on_shelter_clicked(i)
		else:
			# Some corridors, shelter concentrated on a couple of fields.
			for c in [0, 2, 5, 6]:
				game._on_corridor_toggled(c)
			for f in [1, 1, 3, 3]:
				game._on_shelter_clicked(f)
		# Step days directly rather than leaning on wall-clock speed, so the captures
		# land on the same days every run.
		game.paused = true
		_advance(232)

	if frames == 20:
		_shot("%s-02-midyear" % prefix)
		_advance(504 - game.sim.day)

	if frames == 28:
		_shot("%s-03-endofyear" % prefix)
		print("day %d, phase %d (2 = ENDED)" % [game.sim.day, game.phase])
		_report()
		return true

	return false


func _advance(days: int) -> void:
	for d in days:
		if game.phase != 1:   # Phase.PLAYING
			return
		game._advance_one_day()


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var path := ProjectSettings.globalize_path("res://shots/%s.png" % name)
	var err := img.save_png(path)
	if err != OK:
		errors.append("could not save %s (error %d)" % [name, err])
	else:
		shots_taken += 1
		print("saved %s" % path)


func _report() -> void:
	if errors.is_empty():
		print("capture OK: %d screenshots" % shots_taken)
	else:
		for e in errors:
			print("CAPTURE ERROR: " + e)
