# Session handoff — 2026-09-14 (updated 2026-09-15, superseded 2026-09-18)

Read this first if you're picking this project up cold. It's a narrative summary of
past sessions' work; `CLAUDE.md` and `docs/MODEL.md`/`DESIGN.md` are the living
reference docs and take precedence if anything here goes stale.

> **2026-09-18: most of what follows is now history, not current state.** The project
> owner's verdict on the two HTML pages was that they "aren't really games; they're just
> interactive figures," and asked for an actual game in Godot. Both pages, `js/` and the
> node tests were deleted and replaced by a Godot 4 game (`scripts/sim.gd` +
> `scripts/game.gd`, `README.md` for how to run it). Read `CLAUDE.md`'s "Current state"
> and `docs/MODEL.md`'s "Godot port" section for what actually exists now. Everything
> below is kept because the *reasoning* — why the model is a reduction, what calibrated
> cleanly and what didn't, why the farm-manager variant needed stage structure — still
> explains why the simulation looks the way it does.

**2026-09-15 update:** pushed to GitHub — `lucasnell/eco-evo-game`, public, `main`
branch. Before pushing, `docs/papers/` (8 copyrighted third-party PDFs, not all
authored by the repo owner) was purged from git history entirely with
`git filter-repo` and gitignored going forward — see `docs/SOURCES.md`. The
"no remote" risk noted below on 09-14 no longer applies; that's why this update
exists.

## Where this stands

Two playable pages exist, both single-file HTML/vanilla JS, all committed and pushed
to `github.com/lucasnell/eco-evo-game` (public, `main`).

- **`index.html` — "Dispersal Lab."** Two-cage tutorial. Player tunes δ_a (aphid
  dispersal) and γ (parasitoid dispersal heterogeneity) between turns and watches
  whether the parasitoid persists and both aphid clones coexist. Teaches the low-δ_a /
  low-γ mechanism: dial either down far enough and the parasitoid population crashes,
  which then excludes the resistant aphid clone (nothing left to make its fecundity
  cost worth paying).
- **`hidden-trap.html` — "Farm Manager."** Player is framed as maximizing crop yield
  via one lever ("habitat connectivity investment," a landscape framing of δ_a). Plays
  the conservation-biological-control paradox: sustained high investment helps the
  parasitoid, which sounds purely good, but the sustained parasitism pressure also
  selects the pest for resistance — so yield actually erodes *more* under high
  investment than low, even though wasp numbers look the same in both cases. The
  reveal comes at the end of 5 simulated seasons.

Both open by double-clicking the file — no server, no build step. `node --test test/`
runs 13 passing tests. Try it yourself: `open index.html` or `open hidden-trap.html`.

## How the session got here

1. **Recovered prior-session design work.** A previous chat had already produced
   `CLAUDE.md` + `docs/DESIGN.md`/`MODEL.md`/`SOURCES.md` (plus the cited papers) for
   this exact game concept, with hard constraints (no trait-selection menus, player
   manipulates environment not organism, etc.) and an explicit next step: transcribe
   the real model from `lucasnell/gameofclones` source and build a headless sim before
   any UI. This session found that work at `~/GitHub/eco-evo-game` (not yet a git
   repo) and picked it up from there.
2. **Transcribed exact constants from source**, not the paper PDF — cloned
   `gameofclones` and `gameofclones-data`, dug through the R/C++ (parasitism
   functional response, δ_a/γ dispersal mechanics, harvest mortality) and the analysis
   scripts that actually produced the paper's Fig. 3. All cited file:line in
   `docs/MODEL.md`'s "Transcription record."
3. **Built and calibrated `js/model.js`**, the dispersal-lab simulation. Validated
   against a *subset* of the original paper's bifurcation thresholds — see
   `docs/MODEL.md`'s "Calibration notes" for exactly what's confirmed (low-δ_a crash,
   γ<0.6 threshold) vs. explicitly not reproduced and flagged, not faked (the
   high-δ_a homogenization collapse, and a domain-of-attraction bistability). This was
   a deliberate scope decision, made with the user, to ship on what calibrates cleanly.
4. **Built `index.html`.** Verified in real headless Chrome (Playwright + system
   Chrome via `channel: "chrome"`, not a downloaded browser) at 390px and 1280px:
   no horizontal overflow, no JS errors, the crash narrative actually triggers when
   δ_a is dialed down.
5. **Attempted five more mechanics from `DESIGN.md`'s "parked ideas"** (hidden trap,
   harvest-timing lever, Geber scoreboard, diversity-dial, epidemic-diagnosis). Found
   that three of them (hidden trap, harvest-timing, Geber) all depend on a *smooth*
   multi-season trend, and `js/model.js`'s dynamics are chaotic over many harvest
   cycles — confirmed via patch-averaging, 40-seed ensembling, and several alternate
   `(K, attackH)` calibrations, all still chaotic. This is structural, not a tuning
   gap. Flagged this to the user; they narrowed scope to hidden-trap only and dropped
   the other four entirely (harvest-timing, Geber scoreboard, diversity-dial,
   epidemic-diagnosis — the last two are unrelated systems with no reference code,
   would need their own from-scratch transcription from `docs/papers/Yoshida...` and
   `docs/papers/Duffy...` if ever revisited).
6. **Solved the chaos problem for the hidden trap** by adding aphid stage structure —
   a maturation delay (newborns spend several days as non-reproducing juveniles before
   joining the adult pool), the same delay-queue mechanism already used for wasp
   mummies. This is a real simplification the original reduction had collapsed away
   (real aphids take about a week to mature); reintroducing it damps the
   single-generation overshoot that was driving the chaos. Built as a **separate**
   model file, `js/model-farm.js`, not a change to `js/model.js` — the two pages don't
   share a model on purpose, see below.
7. **Calibrated the new variant from scratch** (it needed its own fecundity/density-
   dependence derivation — the old model's `K`/`attackH` didn't transfer to the new
   growth mechanism) and discovered γ's effect ran the *wrong direction* in early
   testing (lower γ produced more resistance, not less). Rather than chase that down,
   switched the farm-manager mode's single lever to δ_a instead, which gave a clean,
   correctly-signed, seed-robust result — and conveniently sidesteps `DESIGN.md`'s
   still-unresolved question of how to give γ an honest farmer-facing name.
8. **Built `hidden-trap.html`.** First version's investment range (δ_a 0.02–0.35) was
   correctly signed but the season-5 yield gap between 0% and 100% investment was only
   1–2 percentage points — too subtle to read as a game. Widened to 0–0.9 (still
   smooth, still monotonic, checked cycle-by-cycle not just at the endpoint) for a
   4–8 point gap. Verified in real headless Chrome, both viewports: mid-game and
   end-of-season narrative reveals trigger correctly, yield bar chart renders, the
   "field data" detail panel opens and shows sensible numbers.

## Two separate models, on purpose

`js/model.js` (dispersal lab) and `js/model-farm.js` (farm manager) are **intentionally
not shared**. They use the same transcribed parasitism/dispersal/harvest mechanics but
different aphid growth structure (instantaneous vs. stage-delayed), because each is
calibrated for a different kind of signal (binary threshold vs. smooth trend) and
neither calibration transfers to the other's growth mechanism. Don't try to unify them
without re-running both test suites and re-validating both pages against
`docs/MODEL.md`. Both `index.html` and `hidden-trap.html` inline a hand-copied version
of their respective model file into their `<script type="module">` — if you edit
`js/model.js` or `js/model-farm.js`, the corresponding HTML file's inline copy needs
the same edit by hand (no build step to keep them in sync automatically).

## Immediate next steps, roughly in order of likely value

1. **Play both pages yourself** and see if the pacing, tone, and visual design actually
   land for the intended teen audience — nothing here has had real playtesting beyond
   the automated browser checks.
2. **Decide on embedding into lucasnell.com.** This repo is currently standalone. The
   website (`~/GitHub/nell_website_quarto` — `CLAUDE.md`/`docs/` live in that repo now,
   not in Box) is live (cutover happened 2026-09-14, continuous deployment wired up) —
   if/when this game should be linked from the site, that's a separate piece of work
   in that other repo, most likely a new `resources/<slug>/index.qmd` page or an
   iframe/link out to wherever these HTML files end up hosted.
3. **The two documented-but-unsolved threads**, only worth chasing if a specific level
   design needs them: the dispersal lab's high-δ_a instability (would need either many
   more simulated patches or actual linearized stability analysis, not more
   trial-and-error simulation — see `docs/MODEL.md`), and the farm-manager model's
   backwards γ effect (never investigated past the point of switching to δ_a instead).
4. **`docs/DESIGN.md`'s still-open questions** haven't moved: landscape vs.
   lab-instrument framing for γ (the dispersal lab uses lab-instrument; the farm
   manager mode sidestepped the question by not exposing γ at all), and whether
   initial resistant proportion should be player-set or dealt (currently player-set in
   both modes).
