class_name CorridorView
extends Control

## A clickable strip of habitat between two fields. Open it and winged aphids can move
## between those fields; leave it closed and they stay put.

signal toggled(corridor_index: int)

const OPEN_COLOR := Color("#7fc99a")
const CLOSED_COLOR := Color("#39463c")
const HOVER_COLOR := Color("#a8e6bf")

var corridor_index: int = 0
var is_open := false
var horizontal := true

var _hovered := false
var _pulse := 0.0


func setup(index: int, is_horizontal: bool) -> void:
	corridor_index = index
	horizontal = is_horizontal
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click to open or close this corridor"


func set_open(value: bool) -> void:
	if value != is_open:
		_pulse = 1.0
	is_open = value
	queue_redraw()


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.0)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit(corridor_index)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		queue_redraw()


func _draw() -> void:
	var color := OPEN_COLOR if is_open else CLOSED_COLOR
	if _hovered:
		color = HOVER_COLOR if is_open else color.lerp(HOVER_COLOR, 0.4)
	if _pulse > 0.0:
		color = color.lerp(Color.WHITE, _pulse * 0.5)

	var thickness := 7.0 if is_open else 3.0
	if horizontal:
		var y := size.y * 0.5
		if is_open:
			draw_line(Vector2(2, y), Vector2(size.x - 2, y), color, thickness)
		else:
			# a closed corridor is drawn as a broken line
			var seg := (size.x - 4.0) / 5.0
			for i in 3:
				var x0 := 2.0 + seg * float(i * 2)
				draw_line(Vector2(x0, y), Vector2(x0 + seg * 0.8, y), color, thickness)
	else:
		var x := size.x * 0.5
		if is_open:
			draw_line(Vector2(x, 2), Vector2(x, size.y - 2), color, thickness)
		else:
			var seg := (size.y - 4.0) / 5.0
			for i in 3:
				var y0 := 2.0 + seg * float(i * 2)
				draw_line(Vector2(x, y0), Vector2(x, y0 + seg * 0.8), color, thickness)
