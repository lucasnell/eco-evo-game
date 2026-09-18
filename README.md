# Game of Clones

A short-form game about **eco-evolutionary dynamics**, built on the pea aphid
(*Acyrthosiphon pisum*) / *Aphidius ervi* parasitoid system studied in
[Nell et al. 2024, *Science*](https://doi.org/10.1126/science.adg4602).

You manage a landscape of six alfalfa fields. You never touch the aphids: you open
corridors between fields, and you plant shelter habitat. Everything else — how many
aphids there are, how many wasps, and what fraction of the aphids carry resistance —
follows from those two decisions and from the simulation's own rules.

## What it is trying to show

1. **Evolution fast enough to matter.** Resistance rises and falls within a single
   playthrough, on the same timescale as the population dynamics it is changing:
   wasps build up → resistance climbs → wasps starve on aphids they cannot use →
   resistance fades because it costs fecundity → wasps recover. The end-of-year
   read-out measures the delay between parasitism and the resistance that follows it
   from your own run (typically 60–120 days).
2. **What it takes to keep all of it alive.** Moderate aphid dispersal *and* genuinely
   uneven parasitoid habitat are both required for the wasps and both aphid clones to
   persist together. Cut the fields off from each other and the parasitoid starves;
   make every field identical — bare *or* lush, it does not matter which — and the
   parasitoid has nowhere worth flying to; connect everything to everything and the
   fields stop being different places at all.

Neither lesson is scripted. Both fall out of the simulation rules, and the game says so
only after the fact, using the numbers from the year you just played.

## Running it

Requires [Godot 4](https://godotengine.org/) (developed against 4.7).

```sh
# play
/Applications/Godot.app/Contents/MacOS/Godot --path .

# simulation acceptance tests (headless, ~1 min)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://test/test_sim.gd

# render screenshots of a good year and a failed one into shots/
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://test/capture.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://test/capture.gd -- fail
```

If `class_name` lookups fail on a fresh clone, run `--headless --path . --import` once
to build Godot's script class cache.

## Layout

| Path | What it is |
|---|---|
| `scripts/sim.gd` | The simulation. Headless, seeded, no rendering — the single source of truth for the dynamics. |
| `scripts/game.gd` | Game loop, landscape UI, end-of-year read-out. |
| `scripts/field_view.gd`, `corridor_view.gd`, `chart.gd` | Drawing only. |
| `test/test_sim.gd` | Acceptance tests, driven through the same landscape interface the player uses. |
| `test/capture.gd` | Runs the real scene and screenshots it, so UI bugs stay separable from simulation bugs. |
| `docs/MODEL.md` | Which constants are transcribed from the published source, which are calibrated, and what is validated. Read before changing the model. |
| `docs/DESIGN.md`, `docs/SOURCES.md` | Design constraints and the literature behind them. |

## Scientific provenance

Parameters and mechanisms are transcribed from
[`lucasnell/gameofclones`](https://doi.org/10.5281/zenodo.8429166) — the code behind the
paper — not re-derived from the PDF. `docs/MODEL.md` keeps the file:line record, and is
explicit about the two things that are *not* transcribed: the absolute population scale,
and the demographic stochasticity a game needs in order for extinction to be possible.
The model is a reduction: it reproduces the qualitative bifurcation structure, not the
full 3780-dimensional field model.
