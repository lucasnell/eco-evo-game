# Model spec and acceptance criteria

## Status

**Transcribed.** Exact parameters and equations have been pulled from the
`lucasnell/gameofclones` R/C++ source and the `gameofclones-data` analysis scripts
(the code that actually produced Nell et al. Fig. 3), with file:line citations kept in
the extraction record below. Reduced-model implementation and numerical calibration are
in progress in `js/model.js` / `test/`.

Do not infer equations or constants from the main-text PDF. It describes structure, not
parameterization. Invented "plausible" constants produce dynamics that look right and
are not, and debugging that costs more than transcription.

## Transcription record (source-grounded, 2026-09-14)

Two separate, both-legitimate sources of "resistance cost/benefit" exist in the
literature this project draws on — **do not conflate them**:

- **Ives et al. 2020's fitted, population-level summary** (already in the acceptance
  table below): parasitism-survival benefit 0.73 (resistant) vs 0 (susceptible);
  parasitism-independent intrinsic rate of increase 1.26 d⁻¹ (susceptible) →
  1.21 d⁻¹ (resistant). These numbers do **not** appear literally anywhere in the
  `gameofclones` source — they are Ives et al.'s fitted demographic summary, one level
  up from the mechanistic simulation.
- **`gameofclones`'s own mechanistic parameters**, from the actual script that produced
  the paper's stability figures (`gameofclones-data/scripts/04-stability/*.R`, built on
  `00-shared-all.R:129-142`'s `line_s`/`line_r` clonal lines): a resistant aphid that is
  attacked survives the attack itself with probability from `attack_surv = c(0.9, 0.6)`
  (singly/multiply attacked; Meisner et al. 2014 eq. 6 framework), *and* if the wasp egg
  still develops, the juvenile has an additional `surv_paras = 0.57` chance of surviving
  to adulthood (the *H. defensa*/APSE3 toxin can still kill the developing wasp/host).
  Susceptible aphids have neither term (certain death on attack). Full daily
  survival/fecundity are 20-element age-schedules (`low`/`high` presets), not single
  numbers.

**Decision for this project:** the reduced model uses the Ives et al. fitted numbers
(0.73 / 0, 1.26 / 1.21 d⁻¹) as the resistance trade-off — they're already the numbers
the acceptance-criteria table below is built around, and collapsing `gameofclones`'s
two-step mechanism into one net probability is exactly the kind of reduction
`docs/MODEL.md`'s "Reduction target" section calls for.

### δ_a (aphid dispersal) — confirmed

`δ_a` = `alate_field_disp_p` in the source, confirmed by
`gameofclones-data/scripts/04-stability/01-aphid-dispersal.R:55-56,61`, whose sweep
(`disp.list`) spans exactly the thresholds in the acceptance table below. Mechanism
(`R/simulate.R:492-500,879-887`): each day, `alate_field_disp_p` of the winged
(alate) adults from every field are pooled, then the pool is redistributed **evenly**
across all fields. Roughly 20% of adult aphids at the field site are winged (see
"Field-scale reality checks" below) — that's the alate fraction actually subject to
dispersal.

### γ (parasitoid dispersal heterogeneity) — confirmed, and it is *not* a single native
### parameter

γ is a multiplier the paper's own analysis script (`04-paras-disp-hetero.R:40-52`)
applies to **two separate mechanisms at once** — a single slider that only drove one of
these would not reproduce the γ<0.6 extinction threshold:

1. **Spatial heterogeneity in field attractiveness to wasps.** Each field gets a fixed
   relative attractiveness drawn once as
   `exp(-Normal(0, sd = 0.5844·γ))`, normalized to sum to 1 across fields. Immigrant
   wasps from the shared dispersal pool are allocated across fields proportional to
   this. γ=0 → all fields equally attractive; larger γ → more heterogeneous landscape.
2. **Density-dependence of wasp emigration.** `emigration_i = wasp_disp_m0 · exp(-wasp_disp_m1 · log(z_i))`,
   where `z_i` is total living aphids in field i, `wasp_disp_m0 = 0.3` (fixed), and
   `wasp_disp_m1 = 0.34906·γ`. Larger γ → emigration falls off faster with local aphid
   density (wasps stay where hosts are abundant).

γ = 1.0 is the field-derived nominal value (`04-paras-disp-hetero.R`'s
`pick.wasp.var <- 11L` indexes `wasp.var.list <- 0.1*(0:20)`, i.e. γ = 1.0),
matching this doc's existing "γ = 1 → ~170-day cycles" row.

### Parasitism functional response — confirmed, and it's not mass-action

`src/wasps.hpp:85,93` (age-structure terms collapse away when wasps aren't split into
attack-age classes — `rel_attack`'s five weights sum to 1, so a single aggregate wasp
pool just uses `rel_attack = 1`):

```
A_bar_i = a · W_i / (h · N_i + 1)              // mean attacks per host, Holling-II
attack_prob_i = 1 − (1 + A_bar_i / k)^(−k)     // May (1978) negative-binomial aggregation
```

with `a = 2.32`, `h = 0.008`, `k = 0.35` (aggregation parameter — this, not the mean, is
what produces the "greater-than-binomial variation" this doc's acceptance table
mentions for γ=1). `N_i` = total living aphids in patch i, `W_i` = adult wasps in patch
i. **This saturating, aggregated form — not simple mass-action — is what the aphid-
dispersal bifurcation structure depends on**; a mass-action reduction would likely lose
the δ_a<0.04 Hopf bifurcation.

`a`, `h`, `k` were fit against the source's own implicit density units (roughly:
aphids/wasps per unit field area), which don't map directly onto a small 2–3-patch
reduced model using raw counts. The reduced model keeps `a` and `k` as transcribed
(rate constant and aggregation are dimensionless-ish) and treats the absolute
population scale (patch carrying capacity, and therefore the effective `h`) as a
**calibrated**, not transcribed, quantity — tuned numerically so the reduced model's
δ_a/γ bifurcation locations land near this table's thresholds. This is flagged, not
invented: the structural form is exact; the magnitude is a documented simplification
required by shrinking 28 fields to 2–3.

### Harvest — confirmed exact match to this doc's existing numbers

`04-paras-disp-hetero.R:54-72`: every 28 days per field, staggered one field/day.
Aphid (both clones) post-harvest survival drawn `Uniform(0.01, 0.04)` (96–99%
mortality, exactly this doc's existing figure). Mummy survival = 0 (100% mortality).
Adult wasps are never touched by harvest (escape by flight, exactly this doc's existing
note). The package's own generic default (`environ$harvest_surv = 0.05`,
`cycle_length = 30`) is a *different*, non-paper-specific placeholder — not used here.

### Time step and stage structure

Daily discrete step throughout; harvest is a discrete event between days, not
integrated across (confirms this doc's existing numerical note). Mummy
(egg-to-adult-wasp) development: 7 days as a living-but-parasitized host + 3 days as a
mummy = 10-day delay before an attack becomes an adult wasp. Adult wasp daily survival
`s_y = 0.69`. `sim_experiments()`'s own default/README example uses 2 patches; the
28-field number belongs to the full field model this doc's "Reduction target" section
already says not to reproduce.

## Reduced model spec (implemented in `js/model.js`)

State, per patch `i` of `P` patches (`P` = 2 or 3):

- `S_i`, `R_i` — susceptible / resistant aphid counts
- `W_i` — adult wasp count
- `mummies_i[0..9]` — a 10-slot delay queue (7 days living-parasitized + 3 days mummy,
  per the transcription above); slot 0 ecloses to an adult wasp each day
- `attract_i` — fixed per-patch wasp attractiveness weight, drawn once at simulation
  setup as `exp(-Normal(0, sd = 0.5844·γ))` and normalized to sum to 1 across patches
  (transcribed mechanism; the *draw* itself is necessarily reduced-model-specific since
  there are 2–3 patches here, not 28)

Daily step, in order:

1. `N_i = S_i + R_i`.
2. `attack_prob_i = 1 − (1 + (a·W_i / (h·N_i + 1)) / k)^(−k)`, transcribed `a`/`k`,
   calibrated `h` (see above).
3. `attacked_S_i = S_i · attack_prob_i`, `attacked_R_i = R_i · attack_prob_i` — same
   exposure for both clones; the resistance difference is entirely in what happens
   next.
4. Susceptible: 0% post-attack survival. Resistant: `resist_benefit` (0.73) post-attack
   survival. All attacked-and-dead individuals (both clones) enter the mummy queue —
   **simplifying assumption, flagged as open**: `gameofclones`'s own `surv_paras = 0.57`
   term implies the *H. defensa* toxin can kill the developing wasp even when it kills
   the host too, which would mean not every dead resistant aphid yields a viable mummy.
   V1 assumes it does (simpler, and conservative in the direction of *more* parasitoid
   pressure, which most matters for the δ_a/γ instability side of the acceptance
   criteria). Revisit if the resistant-favoring bifurcations don't calibrate cleanly.
5. Unattacked individuals of each clone reproduce with Beverton-Holt-style density
   dependence: `X_i,next = (X_i − attacked_X_i) · λ_X / (1 + N_i / K)` for `X ∈ {S, R}`,
   `λ_S = 1.26`, `λ_R = 1.21` (transcribed, Ives et al. fitted), `K` calibrated.
6. Mummy queue shifts one day; slot-0 mummies eclose into `W_i` (before harvest, after
   growth); `W_i,next = W_i · s_y + eclosed_i`, `s_y = 0.69` (transcribed).
7. Aphid dispersal: pool `δ_a · alate_fraction · X_i` from every patch for each clone
   (`alate_fraction = 0.20`, transcribed), redistribute the pool evenly across patches
   (transcribed mechanism).
8. Wasp dispersal: `emigration_i = W_i · wasp_disp_m0 · exp(−wasp_disp_m1·γ · ln(max(N_i,1)))`,
   `wasp_disp_m0 = 0.3` (transcribed, fixed), `wasp_disp_m1 = 0.34906·γ` (transcribed).
   Pool emigrants, redistribute proportional to `attract_i` (transcribed mechanism).
9. Harvest, every 28 days, staggered `⌊28/P⌋` days apart across patches: aphid survival
   drawn independently per clone `~ Uniform(0.01, 0.04)` (transcribed); mummy queue for
   that patch zeroed (transcribed, 100% mortality); wasps untouched (transcribed).

## Calibration notes

`K` (per-patch carrying capacity) and the absolute population scale it sets `h` against
are **not** transcribed — see "Parasitism functional response" above for why the
source's units don't map onto a 2–3-patch reduction. These are tuned numerically
(parameter sweep in `test/sweep.mjs`) so the reduced model's own δ_a/γ bifurcation
locations land in the right qualitative places. Do not expect the reduced model's
actual numeric thresholds to land exactly on 0.04 / 0.10 / 0.258 or 0.6 — those are the
full 28-field model's thresholds.

**Result of calibration (2026-09-14), `patchCarryingCapacity = 500`, `attackH = 2.0`**
(`js/model.js`'s `CALIBRATED_DEFAULTS`):

- **Reproduced, validated by `test/model.test.mjs`:** the low-δ_a mechanism from
  `docs/DESIGN.md` ("too little aphid dispersal → parasitoid population crashes → with
  no parasitism pressure the susceptible clone outcompetes the resistant one"). At
  δ_a = 0.04–0.06 the parasitoid population collapses (mean adult wasps ~1–3 across a
  2–3 patch, 3000-day run) and the resistant clone is fully excluded (final resistant
  proportion 0.00). At δ_a ≥ 0.10 wasps persist robustly (mean ~4–50, increasing with
  δ_a) and resistant is not excluded. The γ threshold also landed close to the
  full-model figure: γ < 0.6 → wasp extinction; γ ≥ 0.8 → persistence, matching this
  doc's "γ < 0.6 → parasitoid extinction" row well.
- **NOT reproduced — open limitation, shipped anyway per explicit product decision
  (2026-09-14):** the high-δ_a mechanism ("too much aphid dispersal → patches
  homogenize → selection mosaic erased → resistant clone excluded", and the
  δ_a > ~0.258 saddle-node collapse). Swept δ_a up to 0.95 (2 and 3 patches, symmetric
  and asymmetric starting conditions) — long-run cycling amplitude only ever *decreases*
  monotonically as δ_a increases; nothing destabilizes. Likely cause: this doc's own
  framing of the real result — "population abundances themselves change little across
  this range — the interesting change is in stability, not in numbers" — describes a
  saddle-node bifurcation in the *fixed point's existence*, a property of the full
  stage-structured system's linearization, not something brute-force trajectory
  simulation of a small patch count will discover by tuning `K`/`h` further. Reproducing
  it properly likely needs either many more patches or actual linearized stability
  analysis (Jacobian eigenvalues at the fixed point) rather than trial-and-error
  simulation — a materially different, bigger effort, deferred. **Do not build UI copy,
  a game level, or a "hidden trap" mechanic that depends on the high-δ_a failure mode
  actually occurring in this simulation — it won't.** The `resources/` v1 game is scoped
  to the low-δ_a / γ mechanisms only; revisit this doc before adding a high-dispersal
  level.
- **Also NOT reproduced — a second open limitation, found while writing acceptance
  tests:** DESIGN.md's "domain of attraction" bistability (does starting resistant
  proportion alone, at fixed δ_a/γ, determine which clone is excluded?). Tested directly
  at δ_a=0.10: a 1%-resistant start and a 99%-resistant start converge to the *same*
  long-run outcome (resistant excluded), not different ones. Cause: at this calibration
  the wasp population undergoes deep boom-bust troughs and eventually bottoms out near
  zero regardless of the starting clone ratio — once both patches' wasps hit ~0
  simultaneously there is no immigration to rescue them (a real property of a small,
  closed 2–3-patch reduction; the full 28-field system has enough patches that
  simultaneous extinction everywhere is far less likely). **Do not build a level around
  "same parameters, different starting resistant proportion, different outcome"
  without first re-checking this** — as calibrated, it isn't true here.

## Source of truth

1. `lucasnell/gameofclones` v1.0.2 — https://doi.org/10.5281/zenodo.8429166
2. `lucasnell/gameofclones-data` v1.0.4 — https://doi.org/10.5281/zenodo.10570148
3. Nell et al. 2024 Science supplementary: Materials and Methods, figs. S1–S21,
   tables S1–S8
4. Ives et al. 2020 Nat Ecol Evol Methods section (stage-structured Leslie matrices for
   aphid instars and parasitoid stages, attack-rate formulation, state-space fitting)

## Reduction target

The full field model is 3780-dimensional. The published phase portraits are 1-D
projections and are explicitly described as approximate visualizations. Reproduce the
**qualitative bifurcation structure**, not the full system.

Minimum state the game needs:

- Two aphid clones per patch: susceptible (high fecundity) and resistant (*H. defensa* +
  APSE3, low fecundity)
- Parasitoid abundance per patch
- Small number of patches (see open question in DESIGN.md)
- Dispersal pools for aphids and parasitoids
- Harvest events on a 28-day cycle

## Acceptance criteria — these are the tests

Write these as assertions against the headless simulation before building any UI.

### Aphid dispersal (δ_a), from Nell et al. Fig. 3A

**Reduced-model validation status:** see "Calibration notes" above. The δ_a < 0.04 row
is reproduced (as parasitoid-crash → exclusion, not literally as a Hopf bifurcation to
cycles — the reduced model doesn't distinguish those two routes to the same failure).
The δ_a ≈ 0.10 and δ_a > 0.258 rows are **not currently reproduced** — v1 ships without
them, by explicit decision.

| Condition | Expected behavior |
|---|---|
| δ_a ≈ 0.10 (nominal, lab experiment) | Stable point *and* an unstable stationary point both present |
| δ_a > ~0.258 | Globally unstable — the two clones and the parasitoid cannot all persist |
| δ_a < 0.04 | Neimark-Sacker (Hopf) bifurcation → permanent cycles |
| δ_a decreasing further | Cycle amplitude increases until parasitoid is eliminated |
| Starting resistant proportion below the unstable point | Resistant clone excluded |
| Starting resistant proportion very high | Parasitoid temporarily crashes → susceptible dominates → parasitoid recovers when resistance is low |

As δ_a increases, the unstable point converges on the stable point and both are
eliminated in a saddle-node bifurcation. Population abundances themselves change little
across this range — the interesting change is in stability, not in numbers. Worth
surfacing in the UI, since it is counterintuitive.

### Parasitoid dispersal heterogeneity (γ), from Nell et al. Fig. 3B

| Condition | Expected behavior |
|---|---|
| γ = 1 | Corresponds to field-derived estimates; cycles ~170 days (six harvest cycles); greater-than-binomial variation comparable to field data |
| γ < 0.6 | Unstable cycles in parasitoid abundance → parasitoid extinction → susceptible clone outcompetes resistant |
| γ = 1.0, controlling for effect of γ on overall parasitoid dispersal rate | Similar threshold appears |

There is a **minimum degree of parasitoid dispersal heterogeneity required to stabilize
the system.** That is the lesson of this axis.

### Harvest events (field model)

- Every 28 days per field; fields staggered so each is harvested on a different day
- Pupal parasitoid mortality: **100%**
- Aphid mortality (parasitized or not): drawn uniform **96–99%**
- Adult parasitoids escape by flight — **unaffected**

### Trade-off parameters (Ives et al. 2020, fitted)

- Resistance benefit: probability of surviving parasitism = **0.73** for
  *Hamiltonella*–APSE3 clones, **0** for susceptible
- Resistance cost: parasitism-independent intrinsic rate of increase
  **1.26 d⁻¹ → 1.21 d⁻¹**
- Selection threshold: at mean observed resistant proportion Q = 0.48, observed
  parasitism **> 21%** favors resistance; bounded **13%–30%** across the extreme
  observed proportions (Q = 0.88 and Q = 0.02)

### Field-scale reality checks

- Observed *Hamiltonella*-containing clone frequency ranges **2%–88%** across fields
- Resistance neither vanishes nor fixes at the regional scale
- Regional equilibrium is self-correcting: resistance up → parasitoid population
  declines → selection against resistance → return to equilibrium (~1000 days to
  recover from an imposed perturbation)
- Roughly **20%** of adult aphids at the field site are winged (dispersal-capable)

## Lab experiment parameters (useful for a two-patch tutorial level)

- Seven cage pairs, 30 × 120 cm, one with parasitism and one without
- 250-day run ≈ 80 aphid population doubling periods
- Manual dispersal every 3–4 days, pooling winged adults from cage sides and the tops
  of 25% of plants
- No-dispersal + no-parasitism → susceptible excludes resistant
- No-dispersal + parasitism → either parasitoids kill all aphids and are then eliminated,
  or only the resistant clone persists
- With dispersal → neither clone excluded for the duration; cage-level extinctions
  transient, and only after parasitoids reached especially high abundance

A two-patch tutorial reproducing this is probably the right first playable.

## Numerical notes

- Seed all RNG. Clone trait draws and harvest mortality draws must be reproducible.
- Cap or adapt timestep. Stiffness appears at high dispersal and around harvest events.
- Harvest is a discrete event inside a continuous-ish simulation. Handle explicitly;
  do not let the integrator step across it.
