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

Design phase. Mechanics chosen, nothing built. Next step is the reduced model spec
in `docs/MODEL.md` and the headless simulation.
