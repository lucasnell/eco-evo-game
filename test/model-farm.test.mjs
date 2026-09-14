// Validation for js/model-farm.js -- the farm-manager ("hidden trap") model variant.
// See that file's header comment and docs/MODEL.md's "Farm-manager model calibration"
// for why this is a separate model from js/model.js and what it's actually validated
// against: a smooth, monotonic delta_a -> resistant-proportion -> aphid-load
// relationship, NOT the dispersal-lab's crash/persist threshold.

import { test } from "node:test";
import assert from "node:assert/strict";
import { runSimulation, CALIBRATED_DEFAULTS } from "../js/model-farm.js";

const CYCLES = 20;
const DAYS = CYCLES * 28;

function baseOpts(overrides) {
  return {
    patches: 2,
    deltaA: 0.10,
    gamma: 1.0,
    initialS: [225, 225],
    initialR: [25, 25],
    initialW: [10, 10],
    seed: 555,
    ...overrides,
  };
}

function totals(state) {
  const N = state.N.reduce((a, b) => a + b, 0);
  const R = state.R.reduce((a, b) => a + b, 0);
  const W = state.W.reduce((a, b) => a + b, 0);
  return { N, R, W, Rprop: N > 0 ? R / N : NaN };
}

test("reproducibility: same seed and parameters produce identical trajectories", () => {
  const a = runSimulation(baseOpts({}), 200);
  const b = runSimulation(baseOpts({}), 200);
  assert.deepEqual(a, b);
});

test("mass sanity: no negative or non-finite populations over a long run", () => {
  const series = runSimulation(baseOpts({ deltaA: 0.9 }), DAYS);
  for (const s of series) {
    for (const arr of [s.S, s.R, s.W]) {
      for (const v of arr) {
        assert.ok(Number.isFinite(v), `non-finite value: ${v}`);
        assert.ok(v >= -1e-6, `negative population: ${v}`);
      }
    }
  }
});

// deltaA range matches hidden-trap.html's MIN_DELTA_A/MAX_DELTA_A (0-100% investment
// slider). Widened from an initial 0.02-0.35 to 0-0.9 during playtesting: the
// direction was already correctly signed at the narrower range, but the effect size
// (final yield gap between 0% and 100% investment) was only 1-2 percentage points --
// too subtle to read as a game. 0-0.9 keeps the same monotonic, non-chaotic behavior
// (checked cycle-by-cycle, not just at the endpoint) while roughly doubling the gap.

test("the hidden trap: higher sustained aphid dispersal (more habitat connectivity investment) produces a higher long-run resistant proportion, across multiple seeds", () => {
  for (const seed of [1, 2, 3, 4, 5]) {
    const low = totals(runSimulation(baseOpts({ deltaA: 0.0, seed }), DAYS).at(-1));
    const high = totals(runSimulation(baseOpts({ deltaA: 0.9, seed }), DAYS).at(-1));
    assert.ok(
      high.Rprop > low.Rprop,
      `seed=${seed}: expected higher deltaA to produce higher resistant proportion, got low=${low.Rprop} high=${high.Rprop}`
    );
  }
});

test("the hidden trap: higher investment produces MORE aphids (worse yield) by season's end, not fewer", () => {
  for (const seed of [1, 2, 3, 4, 5]) {
    const low = totals(runSimulation(baseOpts({ deltaA: 0.0, seed }), DAYS).at(-1));
    const high = totals(runSimulation(baseOpts({ deltaA: 0.9, seed }), DAYS).at(-1));
    assert.ok(
      high.N > low.N,
      `seed=${seed}: expected higher deltaA to produce a higher aphid load by season's end, got low=${low.N} high=${high.N}`
    );
  }
});

test("the trap is hidden: wasp numbers stay comparable between low and high investment even as control erodes", () => {
  const low = totals(runSimulation(baseOpts({ deltaA: 0.0 }), DAYS).at(-1));
  const high = totals(runSimulation(baseOpts({ deltaA: 0.9 }), DAYS).at(-1));
  const ratio = high.W / low.W;
  assert.ok(
    ratio > 0.8 && ratio < 1.3,
    `expected wasp abundance to look similar despite the yield difference (that's the paradox), got ratio=${ratio}`
  );
});

test("initial control then erosion: aphid load drops sharply in the first few cycles, then climbs back as resistance rises", () => {
  const series = runSimulation(baseOpts({ deltaA: 0.9 }), DAYS);
  const early = totals(series[2 * 28]).N; // cycle 2
  const dip = totals(series[4 * 28]).N; // cycle 4
  const late = totals(series[CYCLES * 28]).N; // cycle 20
  assert.ok(dip < early, `expected an initial control dip, got early=${early} dip=${dip}`);
  assert.ok(late > dip, `expected aphid load to climb back as resistance rises, got dip=${dip} late=${late}`);
});
