class_name FieldView
extends Control

## One alfalfa field. Draws its aphids (coloured by clone), its wasps, its shelter, and
## its harvest countdown. Clicking it cycles the shelter level.

signal shelter_clicked(field_index: int)

const SUSCEPTIBLE := Color("#5fd38d")
const RESISTANT := Color("#b98cf5")
const WASP := Color("#f7a03c")
const CROP := Color("#2a3a2c")
const CROP_CUT := Color("#3a3527")
const EDGE := Color("#4d5f51")
const EDGE_HOVER := Color("#8fd0a6")
const SHELTER_COLOR := Color("#6f9e78")
const TEXT := Color("#d8e2da")
const TEXT_DIM := Color("#8b998f")

const MAX_DOTS := 90
const MAX_WASP_MARKS := 22
const APHIDS_PER_DOT := 7.0
const WASPS_PER_MARK := 1.6

var field_index: int = 0
var sim: EcoSim = null
var field_name: String = ""

var _dot_positions: Array[Vector2] = []
var _dot_order: Array[int] = []
var _wasp_positions: Array[Vector2] = []
var _hovered := false
var _flash := 0.0          ## harvest flash, decays to 0
var _time := 0.0


func setup(index: int, simulation: EcoSim, display_name: String) -> void:
	field_index = index
	sim = simulation
	field_name = display_name
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click to add or remove shelter habitat"
	_rebuild_layout()


func _rebuild_layout() -> void:
	# Deterministic scatter, so dots don't jump around between frames.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + field_index
	_dot_positions.clear()
	_dot_order.clear()
	for i in MAX_DOTS:
		_dot_positions.append(Vector2(rng.randf(), rng.randf()))
		_dot_order.append(i)
	# Shuffling which dots are "resistant" keeps the two clones spatially mixed.
	for i in range(_dot_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = _dot_order[i]
		_dot_order[i] = _dot_order[j]
		_dot_order[j] = tmp
	_wasp_positions.clear()
	for i in MAX_WASP_MARKS:
		_wasp_positions.append(Vector2(rng.randf(), rng.randf()))


func flash_harvest() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Called once per simulated day, so the post-harvest flash fades at the same rate
## whatever speed the player is running at.
func tick_day() -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - 0.16)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		shelter_clicked.emit(field_index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false


func _draw() -> void:
	if sim == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	var font := ThemeDB.fallback_font

	var days_to_cut := _days_until_harvest()
	var regrowth: float = clampf(float(sim.days_per_cycle() - days_to_cut) / 12.0, 0.0, 1.0)
	var bg := CROP_CUT.lerp(CROP, regrowth)
	if _flash > 0.0:
		bg = bg.lerp(Color("#e8e2c8"), _flash * 0.7)
	draw_rect(r, bg, true)

	# Shelter habitat: a hedge along the field edge, one band per level.
	var shelter_level: int = sim.shelter[field_index]
	for s in shelter_level:
		var inset := 3.0 + s * 4.0
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			SHELTER_COLOR.lerp(Color.TRANSPARENT, 0.45), false, 2.5)

	var border := EDGE_HOVER if _hovered else EDGE
	draw_rect(r, border, false, 2.0 if _hovered else 1.0)

	_draw_populations(font)
	_draw_labels(font, days_to_cut, shelter_level)


func _draw_populations(font: Font) -> void:
	var pad := 16.0
	var top := 26.0
	var area := Rect2(pad, top, size.x - pad * 2.0, size.y - top - 26.0)

	var total: float = sim.susceptible[field_index] + sim.resistant[field_index]
	var dots: int = clampi(int(round(total / APHIDS_PER_DOT)), 0, MAX_DOTS)
	var q := sim.field_resistant_fraction(field_index)
	var resistant_dots: int = 0 if is_nan(q) else int(round(float(dots) * q))

	for idx in dots:
		var pos: Vector2 = _dot_positions[idx]
		var p := Vector2(area.position.x + pos.x * area.size.x,
			area.position.y + pos.y * area.size.y)
		var is_resistant: bool = _dot_order[idx] < resistant_dots
		draw_circle(p, 2.6, RESISTANT if is_resistant else SUSCEPTIBLE)

	# Wasps drift above the crop.
	var wasp_marks: int = clampi(int(round(sim.wasps[field_index] / WASPS_PER_MARK)),
		0, MAX_WASP_MARKS)
	for idx in wasp_marks:
		var pos: Vector2 = _wasp_positions[idx]
		var bob := sin(_time * 2.2 + float(idx) * 1.7) * 3.0
		var p := Vector2(area.position.x + pos.x * area.size.x,
			area.position.y + pos.y * area.size.y + bob)
		draw_line(p + Vector2(-3, -2), p, WASP, 1.6)
		draw_line(p + Vector2(3, -2), p, WASP, 1.6)


func _draw_labels(font: Font, days_to_cut: int, shelter_level: int) -> void:
	var inner := size.x - 16.0
	draw_string(font, Vector2(8, 16), field_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)

	var shelter_text := "shelter " + ("–" if shelter_level == 0 else "+".repeat(shelter_level))
	draw_string(font, Vector2(8, 16), shelter_text, HORIZONTAL_ALIGNMENT_RIGHT, inner, 11,
		SHELTER_COLOR if shelter_level > 0 else TEXT_DIM)

	var total: float = sim.susceptible[field_index] + sim.resistant[field_index]
	var q := sim.field_resistant_fraction(field_index)
	var q_text := "--" if is_nan(q) else "%d%% resistant" % int(round(q * 100.0))
	draw_string(font, Vector2(8, size.y - 8),
		"%d aphids · %s" % [int(round(total * EcoSim.IND_SCALE)), q_text],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_DIM)

	var cut_text := "cut today" if days_to_cut == 0 else "cut in %dd" % days_to_cut
	draw_string(font, Vector2(8, size.y - 8), cut_text, HORIZONTAL_ALIGNMENT_RIGHT, inner,
		11, TEXT_DIM)


func _days_until_harvest() -> int:
	return sim.days_until_harvest(field_index)
