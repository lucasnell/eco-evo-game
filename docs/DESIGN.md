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

- Lab-instrument framing vs. landscape framing for γ (see above).
- How many patches to expose? The field model uses 28 fields; the lab experiment used
  paired cages. Paired or small-N is far more readable on screen.
- Does the player set initial resistant frequency, or is it dealt to them? Dealing it
  makes the domain-of-attraction lesson land harder.
- Where does the Geber-style scoreboard fit, if at all, in a short-form build?
