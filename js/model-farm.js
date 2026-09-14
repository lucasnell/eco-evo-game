// Farm-manager ("hidden trap") variant of the aphid/parasitoid simulation.
//
// Why this is a SEPARATE model from js/model.js, not a shared one: the dispersal-lab
// model (js/model.js) is calibrated to show a clean BINARY signal (parasitoid
// crashes vs. persists) and does that well, but its growth mechanism -- unattacked
// aphids reproduce their entire daily growth rate in one instantaneous jump, with no
// stage structure -- produces chaotic, close-to-random boom-bust swings over many
// harvest cycles (confirmed by direct testing: patch-averaging, seed-ensembling, and
// several alternate (K, attackH) calibrations all stayed chaotic). That's fine for a
// single crash/no-crash read, but useless for THIS mode, which needs a smooth,
// legible multi-season trend (resistant frequency climbing, yield eroding) -- the
// conservation-biological-control paradox from Ives et al. 2020, "playable" per
// docs/DESIGN.md's "hidden trap" section.
//
// The fix: give aphids a maturation delay (newborns spend `maturationDays` as
// non-reproducing juveniles before joining the adult pool), the same delay-queue
// mechanism already used for wasp mummies. This is a real, literature-grounded
// simplification of pea aphid development (nymphs mature over roughly a week before
// reproducing) that the dispersal-lab model collapsed away entirely. Reintroducing it
// damps the single-generation overshoot that was driving chaos -- a well-known
// stabilizing effect of stage structure in discrete-time population models -- without
// changing any TRANSCRIBED parasitism, dispersal, or harvest mechanics.
//
// See docs/MODEL.md "Farm-manager model calibration" for the validation record: this
// variant reproduces a clean, monotonic relationship between aphid dispersal (delta_a)
// and long-run resistant proportion / aphid load, appropriate for this mode. It does
// NOT reproduce the dispersal-lab's low-delta_a parasitoid-crash threshold (wasps stay
// stable across the whole delta_a range tested here) -- that mechanism belongs to
// js/model.js, not this file. Do not use this file for the dispersal-lab page, and
// don't expect js/model.js's acceptance criteria to hold here.

export const TRANSCRIBED = Object.freeze({
  attackA: 2.32,
  attackK: 0.35,
  lambdaS: 1.26, // target parasitism-free growth rate, susceptible (Ives et al. 2020)
  lambdaR: 1.21, // target parasitism-free growth rate, resistant
  resistBenefit: 0.73,
  alateFraction: 0.20,
  waspDispM0: 0.3,
  waspDispM1Base: 0.34906,
  attractSdBase: 0.5844,
  adultWaspSurvival: 0.69,
  mummyDelayDays: 10,
  harvestIntervalDays: 28,
  harvestAphidSurvivalMin: 0.01,
  harvestAphidSurvivalMax: 0.04,
});

// NOT transcribed -- see file header and docs/MODEL.md. maturationDays/adultSurvival
// are literature-plausible (aphid nymphal development ~5-10 days) structural choices,
// not fitted values; fecundS/fecundR/densityDampingAtK are DERIVED from those choices
// plus the transcribed lambdaS/lambdaR (see calibrateFecundity below), not independent
// free parameters.
export const CALIBRATED_DEFAULTS = Object.freeze({
  patchCarryingCapacity: 500,
  attackH: 2.0,
  maturationDays: 5,
  adultSurvival: 0.95,
});

// Finds the daily per-adult fecundity `f` such that a population with maturation delay
// `Q` and adult survival `s` (no density dependence, no parasitism) asymptotically
// grows at `targetLambda`-fold per day. Bisection on the geometric growth rate measured
// over the last 50 of 400 simulated days.
export function calibrateFecundity(targetLambda, survival, maturationDays) {
  function asymptoticGrowth(fecundity) {
    let adults = 1000;
    const queue = new Array(maturationDays).fill(0);
    let a50, latest;
    for (let t = 0; t < 400; t++) {
      const births = adults * fecundity;
      const maturing = queue.shift();
      queue.push(births);
      adults = adults * survival + maturing;
      if (t === 400 - 51) a50 = adults;
      latest = adults;
    }
    return Math.pow(latest / a50, 1 / 50);
  }
  let lo = 0, hi = 1;
  for (let i = 0; i < 50; i++) {
    const mid = (lo + hi) / 2;
    if (asymptoticGrowth(mid) < targetLambda) lo = mid; else hi = mid;
  }
  return (lo + hi) / 2;
}

// Finds the density-dependence damping factor D* such that fecundity*D* (applied at
// N=K) makes the population's asymptotic growth rate exactly 1 (i.e., K is a true
// equilibrium). Used to build a Beverton-Holt-style damping(N) = 1/(1+(1/D*-1)*N/K)
// that equals 1 at N=0 (undamped) and D* at N=K.
function calibrateDampingAtK(fecundity, survival, maturationDays) {
  function asymptoticGrowth(damping) {
    let adults = 1000;
    const queue = new Array(maturationDays).fill(0);
    let a50, latest;
    for (let t = 0; t < 400; t++) {
      const births = adults * fecundity * damping;
      const maturing = queue.shift();
      queue.push(births);
      adults = adults * survival + maturing;
      if (t === 400 - 51) a50 = adults;
      latest = adults;
    }
    return Math.pow(latest / a50, 1 / 50);
  }
  let lo = 0, hi = 1;
  for (let i = 0; i < 50; i++) {
    const mid = (lo + hi) / 2;
    if (asymptoticGrowth(mid) < 1) lo = mid; else hi = mid;
  }
  return (lo + hi) / 2;
}

function makeRng(seed) {
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
  const u1 = Math.max(rng(), Number.EPSILON);
  const u2 = rng();
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
}
function uniform(rng, min, max) { return min + rng() * (max - min); }

export function createSimulation(opts) {
  const {
    patches, deltaA, gamma, initialS, initialR, initialW, seed,
    patchCarryingCapacity = CALIBRATED_DEFAULTS.patchCarryingCapacity,
    attackH = CALIBRATED_DEFAULTS.attackH,
    maturationDays = CALIBRATED_DEFAULTS.maturationDays,
    adultSurvival = CALIBRATED_DEFAULTS.adultSurvival,
  } = opts;

  const fecundS = calibrateFecundity(TRANSCRIBED.lambdaS, adultSurvival, maturationDays);
  const fecundR = calibrateFecundity(TRANSCRIBED.lambdaR, adultSurvival, maturationDays);
  const dampingAtK = calibrateDampingAtK(fecundS, adultSurvival, maturationDays);

  const rng = makeRng(seed);
  const P = patches;
  const K = patchCarryingCapacity;
  const S = initialS.slice();
  const R = initialR.slice();
  const W = initialW.slice();
  const juvS = Array.from({ length: P }, () => new Array(maturationDays).fill(0));
  const juvR = Array.from({ length: P }, () => new Array(maturationDays).fill(0));
  const mummies = Array.from({ length: P }, () => new Array(TRANSCRIBED.mummyDelayDays).fill(0));

  const sdAttract = TRANSCRIBED.attractSdBase * gamma;
  let attract = Array.from({ length: P }, () => Math.exp(-gaussian(rng) * sdAttract));
  const attractSum = attract.reduce((a, b) => a + b, 0);
  attract = attract.map((v) => v / attractSum);

  const harvestOffset = Array.from({ length: P }, (_, i) => Math.floor((i * TRANSCRIBED.harvestIntervalDays) / P));
  let day = 0;

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

  function step(liveDeltaA, liveGamma) {
    const da = liveDeltaA ?? deltaA;
    const N = S.map((s, i) => s + R[i]);

    const attackProb = N.map((n, i) => {
      const aBar = (TRANSCRIBED.attackA * W[i]) / (attackH * n + 1);
      return 1 - Math.pow(1 + aBar / TRANSCRIBED.attackK, -TRANSCRIBED.attackK);
    });
    const attackedS = S.map((s, i) => s * attackProb[i]);
    const attackedR = R.map((r, i) => r * attackProb[i]);
    const survivedAttackedR = attackedR.map((r) => r * TRANSCRIBED.resistBenefit);
    const newMummies = attackedS.map((s, i) => s + attackedR[i] * (1 - TRANSCRIBED.resistBenefit));

    const damping = N.map((n) => 1 / (1 + (1 / dampingAtK - 1) * (n / K)));
    const birthsS = S.map((s, i) => (s - attackedS[i]) * fecundS * damping[i]);
    const birthsR = R.map((r, i) => (r - attackedR[i]) * fecundR * damping[i]);

    for (let i = 0; i < P; i++) {
      const maturedS = juvS[i][0];
      const maturedR = juvR[i][0];
      for (let d = 0; d < maturationDays - 1; d++) {
        juvS[i][d] = juvS[i][d + 1];
        juvR[i][d] = juvR[i][d + 1];
      }
      juvS[i][maturationDays - 1] = birthsS[i];
      juvR[i][maturationDays - 1] = birthsR[i];
      S[i] = (S[i] - attackedS[i]) * adultSurvival + maturedS;
      R[i] = (R[i] - attackedR[i]) * adultSurvival + maturedR + survivedAttackedR[i];
    }

    const eclosed = new Array(P).fill(0);
    for (let i = 0; i < P; i++) {
      eclosed[i] = mummies[i][0];
      for (let d = 0; d < TRANSCRIBED.mummyDelayDays - 1; d++) mummies[i][d] = mummies[i][d + 1];
      mummies[i][TRANSCRIBED.mummyDelayDays - 1] = newMummies[i];
    }
    for (let i = 0; i < P; i++) W[i] = W[i] * TRANSCRIBED.adultWaspSurvival + eclosed[i];

    dispersePooled(S, da * TRANSCRIBED.alateFraction);
    dispersePooled(R, da * TRANSCRIBED.alateFraction);

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
    for (let i = 0; i < P; i++) W[i] = W[i] - emigration[i] + waspPool * attract[i];

    for (let i = 0; i < P; i++) {
      if ((((day - harvestOffset[i]) % TRANSCRIBED.harvestIntervalDays) + TRANSCRIBED.harvestIntervalDays) % TRANSCRIBED.harvestIntervalDays === 0) {
        S[i] *= uniform(rng, TRANSCRIBED.harvestAphidSurvivalMin, TRANSCRIBED.harvestAphidSurvivalMax);
        R[i] *= uniform(rng, TRANSCRIBED.harvestAphidSurvivalMin, TRANSCRIBED.harvestAphidSurvivalMax);
        mummies[i].fill(0);
      }
    }
    day += 1;
  }

  function state() {
    return {
      day,
      S: S.slice(), R: R.slice(), W: W.slice(),
      N: S.map((s, i) => s + R[i]),
      resistantProportion: S.map((s, i) => { const n = s + R[i]; return n > 0 ? R[i] / n : NaN; }),
    };
  }

  return { step, state, params: { patches: P, deltaA, gamma, patchCarryingCapacity: K, attackH, fecundS, fecundR, dampingAtK } };
}

export function runSimulation(opts, days) {
  const sim = createSimulation(opts);
  const series = [sim.state()];
  for (let d = 0; d < days; d++) {
    sim.step();
    series.push(sim.state());
  }
  return series;
}
