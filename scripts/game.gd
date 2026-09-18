extends Control

## Game of Clones — an eco-evolutionary field experiment.
##
## You manage a landscape of six alfalfa fields. You never touch the aphids themselves:
## you open corridors between fields and plant shelter habitat, and the aphids and their
## parasitoid wasps do the rest. Keep all three alive for a year — the wasps, the
## susceptible aphids, and the resistant ones — without blending your fields into one.

const FIELDS := 6
const YEAR_CYCLES := 18
const START_CREW := 6
const CREW_PER_CYCLE := 2
const MAX_CREW := 10

const FIELD_NAMES := ["North", "Ridge", "East", "Hollow", "Creek", "South"]

## (field a, field b, drawn horizontally?) for the 3 x 2 layout:  0 1 2
##                                                               3 4 5
const CORRIDORS: Array = [
	[0, 1, true], [1, 2, true], [3, 4, true], [4, 5, true],
	[0, 3, false], [1, 4, false], [2, 5, false],
]

const MOSAIC_GOOD := 0.04   ## between-field variation that counts as a living mosaic

const BG := Color("#12161a")
const PANEL := Color("#1b2220")
const TEXT := Color("#d8e2da")
const TEXT_DIM := Color("#8b998f")
const GOOD := Color("#5fd38d")
const WARN := Color("#f7a03c")
const BAD := Color("#e8697d")

enum Phase { BRIEFING, PLAYING, ENDED }

var sim: EcoSim
var phase: int = Phase.BRIEFING
var crew: int = START_CREW
var days_per_second: float = 8.0
var paused := true
var _accum := 0.0
var _cycles_done := 0

# history, for the end-of-year read-out
var _hist_wasps: Array[float] = []
var _hist_q: Array[float] = []
var _hist_mosaic: Array[float] = []
var _wasp_death_day := -1
var _resistant_death_day := -1
var _susceptible_death_day := -1

# UI
var _field_views: Array[FieldView] = []
var _corridor_views: Array[CorridorView] = []
var _chart: TimeChart
var _day_label: Label
var _crew_label: Label
var _log_label: Label
var _meters: Control
var _overlay: Control
var _speed_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_new_game()
	_build_ui()
	_show_briefing()


func _new_game() -> void:
	sim = EcoSim.new(FIELDS, randi())
	crew = START_CREW
	paused = true
	_accum = 0.0
	_cycles_done = 0
	_hist_wasps.clear()
	_hist_q.clear()
	_hist_mosaic.clear()
	_wasp_death_day = -1
	_resistant_death_day = -1
	_susceptible_death_day = -1


# --- layout --------------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_header()
	_build_landscape()
	_build_side_panel()
	_build_footer()


func _label(text: String, pos: Vector2, font_size: int, color: Color,
		width: float = 0.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	add_child(l)
	if width > 0.0:
		l.size = Vector2(width, l.get_combined_minimum_size().y)
	return l


func _build_header() -> void:
	_label("GAME OF CLONES", Vector2(24, 14), 20, TEXT)
	_label("a landscape you manage · aphids and wasps you do not",
		Vector2(24, 40), 11, TEXT_DIM)

	_day_label = _label("", Vector2(470, 20), 15, TEXT)

	var labels := ["Pause", "Play", "Fast"]
	var speeds := [0.0, 8.0, 32.0]
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.position = Vector2(1080 + i * 62, 16)
		b.size = Vector2(58, 30)
		b.pressed.connect(_on_speed_pressed.bind(speeds[i]))
		add_child(b)
		_speed_buttons.append(b)


func _build_landscape() -> void:
	var origin := Vector2(24, 76)
	var area := Vector2(856, 464)
	var gap := 26.0
	var fw: float = (area.x - gap * 2.0) / 3.0
	var fh: float = (area.y - gap) / 2.0

	for i in FIELDS:
		var col: int = i % 3
		var row: int = i / 3
		var fv := FieldView.new()
		fv.position = origin + Vector2(col * (fw + gap), row * (fh + gap))
		fv.size = Vector2(fw, fh)
		fv.setup(i, sim, FIELD_NAMES[i])
		fv.shelter_clicked.connect(_on_shelter_clicked)
		add_child(fv)
		_field_views.append(fv)

	for ci in CORRIDORS.size():
		var spec: Array = CORRIDORS[ci]
		var a: int = spec[0]
		var horizontal: bool = spec[2]
		var col: int = a % 3
		var row: int = a / 3
		var cv := CorridorView.new()
		cv.setup(ci, horizontal)
		if horizontal:
			cv.position = origin + Vector2(col * (fw + gap) + fw, row * (fh + gap) + fh * 0.5 - 22.0)
			cv.size = Vector2(gap, 44)
		else:
			cv.position = origin + Vector2(col * (fw + gap) + fw * 0.5 - 22.0, fh)
			cv.size = Vector2(44, gap)
		cv.toggled.connect(_on_corridor_toggled)
		add_child(cv)
		_corridor_views.append(cv)


func _build_side_panel() -> void:
	var x := 904.0
	var panel := ColorRect.new()
	panel.color = PANEL
	panel.position = Vector2(x - 12, 76)
	panel.size = Vector2(364, 464)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_label("THE YEAR SO FAR", Vector2(x, 88), 11, TEXT_DIM)

	_meters = Control.new()
	_meters.position = Vector2(x, 110)
	_meters.size = Vector2(340, 120)
	_meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meters.draw.connect(_draw_meters)
	add_child(_meters)

	_chart = TimeChart.new()
	_chart.position = Vector2(x - 4, 240)
	_chart.size = Vector2(348, 170)
	_chart.total_days = YEAR_CYCLES * 28
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chart)

	_label("Wasps hunt aphids. Resistant aphids survive being attacked but breed more "
		+ "slowly, so neither clone wins outright — which one is ahead depends on how "
		+ "much parasitism is happening right now.",
		Vector2(x, 420), 11, TEXT_DIM, 336)


func _build_footer() -> void:
	var y := 556.0
	var panel := ColorRect.new()
	panel.color = PANEL
	panel.position = Vector2(12, y)
	panel.size = Vector2(1256, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_crew_label = _label("", Vector2(28, y + 14), 14, TEXT)
	_label(("Click a corridor to open or close it (1 crew day). Click a field to add or "
		+ "remove shelter habitat (1 crew day). You get %d crew days back at every cut.")
			% CREW_PER_CYCLE,
		Vector2(28, y + 40), 11, TEXT_DIM, 560)

	_log_label = _label("", Vector2(28, y + 96), 12, WARN, 560)

	_label("WHAT YOU ARE TRYING TO DO", Vector2(650, y + 14), 11, TEXT_DIM)
	_label("Finish the year with wasps still flying, both aphid clones still present, "
		+ "and your fields still different from each other. Corridors let aphids move; "
		+ "shelter decides where wasps go. Uneven shelter matters more than lots of it.",
		Vector2(650, y + 36), 11, TEXT, 590)


# --- briefing / ending overlays -------------------------------------------------------

func _clear_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _make_overlay() -> VBoxContainer:
	_clear_overlay()
	var shade := ColorRect.new()
	# Left deliberately semi-transparent: the year you just played stays visible behind
	# the verdict, chart and all.
	shade.color = Color(0.03, 0.05, 0.05, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_overlay = shade

	var panel := ColorRect.new()
	panel.color = PANEL
	panel.position = Vector2(26, 48)
	panel.size = Vector2(848, 624)
	shade.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(32, 30)
	scroll.size = Vector2(788, 566)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	scroll.add_child(box)
	return box


func _overlay_text(box: VBoxContainer, text: String, font_size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 780
	box.add_child(l)


## A button that keeps its own size inside the overlay's vertical stack.
func _overlay_button(box: VBoxContainer, text: String, on_press: Callable) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 44)
	b.pressed.connect(on_press)
	row.add_child(b)


func _show_briefing() -> void:
	phase = Phase.BRIEFING
	var box := _make_overlay()
	_overlay_text(box, "GAME OF CLONES", 30, TEXT)
	_overlay_text(box, "An eco-evolutionary field experiment, after Nell et al. 2024.",
		13, TEXT_DIM)
	_overlay_text(box,
		"Six alfalfa fields. In them live pea aphids, and the parasitoid wasps that lay "
		+ "eggs in them.\n\n"
		+ "Some aphids carry a bacterium that lets them survive a wasp attack. That "
		+ "protection is not free: resistant aphids breed more slowly than susceptible "
		+ "ones. So when wasps are everywhere, resistance pays. When wasps are scarce, "
		+ "it is just a cost, and the susceptible clone takes over.\n\n"
		+ "You cannot choose which aphids live. You can only change the land: open "
		+ "corridors between fields so winged aphids can move, and plant shelter that "
		+ "makes some fields easier for wasps to find than others.\n\n"
		+ "Every field is cut every 28 days, which kills almost every aphid in it. "
		+ "Surviving a year takes a landscape, not a field.", 15, TEXT)
	_overlay_text(box,
		"Finish 18 cuts with wasps alive, both aphid clones alive, and your fields "
		+ "still genetically different from one another.", 15, GOOD)
	_overlay_text(box,
		"One honest note: how evenly wasps spread across a landscape is not a dial "
		+ "anyone turns in real life — it is something ecologists measure. Here you are "
		+ "running an experiment on a simulated landscape, which is the one place you "
		+ "can turn it.", 12, TEXT_DIM)

	_overlay_button(box, "Take the job", _on_begin)


func _on_begin() -> void:
	_clear_overlay()
	phase = Phase.PLAYING
	paused = false
	days_per_second = 8.0
	_log("The season starts. Nothing is wrong yet.")


# --- input ---------------------------------------------------------------------------

func _on_speed_pressed(speed: float) -> void:
	if phase != Phase.PLAYING:
		return
	paused = is_zero_approx(speed)
	if not paused:
		days_per_second = speed


func _on_corridor_toggled(index: int) -> void:
	if phase != Phase.PLAYING:
		return
	if not _spend_crew():
		return
	var spec: Array = CORRIDORS[index]
	var now_open := not sim.has_corridor(spec[0], spec[1])
	sim.set_corridor(spec[0], spec[1], now_open)
	_corridor_views[index].set_open(now_open)
	_log("%s the corridor between %s and %s."
		% ["Opened" if now_open else "Closed", FIELD_NAMES[spec[0]], FIELD_NAMES[spec[1]]])


func _on_shelter_clicked(field: int) -> void:
	if phase != Phase.PLAYING:
		return
	if not _spend_crew():
		return
	var next: int = (sim.shelter[field] + 1) % (EcoSim.MAX_SHELTER + 1)
	sim.set_shelter(field, next)
	if next == 0:
		_log("Cleared the shelter around %s." % FIELD_NAMES[field])
	else:
		_log("%s now has %d band%s of shelter habitat."
			% [FIELD_NAMES[field], next, "" if next == 1 else "s"])


func _spend_crew() -> bool:
	if crew <= 0:
		_log("No crew days left. More arrive at the next cut.")
		return false
	crew -= 1
	return true


func _log(message: String) -> void:
	if _log_label != null:
		_log_label.text = message


# --- simulation pacing ----------------------------------------------------------------

func _process(delta: float) -> void:
	_update_hud()
	if phase != Phase.PLAYING or paused:
		return

	_accum += delta * days_per_second
	while _accum >= 1.0:
		_accum -= 1.0
		_advance_one_day()
		if phase != Phase.PLAYING:
			return


func _advance_one_day() -> void:
	sim.step()

	for fv in _field_views:
		fv.tick_day()
	for i in sim.harvested_today:
		_field_views[i].flash_harvest()

	var q := sim.resistant_fraction()
	_hist_wasps.append(sim.total_wasps())
	_hist_q.append(0.0 if is_nan(q) else q)
	_hist_mosaic.append(sim.mosaic())
	_chart.record(sim.total_aphids(), sim.total_wasps(), q)

	if _wasp_death_day < 0 and sim.wasps_extinct():
		_wasp_death_day = sim.day
		_log("The last wasps are gone.")
	if _resistant_death_day < 0 and sim.resistant_lost():
		_resistant_death_day = sim.day
		_log("The resistant clone has disappeared from the landscape.")
	if _susceptible_death_day < 0 and sim.susceptible_lost():
		_susceptible_death_day = sim.day
		_log("The susceptible clone has disappeared from the landscape.")

	var cycles: int = sim.day / sim.days_per_cycle()
	if cycles > _cycles_done:
		_cycles_done = cycles
		crew = mini(MAX_CREW, crew + CREW_PER_CYCLE)

	if sim.day >= YEAR_CYCLES * sim.days_per_cycle():
		_end_year()


func _update_hud() -> void:
	if sim == null:
		return
	var cycle: int = mini(sim.day / sim.days_per_cycle() + 1, YEAR_CYCLES)
	_day_label.text = "Day %d   ·   cut %d of %d" % [sim.day, cycle, YEAR_CYCLES]
	_crew_label.text = "Crew days available: %d" % crew
	for i in _corridor_views.size():
		var spec: Array = CORRIDORS[i]
		_corridor_views[i].set_open(sim.has_corridor(spec[0], spec[1]))
	if _meters != null:
		_meters.queue_redraw()


func _draw_meters() -> void:
	var font := ThemeDB.fallback_font
	var w := 336.0
	var rows := [
		_meter_row("Wasps", sim.total_wasps(), 60.0,
			sim.wasps_extinct(), sim.total_wasps() < 3.0),
		_meter_row("Resistant clone", sim.resistant_fraction() * 100.0, 100.0,
			sim.resistant_lost(), sim.resistant_fraction() < 0.02),
		_meter_row("Susceptible clone", (1.0 - sim.resistant_fraction()) * 100.0, 100.0,
			sim.susceptible_lost(), (1.0 - sim.resistant_fraction()) < 0.02),
		_meter_row("Genetic mosaic", sim.mosaic(), MOSAIC_GOOD * 2.0,
			false, sim.mosaic() < MOSAIC_GOOD),
	]
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y: float = i * 30.0
		_meters.draw_string(font, Vector2(0, y + 11), row["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
		_meters.draw_string(font, Vector2(0, y + 11), row["text"],
			HORIZONTAL_ALIGNMENT_RIGHT, w, 12, row["color"])
		_meters.draw_rect(Rect2(0, y + 16, w, 5), Color("#202a26"), true)
		_meters.draw_rect(Rect2(0, y + 16, w * row["fill"], 5), row["color"], true)


func _meter_row(label: String, value: float, full: float, dead: bool,
		warning: bool) -> Dictionary:
	var v: float = 0.0 if is_nan(value) else value
	var color := GOOD
	if dead:
		color = BAD
	elif warning:
		color = WARN
	var text := "gone" if dead else "%.0f" % v
	if label.ends_with("clone"):
		text = "gone" if dead else "%.0f%%" % v
	elif label.ends_with("mosaic"):
		if v < MOSAIC_GOOD * 0.4:
			text = "fields are alike"
		elif v < MOSAIC_GOOD:
			text = "fading"
		else:
			text = "fields differ"
	return {
		"label": label, "text": text, "color": color,
		"fill": clampf(v / full, 0.0, 1.0),
	}


# --- the end of the year --------------------------------------------------------------

func _end_year() -> void:
	phase = Phase.ENDED
	paused = true

	var wasps_alive := not sim.wasps_extinct() and _wasp_death_day < 0
	var both_clones := _resistant_death_day < 0 and _susceptible_death_day < 0
	var mean_mosaic := 0.0
	for v in _hist_mosaic:
		mean_mosaic += v
	mean_mosaic /= maxf(_hist_mosaic.size(), 1)
	var mosaic_alive := mean_mosaic >= MOSAIC_GOOD

	var box := _make_overlay()
	var won := wasps_alive and both_clones and mosaic_alive
	if won:
		_overlay_text(box, "A YEAR THAT HELD TOGETHER", 28, GOOD)
	elif wasps_alive and both_clones:
		_overlay_text(box, "EVERYTHING SURVIVED. NOTHING VARIED.", 28, WARN)
	else:
		_overlay_text(box, "THE SYSTEM CAME APART", 28, BAD)

	_overlay_text(box, _scoreline(wasps_alive, both_clones, mosaic_alive, mean_mosaic),
		14, TEXT)
	_overlay_text(box, _narrative(wasps_alive, both_clones, mosaic_alive), 14, TEXT)
	_overlay_text(box, _loop_readout(), 13, RESIST_TEXT)
	_overlay_text(box,
		"In the real system this is built on — alfalfa fields at the Arlington "
		+ "Agricultural Research Station in Wisconsin, surveyed 2011-2019, cut every 28 "
		+ "days — aphid resistance rises and falls fast enough to steer the wasp "
		+ "population while the wasp population is steering it back. Ecology and "
		+ "evolution run on the same clock, and it takes a landscape of moderately "
		+ "connected, genuinely different fields to keep both of them going.",
		12, TEXT_DIM)

	_overlay_button(box, "Another year", _on_restart)


const RESIST_TEXT := Color("#b98cf5")


func _scoreline(wasps_alive: bool, both_clones: bool, mosaic_alive: bool,
		mean_mosaic: float) -> String:
	var lines: Array[String] = []
	lines.append("%s  wasps" % ("KEPT  " if wasps_alive else "LOST  "))
	lines.append("%s  both aphid clones" % ("KEPT  " if both_clones else "LOST  "))
	if both_clones:
		lines.append("%s  a mosaic of genetically different fields (%.3f)"
			% ["KEPT  " if mosaic_alive else "LOST  ", mean_mosaic])
	else:
		lines.append("  --    a mosaic needs two clones to be a mosaic of anything")
	return "\n".join(lines)


func _narrative(wasps_alive: bool, both_clones: bool, mosaic_alive: bool) -> String:
	var delta_a := sim.delta_a_effective()
	var gamma := sim.gamma_effective()
	var parts: Array[String] = []

	if not wasps_alive:
		parts.append("Your wasps died out on day %d." % _wasp_death_day)
		if gamma < 0.5:
			parts.append("Every field looked much the same to them. Wasps that leave a "
				+ "field with no aphids left have to land somewhere better than random, "
				+ "and in a landscape this uniform there was no better. Unevenness is "
				+ "what they needed, not more shelter.")
		if delta_a < 0.15:
			parts.append("Your fields were also nearly cut off from each other, so when "
				+ "a field was cut its aphids were simply gone — nothing flew in to "
				+ "restart them, and the wasps had nothing to come back to.")
		if _resistant_death_day > _wasp_death_day:
			parts.append(("With no wasps left, resistance was pure cost. The resistant "
				+ "clone was gone by day %d, out-bred by the susceptible one. That is "
				+ "the feedback running in reverse: lose the ecology and you lose the "
				+ "evolution with it.") % _resistant_death_day)
	elif not both_clones:
		if _resistant_death_day > 0:
			parts.append(("The resistant clone disappeared on day %d. Resistance only "
				+ "pays while enough wasps are attacking; when parasitism stayed low, "
				+ "the slower-breeding clone lost.") % _resistant_death_day)
		if _susceptible_death_day > 0:
			parts.append(("The susceptible clone disappeared on day %d — parasitism "
				+ "stayed so heavy for so long that breeding fast stopped being worth "
				+ "anything.") % _susceptible_death_day)
	elif not mosaic_alive:
		parts.append("Nothing went extinct, which is not nothing. But you connected "
			+ "your fields so thoroughly that they stopped being separate places: "
			+ "aphids mixed across the whole landscape until every field had the same "
			+ "clone mix as every other. A mosaic that uniform has no variation left "
			+ "for selection to act differently on from field to field.")
	else:
		parts.append("Wasps, susceptible aphids and resistant aphids all made it "
			+ "through the year, and your fields still differ from one another. "
			+ "Aphids moved enough to restart cut fields, not so much that the fields "
			+ "became one field, and wasps had somewhere worth flying to.")

	parts.append(("You finished with aphid dispersal at %.2f and landscape unevenness "
		+ "at %.2f. In the study this is built on, the parasitoid needs unevenness of "
		+ "roughly 0.6 or more to persist at all.") % [delta_a, gamma])
	return "\n\n".join(parts)


## Did the loop actually close? Reports the delay between parasitism peaking and
## resistance peaking — the signature of evolution responding to ecology.
func _loop_readout() -> String:
	if _hist_wasps.size() < 120:
		return ""
	var lag := _best_lag(_hist_wasps, _hist_q, 30, 120)
	var q_min := INF
	var q_max := -INF
	for v in _hist_q:
		q_min = minf(q_min, v)
		q_max = maxf(q_max, v)
	if q_max - q_min < 0.05:
		return "Resistance barely moved this year (%.0f%% to %.0f%%)." \
			% [q_min * 100.0, q_max * 100.0]
	if _wasp_death_day > 0:
		return ("Before the wasps went, resistance had already climbed to %.0f%% of your "
			+ "aphids — evolution keeping up with the ecology in real time. Then the "
			+ "wasps died, resistance stopped paying, and it fell away again. You saw "
			+ "half the loop: ecology drove evolution, but there was no ecology left "
			+ "for the evolution to drive back.") % [q_max * 100.0]
	return ("Resistance swung between %.0f%% and %.0f%% of your aphids, and it tracked "
		+ "parasitism with a delay of about %d days. Wasps build up, resistance "
		+ "follows, wasps starve on aphids they cannot use, resistance fades because it "
		+ "costs more than it is worth — and it starts again. That loop is what "
		+ "eco-evolutionary dynamics means.") % [q_min * 100.0, q_max * 100.0, lag]


func _best_lag(a: Array, b: Array, skip: int, max_lag: int) -> int:
	var best := 0
	var best_r := -INF
	for lag in range(0, max_lag + 1):
		var n: int = a.size() - lag - skip
		if n < 30:
			break
		var sa := 0.0
		var sb := 0.0
		for i in n:
			sa += a[skip + i]
			sb += b[skip + i + lag]
		var ma := sa / n
		var mb := sb / n
		var num := 0.0
		var da := 0.0
		var db := 0.0
		for i in n:
			var x: float = a[skip + i] - ma
			var y: float = b[skip + i + lag] - mb
			num += x * y
			da += x * x
			db += y * y
		if da <= 0.0 or db <= 0.0:
			continue
		var r: float = num / sqrt(da * db)
		if r > best_r:
			best_r = r
			best = lag
	return best


func _on_restart() -> void:
	_clear_overlay()
	_new_game()
	for i in _field_views.size():
		_field_views[i].sim = sim
	_chart.clear_history()
	for cv in _corridor_views:
		cv.set_open(false)
	phase = Phase.PLAYING
	paused = false
	_log("A new year, a new landscape.")
