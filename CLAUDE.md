# CLAUDE.md

## What this project is

A short-form educational game teaching **eco-evolutionary dynamics** to undergraduates,
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

- **The deliverable is a Godot 4 game** (developed against 4.7). `scripts/sim.gd` is the
  simulation and the single source of truth for the dynamics; everything else draws it.
- Simulation logic must be **headless and testable first**. No rendering code until the
  dynamics pass the threshold tests in `docs/MODEL.md`. `test/test_sim.gd` runs headless
  via `Godot --headless --path . --script res://test/test_sim.gd`.
- Simulation bugs and rendering bugs look identical on a canvas. Keep them separable —
  that is what `test/capture.gd` (renders the real scene to `shots/`) is for.
- Seed all RNG explicitly. Unseeded clone-trait draws make it impossible to distinguish
  a real parameter effect from a lucky sample.
- Cap or adapt the integrator timestep. These dynamics stiffen at high dispersal and
  high harvest mortality.
- Anything that varies per-frame must not change the simulation. Population state
  advances only in `EcoSim.step()`, one simulated day at a time, independent of framerate
  or the speed the player has selected.
- **Work directly on `main`** (owner's instruction, 2026-09-18). No feature branches for
  now — this is a single-author project and the branch round-trip cost more friction than
  it was worth. If a session is forced into a git worktree (background jobs create one
  automatically, on a branch), merge it back to `main` and confirm the merge landed
  before the session ends; do not leave work stranded on a branch. Verify by checking
  that `main`'s SHA actually moved, not by trusting a "merge" that ran in the worktree —
  a merge run from the worktree reports "Already up to date" and does nothing, because
  the worktree is already on that branch.

## Reference implementation

Do **not** re-derive the model from the paper PDFs. Working, validated code exists:

- `lucasnell/gameofclones` v1.0.2 — https://doi.org/10.5281/zenodo.8429166
- `lucasnell/gameofclones-data` v1.0.4 — https://doi.org/10.5281/zenodo.10570148

Port a reduced version. The full field model is 3780-dimensional; the published phase
portraits are 1-D projections of it and are described as approximate visualizations.
A game needs a reduced model that reproduces the qualitative bifurcations, not the
full system.

## Current state

> **Paused mid-redesign (2026-09-18).** The Godot build below is finished and works, but
> the owner has rejected two things about it — the real-time pacing ("intense, hard to
> keep track of") and the farm framing (system stability is not the same as crop yield).
> **Read `docs/DESIGN.md`'s "Redesign in progress" section before doing any work**, and
> do not keep polishing the current build. One question is still open: whether to settle
> the setting or the scoring loop first — start there. (The audience question was
> answered on 2026-09-18: **undergraduates**, not teenagers.) The simulation itself is
> not in question and should be reusable as-is.

**Rebuilt as a Godot 4 game (2026-09-18).** The earlier deliverables — two single-file
HTML pages (`index.html` dispersal lab, `hidden-trap.html` farm manager) plus the JS
model files and their node tests — were **deleted**, at the project owner's request:
they were interactive figures rather than games. Version control retains them (last
present at commit 2fe8393), and `docs/MODEL.md` retains everything learned from building
them. Do not resurrect them without being asked.

What exists now is one game, `scripts/game.gd` + `scripts/sim.gd`, run with
`Godot --path .`. See `README.md` for commands and layout.

**The player builds a landscape; the model parameters emerge from it.** This is the
important design decision, and it resolves `docs/DESIGN.md`'s long-open "γ problem":

- Opening/closing **corridors** between fields sets aphid dispersal. A field's emigration
  scales with how connected it is, so δ_a emerges from the network rather than being a
  slider. No corridors → δ_a = 0; all seven open → ≈0.9.
- Placing **shelter habitat** per field (0–2 bands) sets parasitoid dispersal
  heterogeneity. What matters is the *unevenness*, not the amount: uniform shelter gives
  γ = 0 whether every field is bare or every field is lush. γ is never shown as a dial,
  which is the honest treatment DESIGN.md asked for, since it is an emergent landscape
  property and not something anyone turns. The briefing screen says so explicitly.

The player never selects a trait, never touches clone frequencies, and only changes the
land — hard constraints 1, 2 and 4 hold. Failure ends in a data-driven causal narrative
built from that run's own trajectory, not a game-over screen (constraint 5).

**Validated.** `test/test_sim.gd`, 14 checks, all passing, driven through the same
corridor/shelter interface the player uses (16 seeds × 18 harvest cycles each): good
landscape 16/16 persist; no corridors 0/16 (and the parasitoid is what goes first,
15/16); uniform shelter 2/16 whether bare or lush; between-field genetic variation
collapses ~4× when everything is connected; resistance swings >15 points in 16/16 runs
and lags parasitism by a mean 81 days. See `docs/MODEL.md`'s "Godot port" section.

Two model changes were needed, and are documented there rather than silently made:
population counts are now drawn from Poisson/binomial distributions (a game needs
extinction to be genuinely possible; all *rates* stay in the validated density units, so
the mean dynamics are unchanged), and the landscape is six fields rather than two or
three. With six fields the reduction now does show the high-δ_a homogenization mechanism
the old two-patch model could not — as loss of the between-field mosaic, not as
extinction. The domain-of-attraction bistability remains unreproduced; don't build on it.

Explicitly dropped, per product decision (2026-09-14) — do not build unless asked again:
harvest-timing lever, Geber scoreboard, diversity-dial level, epidemic-diagnosis level.
Diversity-dial and epidemic are unrelated systems with no reference code, needing their
own from-scratch transcription from the Yoshida and Duffy papers if ever revisited.

Not yet done: a tutorial level distinct from the briefing screen; sound; a web export
(Godot exports to HTML5, the obvious route to embedding this in lucasnell.com, which
remains unlinked — this repo is still standalone).
