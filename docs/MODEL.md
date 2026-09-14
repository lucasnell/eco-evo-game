# Model spec and acceptance criteria

## Status

**Skeleton.** Parameter values and equations must be transcribed from the reference
implementation (`lucasnell/gameofclones`) and the Nell et al. supplementary materials
before any simulation code is written.

Do not infer equations or constants from the main-text PDF. It describes structure, not
parameterization. Invented "plausible" constants produce dynamics that look right and
are not, and debugging that costs more than transcription.

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
