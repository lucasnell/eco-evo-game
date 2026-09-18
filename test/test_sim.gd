extends SceneTree

## Acceptance tests for the simulation. Run headless:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://test/test_sim.gd
##
## These assert the qualitative results the game is built to teach, driven through the
## same landscape interface the player uses (corridors + shelter), at the settings the
## game ships with. They are the port's guard rail: if the sim drifts from the behaviour
## validated in docs/MODEL.md, these fail.

const FIELDS := 6
const CYCLES := 18
const SEEDS := 16

## Field layout, 3 x 2:   0 1 2
##                        3 4 5
const ALL_CORRIDORS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(3, 4), Vector2i(4, 5),
	Vector2i(0, 3), Vector2i(1, 4), Vector2i(2, 5),
]

var failures := 0
var checks := 0


func _initialize() -> void:
	print("Eco-evo acceptance tests (%d fields, %d cycles, %d seeds)\n" % [FIELDS, CYCLES, SEEDS])

	test_landscape_produces_parameters()
	test_good_landscape_persists()
	test_isolated_fields_lose_parasitoid()
	test_uniform_landscape_loses_parasitoid()
	test_full_connection_erases_mosaic()
	test_eco_evo_loop_closes()
	test_resistance_tradeoff_is_enforced()

	print("\n%d/%d checks passed." % [checks - failures, checks])
	quit(1 if failures > 0 else 0)


func check(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("  PASS  %s %s" % [label, detail])
	else:
		failures += 1
		print("  FAIL  %s %s" % [label, detail])


## Build a sim from a landscape description.
## `corridors`: indices into ALL_CORRIDORS that are open. `shelter`: per-field levels.
func build(corridors: Array, shelter_levels: Array, seed: int) -> EcoSim:
	var sim := EcoSim.new(FIELDS, seed)
	for c in corridors:
		var link: Vector2i = ALL_CORRIDORS[c]
		sim.set_corridor(link.x, link.y, true)
	for i in FIELDS:
		sim.set_shelter(i, shelter_levels[i])
	return sim


func run_landscape(corridors: Array, shelter_levels: Array, seed: int,
		cycles: int = CYCLES) -> Dictionary:
	var sim := build(corridors, shelter_levels, seed)
	var days := cycles * sim.days_per_cycle()
	var wasp_series: Array[float] = []
	var q_series: Array[float] = []
	var mosaic_sum := 0.0
	var wasps_died := false
	var resistant_died := false
	var susceptible_died := false

	for d in days:
		sim.step()
		wasp_series.append(sim.total_wasps())
		var q := sim.resistant_fraction()
		q_series.append(0.0 if is_nan(q) else q)
		mosaic_sum += sim.mosaic()
		if sim.wasps_extinct():
			wasps_died = true
		if sim.resistant_lost():
			resistant_died = true
		if sim.susceptible_lost():
			susceptible_died = true

	return {
		"wasps": wasp_series,
		"q": q_series,
		"mosaic": mosaic_sum / float(days),
		"wasps_died": wasps_died,
		"resistant_died": resistant_died,
		"susceptible_died": susceptible_died,
		"all_persist": not (wasps_died or resistant_died or susceptible_died),
		"delta_a": sim.delta_a_effective(),
		"gamma": sim.gamma_effective(),
	}


func count_persisting(corridors: Array, shelter_levels: Array) -> int:
	var n := 0
	for seed in range(1, SEEDS + 1):
		if run_landscape(corridors, shelter_levels, seed)["all_persist"]:
			n += 1
	return n


## Sanity check on the mapping from landscape to model parameters, since the whole design
## rests on the player never touching delta_a or gamma directly.
func test_landscape_produces_parameters() -> void:
	print("the landscape produces the model parameters")

	var isolated := build([], [0, 2, 0, 2, 0, 2], 1)
	check("no corridors -> no aphid dispersal", is_equal_approx(isolated.delta_a_effective(), 0.0),
		"(delta_a = %.2f)" % isolated.delta_a_effective())

	var sparse := build([0, 2, 6], [0, 2, 0, 2, 0, 2], 1)
	var full := build([0, 1, 2, 3, 4, 5, 6], [0, 2, 0, 2, 0, 2], 1)
	check("more corridors -> more dispersal",
		sparse.delta_a_effective() < full.delta_a_effective(),
		"(%.2f vs %.2f)" % [sparse.delta_a_effective(), full.delta_a_effective()])

	var uniform_bare := build([], [0, 0, 0, 0, 0, 0], 1)
	var uniform_lush := build([], [2, 2, 2, 2, 2, 2], 1)
	var uneven := build([], [0, 2, 0, 2, 0, 2], 1)
	check("uniform shelter -> no heterogeneity, at any level",
		is_equal_approx(uniform_bare.gamma_effective(), 0.0)
			and is_equal_approx(uniform_lush.gamma_effective(), 0.0),
		"(bare %.2f, lush %.2f)" % [uniform_bare.gamma_effective(), uniform_lush.gamma_effective()])
	check("uneven shelter -> heterogeneity", uneven.gamma_effective() > 0.9,
		"(gamma = %.2f)" % uneven.gamma_effective())


## The headline result: moderate aphid dispersal plus uneven parasitoid habitat lets the
## wasps AND both aphid clones persist together.
func test_good_landscape_persists() -> void:
	print("moderate connection + uneven shelter -> everything coexists")
	var corridors: Array = [0, 2, 5, 6]
	var shelter_levels: Array = [0, 2, 0, 2, 0, 2]
	var n := count_persisting(corridors, shelter_levels)
	var r := run_landscape(corridors, shelter_levels, 1)
	check("all three persist", n >= int(SEEDS * 0.7),
		"(%d/%d runs, delta_a=%.2f gamma=%.2f)" % [n, SEEDS, r["delta_a"], r["gamma"]])


## Too little dispersal: hosts cannot recolonize cut fields, the parasitoid starves, and
## once parasitism is gone resistance stops paying for itself.
func test_isolated_fields_lose_parasitoid() -> void:
	print("isolated fields -> the parasitoid is lost")
	var shelter_levels: Array = [0, 2, 0, 2, 0, 2]
	var n := count_persisting([], shelter_levels)
	var wasp_failures := 0
	for seed in range(1, SEEDS + 1):
		if run_landscape([], shelter_levels, seed)["wasps_died"]:
			wasp_failures += 1
	check("system usually fails with no corridors", n <= int(SEEDS * 0.5),
		"(%d/%d intact)" % [n, SEEDS])
	check("and it is the parasitoid that goes", wasp_failures >= int(SEEDS * 0.5),
		"(%d/%d lost wasps)" % [wasp_failures, SEEDS])


## The counterintuitive one: improving habitat everywhere, uniformly, is as bad as
## improving it nowhere. What the parasitoid needs is unevenness.
func test_uniform_landscape_loses_parasitoid() -> void:
	print("uniform shelter -> the parasitoid is lost, however much shelter there is")
	var corridors: Array = [0, 2, 5, 6]
	var uneven := count_persisting(corridors, [0, 2, 0, 2, 0, 2])
	var all_bare := count_persisting(corridors, [0, 0, 0, 0, 0, 0])
	var all_lush := count_persisting(corridors, [2, 2, 2, 2, 2, 2])
	check("bare-everywhere fails more than uneven", all_bare < uneven,
		"(%d/%d vs %d/%d intact)" % [all_bare, SEEDS, uneven, SEEDS])
	check("shelter-everywhere also fails more than uneven", all_lush < uneven,
		"(%d/%d vs %d/%d intact)" % [all_lush, SEEDS, uneven, SEEDS])


## Too much dispersal mixes the fields into one: nothing need go extinct for the
## landscape to lose the genetic variation that makes it a mosaic.
func test_full_connection_erases_mosaic() -> void:
	print("connecting everything -> the mosaic is erased")
	var shelter_levels: Array = [0, 2, 0, 2, 0, 2]
	var sparse := 0.0
	var full := 0.0
	for seed in range(1, SEEDS + 1):
		sparse += run_landscape([0, 5], shelter_levels, seed)["mosaic"]
		full += run_landscape([0, 1, 2, 3, 4, 5, 6], shelter_levels, seed)["mosaic"]
	sparse /= SEEDS
	full /= SEEDS
	check("between-field variation collapses as corridors open", sparse > full * 2.0,
		"(mosaic %.3f sparse vs %.3f fully connected)" % [sparse, full])


## The point of the whole game: evolution is fast enough to drive the ecology, and the
## ecology drives the evolution right back.
func test_eco_evo_loop_closes() -> void:
	print("the eco-evolutionary loop closes and repeats")
	var corridors: Array = [0, 2, 5, 6]
	var shelter_levels: Array = [0, 2, 0, 2, 0, 2]
	var swings := 0
	var lags_positive := 0
	var lag_sum := 0.0
	var tested := 0
	for seed in range(1, SEEDS + 1):
		var r := run_landscape(corridors, shelter_levels, seed)
		if not r["all_persist"]:
			continue
		tested += 1
		var q: Array = r["q"]
		var w: Array = r["wasps"]
		var q_min := INF
		var q_max := -INF
		for v in q:
			q_min = minf(q_min, v)
			q_max = maxf(q_max, v)
		if q_max - q_min > 0.15:
			swings += 1
		var best_lag := best_lag_days(w, q, 30, 120)
		lag_sum += best_lag
		if best_lag > 0:
			lags_positive += 1

	check("resistance swings by more than 15 percentage points", swings >= tested * 0.7,
		"(%d/%d runs)" % [swings, tested])
	check("resistance lags parasitism (evolution responds to ecology)",
		lags_positive >= tested * 0.7,
		"(%d/%d runs, mean lag %.0f days)" % [lags_positive, tested, lag_sum / maxf(tested, 1)])


## Lag (in days) that maximizes the correlation between series `a` at time t and series
## `b` at time t+lag. Positive means b follows a.
func best_lag_days(a: Array, b: Array, skip: int, max_lag: int) -> int:
	var best := 0
	var best_r := -INF
	for lag in range(0, max_lag + 1):
		var n := a.size() - lag - skip
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


## The trade-off must always bind: neither clone is strictly better.
func test_resistance_tradeoff_is_enforced() -> void:
	print("the resistance/fecundity trade-off is enforced")

	# No parasitism at all: resistance should decline, because it costs fecundity.
	var sim := build([0, 2, 5, 6], [0, 2, 0, 2, 0, 2], 42)
	for i in FIELDS:
		sim.wasps[i] = 0.0
	var q_start := sim.resistant_fraction()
	for d in 200:
		sim.step()
		for i in FIELDS:
			sim.wasps[i] = 0.0
	var q_end := sim.resistant_fraction()
	check("without parasitism, resistance declines", q_end < q_start,
		"(%.3f -> %.3f)" % [q_start, q_end])

	# Heavy sustained parasitism: resistance should rise.
	var sim2 := build([0, 2, 5, 6], [0, 2, 0, 2, 0, 2], 42)
	var q2_start := sim2.resistant_fraction()
	var rose := false
	for d in 200:
		sim2.step()
		for i in FIELDS:
			sim2.wasps[i] = maxf(sim2.wasps[i], 20.0)
		var q := sim2.resistant_fraction()
		if not is_nan(q) and q > q2_start + 0.1:
			rose = true
	check("under sustained parasitism, resistance rises", rose, "(from %.3f)" % q2_start)
