# Design notes

## Audience and scope

Teens. Short-form — currently targeting something a teacher could drop into a class
period, not a game with hours of progression. Scope may expand later; do not build
progression scaffolding yet.

## Chosen core: the Nell et al. dispersal system

The player tunes aphid dispersal (δ_a) and parasitoid dispersal heterogeneity (γ) and
watches whether aphid clones and parasitoids coexist.

### Why this system earns its place

**Both failure modes end identically on screen, for opposite reasons.** This is the
strongest design property in the whole stack.

- *Too much aphid dispersal* → patches homogenize → selection mosaic erased → genetic
  variation for resistance lost → resistant clone excluded.
- *Too little aphid dispersal* → parasitoid population crashes → with no parasitism
  pressure the susceptible clone outcompetes the resistant one → resistant clone
  excluded.

Same end state. The player must read the intermediate dynamics — did the parasitoid
crash first, or did the patches converge first? — to diagnose which mistake they made.
That is a genuine scientific reasoning skill, and very few educational games can
manufacture a situation that requires it.

**Alternative stable states / domain of attraction.** At a fixed δ_a and γ, the outcome
still depends on the *starting proportion of resistant aphids*. Start too low and the
resistant clone is excluded. Start too high and susceptibles become rare, the parasitoid
population temporarily crashes, susceptibles dominate, and the parasitoid recovers only
when resistance is already low. A level where the player has correct parameters and
still loses teaches that history and initial conditions constrain outcomes. Almost
nothing at this level teaches that.

## The γ problem (unresolved — decide before building UI)

γ is not a quantity anyone manipulates in the world. It is an emergent property of
landscape structure and aphid density that was *estimated* from field data. Aphid
dispersal has a plausible physical handle (field connectivity, spacing, barriers);
parasitoid dispersal heterogeneity does not.

Handing a teenager a slider labeled "parasitoid dispersal heterogeneity" teaches them
it is a knob on the world. Two ways out:

1. **Lab-instrument framing (preferred for core).** The player is explicitly a modeler
   running simulations. Parameter names stay honest, γ stays γ, and the interface is
   openly a research tool. Truthful, and preserves the paper's vocabulary.
2. **Landscape framing (possible later mode).** Bury γ under things the player builds —
   hedgerows, field spacing, refuge strips — with the mapping approximate and stated as
   approximate. More game-like, less exact.

Current lean: build (1) as the core, keep (2) as a later mode.

## The hidden trap (from Ives et al. 2020 discussion)

Give the player a goal that is *not* the lesson: maximize crop yield via parasitoid-based
biological control.

The hidden dynamic is the conservation-biological-control paradox. Management that
benefits the control agent increases selection on the pest for resistance, which
undermines the control. A player who optimizes hard for parasitoid habitat wins for two
seasons, then watches resistance climb and control degrade. Because resistance carries a
fecundity cost, pest populations may still decline even without long-term change in
parasitoid abundance — so the *apparent* signal (no increase in agent numbers, no
increase in direct mortality) understates the real effect.

This is the paper's own argument, playable.

## Turn structure

The field system supplies natural timing:

- Harvest cycle: **28 days**
- Population cycles at γ = 1: **~170 days ≈ six harvest cycles**
- Lab experiment ran **250 days ≈ 80 aphid population doubling periods**

So: one turn = one harvest cycle, fast-forwarded. Not real-time. A full population cycle
is roughly six turns, which is a reasonable session length for short-form play.

## Ideas considered and parked (from earlier workshopping)

Any of these could become an alternate level. Kept here so they are not lost.

- **The diversity dial (Yoshida et al. 2003).** Slider from 1 to 7 algal clones in a
  rotifer–algae chemostat. One clone gives short cycles with a classic quarter-period
  lag; multiple clones give long cycles with predator and prey nearly out of phase. The
  player watches a predator starve amid abundant food. Simplest possible demonstration
  of the concept; strongest candidate for a 20-minute standalone.
- **The epidemic that ends for the wrong reason (Duffy & Sivars-Becker 2007).** Player
  assumes outbreaks end when susceptibles are depleted. A zero-genetic-variance model
  predicts the parasite goes endemic, which real lakes contradict. Adding clonal variance
  terminates epidemics in 20–80 days, matching field observation. Diagnosis puzzle.
- **Harvest timing as the eco lever (Ives et al. 2020).** Mow synchronously or in
  staggered strips. Staggered keeps aphids continuously available → wasps thrive →
  parasitism rises → resistant clones go from ~10% to ~62% in one season → next year
  those populations show lower parasitism and higher growth. Eco→evo→eco in two turns.
- **The Geber scoreboard (Schoener 2011 / Hairston et al. 2005).** End-of-level
  assessment that partitions change in population growth rate into ecological and
  evolutionary contributions. Ask the player to predict the ratio before revealing it.
  In Darwin's finches evolution contributed ~2.2× the ecological contribution; in the
  copepod, about one quarter.

## Open questions

- ~~Lab-instrument vs. landscape framing for γ~~ — **resolved in the Godot build.**
  Neither: γ is not exposed at all. The player places shelter habitat per field, and γ
  emerges as the *unevenness* of the resulting wasp attractiveness. Uniform shelter gives
  γ = 0 whether every field is bare or every field is lush. Keep this property in any
  redesign; it is the honest treatment and it produces the best counterintuitive moment
  in the game.
- ~~How many patches to expose?~~ Six. Readable on screen, and enough for the
  between-field mosaic to be a meaningful quantity.
- Does the player set initial resistant frequency, or is it dealt to them? Currently
  dealt — drawn per field at setup, varying across fields to seed a mosaic.
- Where does the Geber-style scoreboard fit, if at all? Partly superseded: the Godot
  build's end-of-year read-out measures the lag between parasitism and the resistance
  response from the player's own run, which does similar teaching work more cheaply.

## Redesign in progress (2026-09-18) — READ THIS BEFORE BUILDING ANYTHING

The Godot build (see `CLAUDE.md`'s "Current state") is complete, validated and playable,
but the project owner raised **two objections that block further polish**. Do not keep
refining that build; the next session resumes this design discussion.

### Objection 1 — pacing

The real-time continuous simulation is too much to follow. Verbatim: "Wow, that was
intense. Hard to keep track of things. Let's try a different approach that's more slow,
perhaps even turn-based."

Direction under discussion: **one turn = one harvest cycle (28 days)**, nothing advancing
unless the player advances it. The transcribed 28-day cut already supplies a natural turn
boundary, so this costs nothing in fidelity.

### Objection 2 — the farm framing is scientifically wrong-footed

Verbatim: "I'm also not sold on having it based on farming because stability of the
aphid-parasitoid system is not necessarily good for crop yields."

This is correct, and it is the more serious of the two. Note that the Godot build already
*scores* stewardship (persistence + genetic variation) rather than yield, precisely
because the model shows aphid load rising with dispersal — but the farm **setting** still
implies the player ought to want a good harvest, which is the wrong lesson.

Supporting point from the paper itself (read 2026-09-18): Nell et al.'s framing is
**general ecology, not biological control** — it unites "what allows species to coexist"
with "what maintains genetic variation in a population." Alfalfa is the study *setting*,
not an applied pitch. Agriculture-as-goal is a framing the source does not support.

### Candidate directions (proposed, none chosen)

Setting and scoring loop are **independent** choices; they can be mixed freely.

*Settings:*

1. **Generation ship / sealed habitat (sci-fi).** Ecologist on a long voyage; pest and
   parasitoid are both inside a closed life-support system and *cannot be restocked*.
   Makes persistence and standing genetic variation the literal mission rather than an
   imposed score, and removes the yield confound structurally. Harvest maps onto
   scheduled rotation of the hydroponics bays.
2. **Terraforming outpost.** Domes as patches, airlock corridors as dispersal. A looser
   version of 1, with less force behind the "cannot restock" constraint.
3. **Play the real biology as the fantastical hook.** The resistance is a phage inside a
   bacterium inside the aphid, killing the wasp larva — a three-layer nested symbiosis
   that undergraduates reliably find startling. Costs nothing in fidelity.
4. **Researcher / field-study framing.** The paper's own posture, and this doc's original
   preference. Persistence and variation are honestly the goals because they are what the
   researcher wants.
5. **Wild, non-agricultural landscape.** Removes the yield implication entirely, but
   drifts from the real study system and from the transcribed 28-day harvest mechanics.
   Weakest on fidelity.

*Scoring loops:*

- **Hidden state + limited sampling + committed predictions ("grad student sim").** The
  player cannot see true populations; each turn they spend limited sampling effort, then
  commit a claim ("resistance is rising because parasitism rose") that the data supports
  or embarrasses. Matches the real 2011–2019 survey epistemics, makes *reading the
  dynamics* the gameplay rather than a side effect, and suits a turn structure. Adds one
  layer of mechanics.
- **Full information.** Simpler and more readable, but risks turns feeling like clicking
  "next" on a figure — the failure mode the owner already rejected once.

### Unresolved — ask before assuming

- **Audience.** `CLAUDE.md` says teenagers; the owner has now asked for ideas that
  "resonate with undergraduate students." Confirm which, since it changes tone, session
  length, and how much inferential load the game can carry.
- **Which to settle first**, the setting or the scoring loop.

The owner was asked both questions and left before answering, so start there.

### Invariants for any reskin

Whatever the setting, the mechanics must keep: two host genotypes with a
resistance/fecundity trade-off; a parasitoid whose distribution is spatially uneven;
patches with host dispersal between them; periodic disturbance that resets patches; and
the eco-evolutionary feedback closing and repeating. Plus every hard constraint in
`CLAUDE.md`. The simulation in `scripts/sim.gd` supports all of this already and should
be reusable as-is under a new presentation — the redesign is presentation and framing,
not model work.
