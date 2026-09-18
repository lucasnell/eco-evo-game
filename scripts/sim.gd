class_name EcoSim
extends RefCounted

## Reduced eco-evolutionary simulation: pea aphid (susceptible / resistant clones) and
## the parasitoid wasp Aphidius ervi, across a small landscape of alfalfa fields.
##
## Mechanisms and constants are transcribed from lucasnell/gameofclones (the code behind
## Nell et al. 2024, Science) — see docs/MODEL.md for the file:line transcription record.
## Two things here are NOT transcribed and are documented as such:
##   * K (per-field carrying capacity) and ATTACK_H, the absolute population scale. The
##     28-field source model's units don't map onto a 6-field reduction; these are the
##     numerically calibrated values carried over from the validated JS reduction.
##   * IND_SCALE, demographic stochasticity. The source model is deterministic at this
##     level of reduction; a game needs extinction to be a real possibility, so counts
##     are drawn from Poisson/binomial distributions. All RATES are computed in the
##     validated density units, so the mean dynamics are unchanged — noise only.
##
## Everything else (parasitism functional response, resistance trade-off, dispersal
## mechanics, harvest, wasp life history) is the source model's.

# --- Transcribed constants (do not change without re-checking docs/MODEL.md) ---------

const ATTACK_A := 2.32          ## attack rate, Holling-II numerator
const ATTACK_K := 0.35          ## May (1978) negative-binomial aggregation parameter
const LAMBDA_S := 1.26          ## susceptible daily growth factor (Ives et al. 2020)
const LAMBDA_R := 1.21          ## resistant daily growth factor — the cost of resistance
const RESIST_BENEFIT := 0.73    ## P(resistant aphid survives an attack) — the benefit
const ALATE_FRACTION := 0.20    ## fraction of adult aphids that are winged
const WASP_DISP_M0 := 0.3       ## baseline wasp emigration rate
const WASP_DISP_M1_BASE := 0.34906  ## multiplied by gamma: density-dependence of emigration
const ATTRACT_SD_BASE := 0.5844     ## multiplied by gamma: spread of field attractiveness
const ADULT_WASP_SURVIVAL := 0.69   ## daily
const MUMMY_DELAY_DAYS := 10        ## 7 d parasitized host + 3 d mummy
const HARVEST_INTERVAL_DAYS := 28
const HARVEST_SURV_MIN := 0.01      ## aphids surviving a harvest: 1-4%
const HARVEST_SURV_MAX := 0.04

# --- Calibrated / game constants (NOT transcribed) -----------------------------------

const K := 500.0                ## per-field carrying capacity, density units
const ATTACK_H := 2.0           ## handling-time-like constant
const IND_SCALE := 20.0         ## individuals per density unit; sets demographic noise
const EXTINCT := 1.0 / IND_SCALE  ## below one individual = gone

## Fraction of winged aphids that leave a fully connected field each day. A field with
## fewer corridors loses proportionally fewer: the rest fail to find another field and
## stay put. Realized dispersal (delta_a) therefore emerges from the landscape the
## player builds rather than being set directly.
const MAX_EMIGRATION := 0.9
const MAX_LINKS_PER_FIELD := 3   ## degree of a fully connected field in the grid layout

## How much one step of shelter habitat multiplies a field's findability to wasps.
## Uneven shelter -> uneven wasp distribution -> the heterogeneity (gamma) the system
## needs. Uniform shelter, at ANY level, gives no heterogeneity at all.
const SHELTER_GAIN := 0.75
const MAX_SHELTER := 2

# --- State ---------------------------------------------------------------------------

var n_fields: int
var day: int = 0

var susceptible: PackedFloat64Array   ## per field
var resistant: PackedFloat64Array
var wasps: PackedFloat64Array

## Landscape, set by the player.
var shelter: PackedInt32Array         ## per field, 0..MAX_SHELTER
var neighbors: Array[PackedInt32Array] = []  ## open corridors, symmetric

var _mummies: Array[PackedFloat64Array] = []
var _attract: PackedFloat64Array      ## normalized wasp attractiveness, from shelter
var _gamma_eff: float = 0.0           ## heterogeneity implied by the shelter pattern
var _harvest_offset: PackedInt32Array
var _rng := RandomNumberGenerator.new()

## Fields harvested on the most recent step (for the view to flash).
var harvested_today: PackedInt32Array = PackedInt32Array()


func _init(fields: int, seed: int) -> void:
	n_fields = fields
	_rng.seed = seed

	susceptible = PackedFloat64Array()
	resistant = PackedFloat64Array()
	wasps = PackedFloat64Array()
	shelter = PackedInt32Array()
	_harvest_offset = PackedInt32Array()

	for i in fields:
		# Fields start with different densities and different clone frequencies: the
		# landscape begins as a mosaic, and the player's job is to keep it one.
		var n := 120.0 * (0.5 + _rng.randf())
		var q: float = clampf(0.25 * (0.3 + 1.6 * _rng.randf()), 0.02, 0.9)
		susceptible.append(n * (1.0 - q))
		resistant.append(n * q)
		wasps.append(5.0 * (0.5 + _rng.randf()))
		shelter.append(0)
		_harvest_offset.append(int(float(i) * HARVEST_INTERVAL_DAYS / float(fields)))
		neighbors.append(PackedInt32Array())

		var queue := PackedFloat64Array()
		queue.resize(MUMMY_DELAY_DAYS)
		_mummies.append(queue)

	_recompute_attractiveness()


## Wasp attractiveness of each field, and the landscape heterogeneity it implies.
## What matters is not how much shelter there is but how UNEVENLY it is spread: a
## landscape where every field is identical gives wasps no reason to concentrate
## anywhere, which is the low-gamma state the parasitoid cannot survive.
func _recompute_attractiveness() -> void:
	var log_w := PackedFloat64Array()
	var mean_log := 0.0
	for i in n_fields:
		var lw: float = SHELTER_GAIN * float(shelter[i])
		log_w.append(lw)
		mean_log += lw
	mean_log /= float(n_fields)

	var ss := 0.0
	for i in n_fields:
		ss += (log_w[i] - mean_log) * (log_w[i] - mean_log)
	var sd: float = sqrt(ss / float(n_fields))
	# Express the realized unevenness on the same scale the source model's gamma uses.
	_gamma_eff = clampf(sd / ATTRACT_SD_BASE, 0.0, 2.0)

	_attract = PackedFloat64Array()
	var total := 0.0
	for i in n_fields:
		var v: float = exp(log_w[i])
		_attract.append(v)
		total += v
	for i in n_fields:
		_attract[i] = _attract[i] / total


func set_shelter(field: int, level: int) -> void:
	shelter[field] = clampi(level, 0, MAX_SHELTER)
	_recompute_attractiveness()


func set_corridor(a: int, b: int, open: bool) -> void:
	_set_neighbor(a, b, open)
	_set_neighbor(b, a, open)


func _set_neighbor(from: int, to: int, open: bool) -> void:
	var list: PackedInt32Array = neighbors[from]
	var idx := list.find(to)
	if open and idx == -1:
		list.append(to)
	elif not open and idx != -1:
		list.remove_at(idx)
	neighbors[from] = list


func has_corridor(a: int, b: int) -> bool:
	return neighbors[a].has(b)


## Parasitoid dispersal heterogeneity produced by the current shelter pattern.
func gamma_effective() -> float:
	return _gamma_eff


## Realized aphid dispersal: the share of winged aphids that actually leave their field,
## averaged over the landscape. This is delta_a, emerging from how connected the
## player's landscape is.
func delta_a_effective() -> float:
	var total := 0.0
	for i in n_fields:
		total += minf(1.0, float(neighbors[i].size()) / float(MAX_LINKS_PER_FIELD))
	return MAX_EMIGRATION * total / float(n_fields)


# --- Stochastic helpers: draw individual counts, return density ----------------------

func _poisson_count(lambda_mean: float) -> float:
	if lambda_mean <= 0.0:
		return 0.0
	if lambda_mean < 30.0:
		var l := exp(-lambda_mean)
		var k := 0
		var p := 1.0
		while true:
			k += 1
			p *= _rng.randf()
			if p <= l:
				break
		return float(k - 1)
	return maxf(0.0, roundf(lambda_mean + sqrt(lambda_mean) * _rng.randfn(0.0, 1.0)))


func _binom_count(n: float, p: float) -> float:
	var count := roundf(n)
	if count <= 0.0 or p <= 0.0:
		return 0.0
	if p >= 1.0:
		return count
	if count < 30.0:
		var k := 0
		for i in int(count):
			if _rng.randf() < p:
				k += 1
		return float(k)
	var mean := count * p
	var sd := sqrt(count * p * (1.0 - p))
	return clampf(roundf(mean + sd * _rng.randfn(0.0, 1.0)), 0.0, count)


## Poisson draw on a density: convert to individuals, draw, convert back.
func _pois(mean_density: float) -> float:
	return _poisson_count(mean_density * IND_SCALE) / IND_SCALE


## Binomial draw on a density.
func _binom(density: float, p: float) -> float:
	return _binom_count(density * IND_SCALE, p) / IND_SCALE


# --- One simulated day ---------------------------------------------------------------

func step() -> void:
	harvested_today = PackedInt32Array()

	for i in n_fields:
		var n: float = susceptible[i] + resistant[i]

		# Parasitism. Holling type II mean attacks per host, then May's negative-binomial
		# aggregation: wasps clump, so attacks are unevenly spread over hosts.
		var a_bar: float = (ATTACK_A * wasps[i]) / (ATTACK_H * n + 1.0)
		var attack_prob: float = 1.0 - pow(1.0 + a_bar / ATTACK_K, -ATTACK_K)

		# Both clones are attacked at the same rate. The entire difference between them
		# is what happens next — this is the selection step, and it is the only thing
		# that changes clone frequencies.
		var att_s: float = _binom(susceptible[i], attack_prob)
		var att_r: float = _binom(resistant[i], attack_prob)
		var surv_r: float = _binom(att_r, RESIST_BENEFIT)
		var new_mummies: float = att_s + (att_r - surv_r)

		# Reproduction of survivors, with density dependence. Resistant aphids pay for
		# their defence with a lower growth rate (LAMBDA_R < LAMBDA_S).
		var un_s: float = susceptible[i] - att_s
		var un_r: float = resistant[i] - att_r
		var dens: float = 1.0 + (LAMBDA_S - 1.0) * (n / K)
		susceptible[i] = _pois((un_s * LAMBDA_S) / dens)
		resistant[i] = _pois((un_r * LAMBDA_R) / dens) + surv_r

		# Mummy queue: an attack today becomes an adult wasp 10 days from now.
		var queue: PackedFloat64Array = _mummies[i]
		var eclosed: float = queue[0]
		for d in MUMMY_DELAY_DAYS - 1:
			queue[d] = queue[d + 1]
		queue[MUMMY_DELAY_DAYS - 1] = new_mummies
		_mummies[i] = queue
		wasps[i] = _binom(wasps[i], ADULT_WASP_SURVIVAL) + _pois(eclosed)

	_disperse_aphids(susceptible)
	_disperse_aphids(resistant)
	_disperse_wasps()
	_harvest()
	day += 1


## Winged aphids leave their field and settle in a field it is connected to. A field
## with no open corridors keeps its aphids: they have nowhere to go. This is why the
## corridors the player opens ARE the dispersal rate.
func _disperse_aphids(arr: PackedFloat64Array) -> void:
	var arrivals := PackedFloat64Array()
	arrivals.resize(n_fields)
	for i in n_fields:
		var links: PackedInt32Array = neighbors[i]
		if links.size() == 0:
			continue
		var openness: float = minf(1.0, float(links.size()) / float(MAX_LINKS_PER_FIELD))
		var rate: float = minf(1.0, MAX_EMIGRATION * openness * ALATE_FRACTION)
		var leaving: float = _binom(arr[i], rate)
		if leaving <= 0.0:
			continue
		arr[i] -= leaving
		var weights := PackedFloat64Array()
		for j in n_fields:
			weights.append(1.0 / float(links.size()) if links.has(j) else 0.0)
		_allocate(arrivals, leaving, weights)
	for i in n_fields:
		arr[i] += arrivals[i]


## Wasps leave fields where hosts are scarce (more steeply when the landscape is uneven)
## and settle in proportion to how findable each field is. Wasps fly: they are not
## restricted to the player's corridors.
func _disperse_wasps() -> void:
	var m1: float = WASP_DISP_M1_BASE * _gamma_eff
	var pool := 0.0
	for i in n_fields:
		var z: float = maxf(susceptible[i] + resistant[i], 1.0)
		var rate: float = minf(1.0, WASP_DISP_M0 * exp(-m1 * log(z)))
		var leaving: float = _binom(wasps[i], rate)
		wasps[i] -= leaving
		pool += leaving
	if pool > 0.0:
		_allocate(wasps, pool, _attract)


## Split a pooled density across fields with the given weights (multinomial).
func _allocate(arr: PackedFloat64Array, pool: float, weights: PackedFloat64Array) -> void:
	var left := roundf(pool * IND_SCALE)
	if left <= 0.0:
		return
	var last := -1
	for i in n_fields:
		if weights[i] > 0.0:
			last = i
	if last == -1:
		return
	var cum := 0.0
	for i in n_fields:
		if left <= 0.0:
			break
		if weights[i] <= 0.0:
			continue
		var take: float
		if i == last:
			take = left
		else:
			var remaining: float = 1.0 - cum
			var p: float = 0.0
			if remaining > 1e-12:
				p = minf(1.0, weights[i] / remaining)
			take = _binom_count(left, p)
		arr[i] += take / IND_SCALE
		left -= take
		cum += weights[i]


## Alfalfa is cut every 28 days, one field at a time. Harvest kills 96-99% of aphids and
## every mummy; adult wasps escape by flying away. It is the biggest disturbance in the
## system, and it is what makes dispersal matter.
func _harvest() -> void:
	for i in n_fields:
		var phase: int = posmod(day - _harvest_offset[i], HARVEST_INTERVAL_DAYS)
		if phase != 0:
			continue
		var surv: float = _rng.randf_range(HARVEST_SURV_MIN, HARVEST_SURV_MAX)
		susceptible[i] = _binom(susceptible[i], surv)
		resistant[i] = _binom(resistant[i], surv)
		var queue: PackedFloat64Array = _mummies[i]
		for d in MUMMY_DELAY_DAYS:
			queue[d] = 0.0
		_mummies[i] = queue
		harvested_today.append(i)


# --- Readouts ------------------------------------------------------------------------

func total_susceptible() -> float:
	var t := 0.0
	for v in susceptible:
		t += v
	return t


func total_resistant() -> float:
	var t := 0.0
	for v in resistant:
		t += v
	return t


func total_wasps() -> float:
	var t := 0.0
	for v in wasps:
		t += v
	return t


func total_aphids() -> float:
	return total_susceptible() + total_resistant()


## Landscape-wide fraction of aphids carrying resistance. NAN if no aphids remain.
func resistant_fraction() -> float:
	var n := total_aphids()
	if n <= 0.0:
		return NAN
	return total_resistant() / n


## Resistant fraction within one field, or NAN if the field is empty.
func field_resistant_fraction(i: int) -> float:
	var n: float = susceptible[i] + resistant[i]
	if n <= 0.0:
		return NAN
	return resistant[i] / n


## How different the fields are from each other genetically: the standard deviation of
## resistant fraction across occupied fields. This is the selection mosaic. Dispersal
## erases it; without it, the landscape is one big uniform field.
func mosaic() -> float:
	var vals: Array[float] = []
	for i in n_fields:
		var q := field_resistant_fraction(i)
		if not is_nan(q):
			vals.append(q)
	if vals.size() < 2:
		return 0.0
	var mean := 0.0
	for v in vals:
		mean += v
	mean /= float(vals.size())
	var ss := 0.0
	for v in vals:
		ss += (v - mean) * (v - mean)
	return sqrt(ss / float(vals.size()))


func wasps_extinct() -> bool:
	return total_wasps() < EXTINCT


func resistant_lost() -> bool:
	return total_resistant() < EXTINCT


func susceptible_lost() -> bool:
	return total_susceptible() < EXTINCT


func days_per_cycle() -> int:
	return HARVEST_INTERVAL_DAYS


## Days until this field is next cut.
func days_until_harvest(field: int) -> int:
	return posmod(_harvest_offset[field] - day, HARVEST_INTERVAL_DAYS)
