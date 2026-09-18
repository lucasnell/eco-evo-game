class_name TimeChart
extends Control

## Landscape-wide history: how many aphids, how many wasps, and what fraction of the
## aphids carry resistance. The whole lesson is visible in the shape of these three
## lines and the delay between them.

const APHID_COLOR := Color("#5fd38d")
const WASP_COLOR := Color("#f7a03c")
const RESIST_COLOR := Color("#b98cf5")
const GRID := Color("#2c3531")
const TEXT_DIM := Color("#8b998f")

var aphids: PackedFloat32Array = PackedFloat32Array()
var wasps: PackedFloat32Array = PackedFloat32Array()
var resistant_fraction: PackedFloat32Array = PackedFloat32Array()
var total_days: int = 504
var cycle_days: int = 28


func record(aphid_total: float, wasp_total: float, q: float) -> void:
	aphids.append(aphid_total)
	wasps.append(wasp_total)
	resistant_fraction.append(0.0 if is_nan(q) else q)
	queue_redraw()


func clear_history() -> void:
	aphids = PackedFloat32Array()
	wasps = PackedFloat32Array()
	resistant_fraction = PackedFloat32Array()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var plot := Rect2(34, 14, size.x - 44, size.y - 38)
	draw_rect(plot, Color("#161c19"), true)

	# One vertical line per harvest cycle.
	var cycles := int(ceil(float(total_days) / float(cycle_days)))
	for c in range(1, cycles):
		var x: float = plot.position.x + plot.size.x * float(c * cycle_days) / float(total_days)
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), GRID, 1.0)

	if aphids.size() < 2:
		draw_string(font, Vector2(plot.position.x + 8, plot.position.y + 18),
			"the year starts when you press play", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_DIM)
		return

	var max_aphids := 1.0
	var max_wasps := 1.0
	for v in aphids:
		max_aphids = maxf(max_aphids, v)
	for v in wasps:
		max_wasps = maxf(max_wasps, v)

	_draw_series(aphids, max_aphids, plot, APHID_COLOR)
	_draw_series(wasps, max_wasps, plot, WASP_COLOR)
	_draw_series(resistant_fraction, 1.0, plot, RESIST_COLOR, 2.2)

	draw_string(font, Vector2(2, plot.position.y + 8), "100%",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TEXT_DIM)
	draw_string(font, Vector2(2, plot.end.y), "0",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, TEXT_DIM)
	draw_string(font, Vector2(plot.position.x, size.y - 3),
		"aphids (green) · wasps (orange) · %% resistant (purple)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, TEXT_DIM)


func _draw_series(series: PackedFloat32Array, maximum: float, plot: Rect2,
		color: Color, width: float = 1.6) -> void:
	var points := PackedVector2Array()
	for i in series.size():
		var x: float = plot.position.x + plot.size.x * float(i) / float(maxi(total_days - 1, 1))
		var y: float = plot.end.y - plot.size.y * clampf(series[i] / maximum, 0.0, 1.0)
		points.append(Vector2(x, y))
	if points.size() >= 2:
		draw_polyline(points, color, width, true)
