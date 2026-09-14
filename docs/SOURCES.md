# Source literature

What each paper contributes to this project. PDFs should be added to `docs/papers/`.

## Primary

**Nell, L. A., Kishinevsky, M., Bosch, M. J., Sinclair, C., Bhat, K., Ernst, N.,
Boulaleh, H., Oliver, K. M., & Ives, A. R. (2024).** Dispersal stabilizes coupled
ecological and evolutionary dynamics in a host-parasitoid system. *Science* 383,
1240–1244. doi:10.1126/science.adg4602

The core of the game. Moderate host dispersal plus heterogeneous parasitoid dispersal
stabilize both the ecological and evolutionary components. Too much dispersal homogenizes
space and destroys genetic variation; too little loses the parasitoid and then the
resistant clone. Supplies δ_a and γ thresholds, the domain-of-attraction result, and the
lab and field experimental designs. Project owner is first author.

**Ives, A. R., Barton, B. T., Penczykowski, R. M., Harmon, J. P., Kim, K. L., Oliver, K.,
& Radeloff, V. C. (2020).** Self-perpetuating ecological–evolutionary dynamics in an
agricultural host–parasite system. *Nature Ecology & Evolution* 4, 702–711.

Supplies the fitted cost and benefit of resistance, the harvest-timing manipulation
(asynchronous vs. synchronous hoop houses: 62% vs. 10% resistant clones in one season),
the selection threshold calculation, and the conservation-biological-control paradox that
the game's hidden trap is built on. Also the stage-structured model formulation.

## Conceptual framing

**Bassar, R. D., Coulson, T., Travis, J., & Reznick, D. N. (2021).** Towards a more
precise — and accurate — view of eco-evolution. *Ecology Letters* 24, 623–625.

The definitional discipline for this project. Restricts "eco-evolutionary dynamics" to
reciprocal feedback with no separation in timescale. Rules out the easy framings that
would otherwise sneak into a game design. Traces the idea to Pimentel (1961): density
influences selection; selection influences genetic makeup; genetic makeup influences
density.

**Schoener, T. W. (2011).** The newest synthesis: understanding the interplay of
evolutionary and ecological dynamics. *Science* 331, 426–429.

Accessible overview. Source of the Geber-method partitioning idea (evolutionary vs.
ecological contributions to population growth rate) and of the finch/copepod comparison
numbers used in the parked "Geber scoreboard" mechanic.

**Thompson, J. N. (1998).** Rapid evolution as an ecological process. *Trends in Ecology
& Evolution* 13, 329–332.

Early argument that rapid evolution belongs among standard working hypotheses in
ecology. Useful for framing text, less for mechanics.

**Hendry, A. P. (2017).** *Eco-Evolutionary Dynamics.* Princeton University Press.

Reference text. Note that Bassar et al. explicitly reject Hendry's cases 1 and 2 as too
broad a definition; use cases 3–5.

## Supporting empirical systems (parked mechanics)

**Yoshida, T., Jones, L. E., Ellner, S. P., Fussmann, G. F., & Hairston, N. G. (2003).**
Rapid evolution drives ecological dynamics in a predator–prey system. *Nature* 424,
303–306.

Rotifer–*Chlorella* chemostats. Single-clone algal populations produce short cycles with
mean phase lag 32% of cycle period (range 26–36%); multi-clone populations produce long
cycles with lag 56% (range 41–68%). Those numbers are directly usable as test assertions
if the "diversity dial" mechanic is ever built. Mechanism: low-food-value clones dominate
as algae are grazed down, so rotifers cannot recover even as algal density climbs.

**Duffy, M. A., & Sivars-Becker, L. (2007).** Rapid evolution and ecological
host–parasite dynamics. *Ecology Letters* 10, 44–53.

*Daphnia dentifera* / *Metschnikowia*. Epidemics end because hosts evolve resistance, not
only because susceptibles are depleted. With zero clonal variance the model predicts an
endemic parasite, which lakes contradict; with observed variance, epidemics terminate in
20–80 days, matching the observed 25–100 days. More diverse host populations evolve
faster, giving shorter and smaller epidemics.

## Code

- `lucasnell/gameofclones` v1.0.2 — https://doi.org/10.5281/zenodo.8429166
- `lucasnell/gameofclones-data` v1.0.4 — https://doi.org/10.5281/zenodo.10570148
- Ives et al. 2020 data and code — https://doi.org/10.6084/m9.figshare.11828865.v1
