// Reduced eco-evolutionary dynamics simulation: pea aphid (susceptible / resistant
// clones) and Aphidius ervi parasitoid, across a small number of patches.
//
// Parameters and mechanisms are transcribed from lucasnell/gameofclones (R/simulate.R,
// src/wasps.hpp) and the analysis scripts in lucasnell/gameofclones-data that produced
// Nell et al. 2024 (Science) Fig. 3, per the citations in ../docs/MODEL.md. Anything
// NOT transcribed (patch carrying capacity K, and the absolute population scale it sets
// the parasitism functional response's `h` against) is called out below and in
// docs/MODEL.md's "Calibration notes" — the 28-field source doesn't map its units onto
// a 2-3 patch reduction, so that scale is tuned numerically instead of copied.
//
// No dependencies. No build step. Runs under Node (headless tests) or a browser
// <script type="module"> (eventual UI).

// --- Transcribed constants (do not change without re-checking docs/MODEL.md) -------

export const TRANSCRIBED = Object.freeze({
  // Parasitism functional response (src/wasps.hpp) — May (1978) negative-binomial
  // aggregation on top of a Holling type II mean.
  attackA: 2.32,
  attackK: 0.35,

  // Resistance trade-off (Ives et al. 2020, fitted).
  lambdaS: 1.26, // susceptible daily growth factor, parasitism-independent
  lambdaR: 1.21, // resistant daily growth factor, parasitism-independent
  resistBenefit: 0.73, // probability a resistant aphid survives being attacked

  // Dispersal mechanics (R/simulate.R + gameofclones-data/04-paras-disp-hetero.R).
  alateFraction: 0.20, // fraction of aphids that are winged/dispersal-capable
  waspDispM0: 0.3,
  waspDispM1Base: 0.34906, // multiplied by γ
  attractSdBase: 0.5844, // multiplied by γ, shapes patch-attractiveness draw

  // Wasp life history.
  adultWaspSurvival: 0.69, // s_y, daily
  mummyDelayDays: 10, // 7 days living-parasitized + 3 days mummy

  // Harvest (gameofclones-data/04-paras-disp-hetero.R).
  harvestIntervalDays: 28,
  harvestAphidSurvivalMin: 0.01,
  harvestAphidSurvivalMax: 0.04,
});

// --- Calibrated constants (NOT transcribed — see docs/MODEL.md "Calibration notes") -

// Found by parameter sweep (test/sweep.mjs) against docs/MODEL.md's acceptance
// criteria. These values reproduce the low-delta_a "parasitoid crash -> resistant
// excluded" mechanism and the gamma<0.6 extinction threshold cleanly. They do NOT
// reproduce the high-delta_a "homogenization -> instability" mechanism (see
// docs/MODEL.md "Calibration notes" -- an open limitation, not silently dropped).
export const CALIBRATED_DEFAULTS = Object.freeze({
  patchCarryingCapacity: 500, // K, aphids per patch
  attackH: 2.0, // handling-time-like constant in the functional response
});

// --- RNG (seedable, so trait/harvest draws are reproducible) -----------------------

// Small deterministic PRNG (mulberry32) — good enough for reproducible simulation
// draws; not cryptographic, not the pcg32 gameofclones itself uses.
export function makeRng(seed) {
  let a = seed >>> 0;
  return function rng() {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function gaussian(rng) {
  // Box-Muller.
  const u1 = Math.max(rng(), Number.EPSILON);
  const u2 = rng();
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
}

function uniform(rng, min, max) {
  return min + rng() * (max - min);
}

// --- Simulation ----------------------------------------------------------------------

/**
 * @param {object} opts
 * @param {number} opts.patches - number of patches (2 or 3 for the reduced model)
 * @param {number} opts.deltaA - aphid dispersal probability (δ_a)
 * @param {number} opts.gamma - parasitoid dispersal heterogeneity (γ)
 * @param {number[]} opts.initialS - initial susceptible count per patch
 * @param {number[]} opts.initialR - initial resistant count per patch
 * @param {number[]} opts.initialW - initial adult wasp count per patch
 * @param {number} opts.seed - RNG seed
 * @param {number} [opts.patchCarryingCapacity]
 * @param {number} [opts.attackH]
 */
export function createSimulation(opts) {
  const {
    patches,
    deltaA,
    gamma,
    initialS,
    initialR,
    initialW,
    seed,
    patchCarryingCapacity = CALIBRATED_DEFAULTS.patchCarryingCapacity,
    attackH = CALIBRATED_DEFAULTS.attackH,
  } = opts;

  if (initialS.length !== patches || initialR.length !== patches || initialW.length !== patches) {
    throw new Error("initialS/initialR/initialW must each have length `patches`");
  }

  const rng = makeRng(seed);
  const P = patches;
  const K = patchCarryingCapacity;

  const S = initialS.slice();
  const R = initialR.slice();
  const W = initialW.slice();
  const mummies = Array.from({ length: P }, () => new Array(TRANSCRIBED.mummyDelayDays).fill(0));

  // Fixed per-patch wasp attractiveness, drawn once (transcribed mechanism).
  const sdAttract = TRANSCRIBED.attractSdBase * gamma;
  let attract = Array.from({ length: P }, () => Math.exp(-gaussian(rng) * sdAttract));
  const attractSum = attract.reduce((a, b) => a + b, 0);
  attract = attract.map((v) => v / attractSum);

  // Stagger harvest across patches, one field/day equivalent.
  const harvestOffset = Array.from({ length: P }, (_, i) =>
    Math.floor((i * TRANSCRIBED.harvestIntervalDays) / P)
  );

  let day = 0;

  function step() {
    const N = S.map((s, i) => s + R[i]);

    // 1-2. Parasitism: negative-binomial aggregated attack probability.
    const attackProb = N.map((n, i) => {
      const aBar = (TRANSCRIBED.attackA * W[i]) / (attackH * n + 1);
      return 1 - Math.pow(1 + aBar / TRANSCRIBED.attackK, -TRANSCRIBED.attackK);
    });

    const attackedS = S.map((s, i) => s * attackProb[i]);
    const attackedR = R.map((r, i) => r * attackProb[i]);

    // 3-4. Post-attack survival, and new mummies from attacks that kill the host.
    const survivedAttackedR = attackedR.map((r) => r * TRANSCRIBED.resistBenefit);
    const newMummies = attackedS.map((s, i) => s + attackedR[i] * (1 - TRANSCRIBED.resistBenefit));

    // 5. Density-dependent reproduction of unattacked individuals. Beverton-Holt form,
    // normalized so a susceptible-only, parasitism-free population equilibrates
    // exactly at K (X' = lambdaS*X / (1 + (lambdaS-1)*X/K) has fixed point X=K) --
    // NOT transcribed (K and this functional form are the reduced model's own choice,
    // see docs/MODEL.md "Calibration notes"), but standard discrete-time density
    // dependence, chosen so lambdaS/lambdaR keep their transcribed meaning as the
    // parasitism-free growth rate at low density.
    for (let i = 0; i < P; i++) {
      const unattackedS = S[i] - attackedS[i];
      const unattackedR = R[i] - attackedR[i];
      const densityTerm = 1 + (TRANSCRIBED.lambdaS - 1) * (N[i] / K);
      S[i] = (unattackedS * TRANSCRIBED.lambdaS) / densityTerm;
      R[i] = (unattackedR * TRANSCRIBED.lambdaR) / densityTerm + survivedAttackedR[i];
    }

    // 6. Mummy queue: shift, eclose slot 0, push new mummies to the back.
    const eclosed = new Array(P).fill(0);
    for (let i = 0; i < P; i++) {
      eclosed[i] = mummies[i][0];
      for (let d = 0; d < TRANSCRIBED.mummyDelayDays - 1; d++) {
        mummies[i][d] = mummies[i][d + 1];
      }
      mummies[i][TRANSCRIBED.mummyDelayDays - 1] = newMummies[i];
    }
    for (let i = 0; i < P; i++) {
      W[i] = W[i] * TRANSCRIBED.adultWaspSurvival + eclosed[i];
    }

    // 7. Aphid dispersal: pool alate fraction, redistribute evenly.
    dispersePooled(S, deltaA * TRANSCRIBED.alateFraction);
    dispersePooled(R, deltaA * TRANSCRIBED.alateFraction);

    // 8. Wasp dispersal: density-dependent emigration, redistribute by attractiveness.
    const m1 = TRANSCRIBED.waspDispM1Base * gamma;
    const Npost = S.map((s, i) => s + R[i]);
    let waspPool = 0;
    const emigration = new Array(P).fill(0);
    for (let i = 0; i < P; i++) {
      const z = Math.max(Npost[i], 1);
      const rate = TRANSCRIBED.waspDispM0 * Math.exp(-m1 * Math.log(z));
      emigration[i] = Math.min(W[i], W[i] * Math.min(rate, 1));
      waspPool += emigration[i];
    }
    for (let i = 0; i < P; i++) {
      W[i] = W[i] - emigration[i] + waspPool * attract[i];
    }

    // 9. Harvest, staggered.
    for (let i = 0; i < P; i++) {
      if (((day - harvestOffset[i]) % TRANSCRIBED.harvestIntervalDays + TRANSCRIBED.harvestIntervalDays) % TRANSCRIBED.harvestIntervalDays === 0) {
        S[i] *= uniform(rng, TRANSCRIBED.harvestAphidSurvivalMin, TRANSCRIBED.harvestAphidSurvivalMax);
        R[i] *= uniform(rng, TRANSCRIBED.harvestAphidSurvivalMin, TRANSCRIBED.harvestAphidSurvivalMax);
        mummies[i].fill(0);
      }
    }

    day += 1;
  }

  function dispersePooled(arr, rate) {
    let pool = 0;
    for (let i = 0; i < P; i++) {
      const leaving = arr[i] * rate;
      arr[i] -= leaving;
      pool += leaving;
    }
    const share = pool / P;
    for (let i = 0; i < P; i++) arr[i] += share;
  }

  function state() {
    return {
      day,
      S: S.slice(),
      R: R.slice(),
      W: W.slice(),
      N: S.map((s, i) => s + R[i]),
      resistantProportion: S.map((s, i) => {
        const n = s + R[i];
        return n > 0 ? R[i] / n : NaN;
      }),
    };
  }

  return { step, state, params: { patches: P, deltaA, gamma, patchCarryingCapacity: K, attackH } };
}

/** Run `days` steps and return the full time series (one entry per day, post-step). */
export function runSimulation(opts, days) {
  const sim = createSimulation(opts);
  const series = [sim.state()];
  for (let d = 0; d < days; d++) {
    sim.step();
    series.push(sim.state());
  }
  return series;
}
