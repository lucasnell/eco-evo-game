# CLAUDE.md

## What this project is

A short-form educational game teaching **eco-evolutionary dynamics** to teenagers,
built on the pea aphid (*Acyrthosiphon pisum*) / *Aphidius ervi* parasitoid system.
The player manipulates **aphid dispersal** and **parasitoid dispersal heterogeneity**
and observes how those choices determine whether the system persists.

The project owner is an author on Nell et al. 2024 (Science), the paper this game is
based on. Scientific accuracy is therefore not negotiable: anything shipped here is
implicitly endorsed by an author of the source work.

## The concept being taught

Follow Bassar et al. (2021), not the loose definition. Eco-evo dynamics means
**reciprocal feedback with no separation in timescale**:

> density influences selection; selection influences genetic makeup;
> genetic makeup influences density

An ecological change that causes an evolutionary outcome is *not* eco-evo dynamics —
that is ordinary adaptive evolution. A trait change that alters population growth rate
is *not* eco-evo dynamics — that is Fisher's fundamental theorem. The game must show
the loop closing and repeating, not a one-way arrow.

Corollary: do not build a design where ecology happens "within a generation" and
evolution happens "across generations." That framing separates the timescales and
teaches the wrong thing.

## Hard constraints (do not violate without explicit instruction)

1. **The player never selects a trait.** No upgrade menus, no "choose your adaptation."
   Variation is present at the start; the environment does the filtering. Spore-style
   trait selection teaches Lamarckism and is the single most common failure mode in
   this genre.
2. **The player manipulates the environment, never the organism.** Levers are dispersal,
   connectivity, harvest timing, landscape structure.
3. **The resistance/fecundity trade-off is always enforced.** There is no strictly
   optimal clone. Resistant clones survive parasitism (est. 0.73 probability) but pay
   in reduced intrinsic rate of increase (1.26 → 1.21 d⁻¹).
4. **Clone frequencies change only through differential survival and reproduction.**
   Never set frequencies directly in response to player input.
5. **Failure is informative, not punitive.** Extinction shows the trajectory that
   produced it. No bare game-over screen.
6. **Do not mislabel model parameters as things a farmer controls.** See "The γ problem"
   in `docs/DESIGN.md`.

## Repo conventions

- Simulation logic must be **headless and testable first**. No rendering code until the
  dynamics pass the threshold tests in `docs/MODEL.md`.
- Simulation bugs and rendering bugs look identical on a canvas. Keep them separable.
- Seed all RNG explicitly. Unseeded clone-trait draws make it impossible to distinguish
  a real parameter effect from a lucky sample.
- Cap or adapt the integrator timestep. These dynamics stiffen at high dispersal and
  high harvest mortality.
- Prefer a single-file HTML + vanilla JS front end. No build step, no framework.
  The deliverable should run by opening a file.

## Reference implementation

Do **not** re-derive the model from the paper PDFs. Working, validated code exists:

- `lucasnell/gameofclones` v1.0.2 — https://doi.org/10.5281/zenodo.8429166
- `lucasnell/gameofclones-data` v1.0.4 — https://doi.org/10.5281/zenodo.10570148

Port a reduced version. The full field model is 3780-dimensional; the published phase
portraits are 1-D projections of it and are described as approximate visualizations.
A game needs a reduced model that reproduces the qualitative bifurcations, not the
full system.

## Current state

Headless simulation built and passing (`js/model.js`, `node --test test/`). Model
parameters/mechanics transcribed from the `gameofclones` source (see `docs/MODEL.md`'s
"Transcription record"), calibrated, and validated against a *subset* of the original
acceptance-criteria table — **read `docs/MODEL.md`'s "Calibration notes" before building
any UI or level**, since v1 was explicitly shipped on the mechanisms that work
(low-δ_a / low-γ → parasitoid crash → resistant clone excluded) rather than the full
table. Two mechanisms are documented as open gaps, not silently dropped: the high-δ_a
homogenization/collapse bifurcation, and DESIGN.md's domain-of-attraction bistability.
Do not design a level around either without re-verifying against the model first.

**First playable shipped** (`index.html`, single file, no dependencies, verified in a
real headless Chrome at mobile and desktop widths — see commit history for the
Playwright check). Two-cage tutorial matching the lab experiment, lab-instrument framing
for γ (the open framing decision in `docs/DESIGN.md` — landscape framing is still
unbuilt, revisit if wanted), player controls only δ_a/γ between turns, initial resistant
proportion set once and locked (never overwritten directly, satisfying hard constraint
4), failures shown as explanatory narrative rather than game-over (hard constraint 5).

`js/model.js`'s logic is duplicated by hand inside `index.html`'s inline `<script>` —
**if you change the model, update both** (or extract a shared build step later; not
worth it yet for one page).

**Hidden-trap / farm-manager mode shipped** (`hidden-trap.html`). This mode needed a
smooth multi-season trend, which `js/model.js`'s growth mechanism can't produce (it's
chaotic over many harvest cycles — confirmed via patch-averaging, seed-ensembling, and
several alternate calibrations, all still chaotic; this is structural, not a tuning
gap). Fixed by adding aphid stage structure (a maturation delay, same mechanism as the
existing wasp-mummy queue) in a **separate** model file, `js/model-farm.js` — do not
merge this back into `js/model.js` without re-validating both pages' acceptance tests.
See `docs/MODEL.md`'s "Farm-manager model calibration" for the full record: what's
transcribed vs. chosen vs. derived, and what this variant is and isn't validated for
(notably: γ's effect ran the *wrong direction* in early testing and was abandoned in
favor of δ_a as the single player-facing lever — don't expose γ here without redoing
that analysis; this variant also does not reproduce `js/model.js`'s low-δ_a crash
threshold, that's not what it's for). 5/5 tests pass in `test/model-farm.test.mjs`,
verified in real headless Chrome at mobile/desktop widths, screenshots in commit
history. The investment-to-δ_a range (`MIN_DELTA_A`/`MAX_DELTA_A` in `hidden-trap.html`)
was widened from an initial 0.02–0.35 to 0–0.9 during playtesting because the narrower
range was correctly signed but the season-5 yield gap between 0% and 100% investment was
only 1–2 percentage points — too subtle to read as a game. Keep `test/model-farm.test.mjs`
in sync if this range changes again.

Explicitly dropped, per product decision (2026-09-14) — do not build unless asked again:
harvest-timing lever, Geber scoreboard, diversity-dial level, epidemic-diagnosis level.
These would have hit the same chaos problem as the hidden trap (confirmed for
harvest-timing/Geber via the same diagnostic sweeps); diversity-dial and epidemic are
unrelated systems with no reference code, needing their own from-scratch transcription
from `docs/papers/Yoshida...` and `docs/papers/Duffy...` if ever revisited.

Not yet done: a landscape-framing mode for γ in the dispersal lab; embedding this
into lucasnell.com itself (this repo is currently standalone, not linked from the
Quarto site).
