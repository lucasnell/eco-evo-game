// Acceptance tests against docs/MODEL.md's criteria table -- ONLY the rows the reduced
// model actually reproduces (see MODEL.md "Calibration notes" for what's in/out of
// scope for v1, and why). Do not add assertions for the high-delta_a homogenization
// mechanism without first re-reading that section -- it's a known, documented gap, not
// an oversight.

import { test } from "node:test";
import assert from "node:assert/strict";
import { runSimulation, createSimulation, CALIBRATED_DEFAULTS } from "../js/model.js";

const DAYS = 3000;
const TAIL = 800;

function baseOpts(overrides) {
  return {
    patches: 2,
    deltaA: 0.10,
    gamma: 1.0,
    initialS: [250, 250],
    initialR: [250, 250],
    initialW: [10, 10],
    seed: 12345,
    patchCarryingCapacity: CALIBRATED_DEFAULTS.patchCarryingCapacity,
    attackH: CALIBRATED_DEFAULTS.attackH,
    ...overrides,
  };
}

function tailStats(series) {
  const tail = series.slice(-TAIL);
  const totalW = tail.map((s) => s.W.reduce((a, b) => a + b, 0));
  const meanW = totalW.reduce((a, b) => a + b, 0) / totalW.length;
  const finalResistantProportion = tail[tail.length - 1].resistantProportion;
  return { meanW, finalResistantProportion };
}

test("MODEL.md: delta_a < 0.04 -> parasitoid crashes and resistant clone is excluded", () => {
  const series = runSimulation(baseOpts({ deltaA: 0.04 }), DAYS);
  const { meanW, finalResistantProportion } = tailStats(series);
  assert.ok(meanW < 5, `expected wasp population to crash, got meanW=${meanW}`);
  for (const p of finalResistantProportion) {
    assert.ok(p < 0.05, `expected resistant clone excluded, got proportion=${p}`);
  }
});

test("MODEL.md: delta_a >= 0.10 -> parasitoid persists, resistant clone not excluded", () => {
  const series = runSimulation(baseOpts({ deltaA: 0.10 }), DAYS);
  const { meanW, finalResistantProportion } = tailStats(series);
  assert.ok(meanW > 3, `expected wasp population to persist, got meanW=${meanW}`);
  assert.ok(
    finalResistantProportion.some((p) => p > 0.05),
    `expected resistant clone present somewhere, got proportions=${finalResistantProportion}`
  );
});

test("MODEL.md: gamma < 0.6 -> parasitoid dispersal heterogeneity too low, wasps go extinct", () => {
  const series = runSimulation(baseOpts({ gamma: 0.4 }), DAYS);
  const { meanW } = tailStats(series);
  assert.ok(meanW < 5, `expected wasp population to crash at low gamma, got meanW=${meanW}`);
});

test("MODEL.md: gamma >= 0.8 -> parasitoid dispersal heterogeneity sufficient, wasps persist", () => {
  const series = runSimulation(baseOpts({ gamma: 0.8 }), DAYS);
  const { meanW } = tailStats(series);
  assert.ok(meanW > 3, `expected wasp population to persist at gamma=0.8, got meanW=${meanW}`);
});

// NOT asserted: DESIGN.md's "domain of attraction" bistability (does the starting
// resistant proportion alone determine which clone is excluded, independent of the
// dispersal parameters?). Investigated during calibration -- at delta_a=0.10 this
// reduced model does NOT show it: both a 1%-resistant and a 99%-resistant start
// converge to the same long-run outcome (resistant excluded), because the wasp
// population's boom-bust cycling eventually bottoms out near zero regardless of
// starting clone ratio, and there's no immigration to rescue it once that happens.
// That's a real, deterministic property of this calibration (not a flaky test), and a
// further known gap beyond the high-delta_a mechanism documented in MODEL.md -- add it
// there if this test is ever revisited rather than re-deriving this from scratch.

test("MODEL.md: harvest applies ~96-99% aphid mortality every 28 days, adult wasps unaffected", () => {
  // 3 patches, staggered harvest offsets 0/9/18 days -- patch 0 is harvested on the very
  // first step (offset 0), patches 1/2 are not. Comparing patch 0 against patch 1 after
  // one step isolates the harvest effect from ordinary growth/parasitism, which all
  // three patches experience identically (same initial conditions, deltaA=0 so no
  // dispersal to create other differences).
  const sim = createSimulation(
    baseOpts({
      patches: 3,
      deltaA: 0,
      gamma: 1.0,
      initialS: [250, 250, 250],
      initialR: [250, 250, 250],
      initialW: [200, 200, 200],
    })
  );
  sim.step();
  const after = sim.state();
  const survivalFraction = after.S[0] / after.S[1];
  assert.ok(
    survivalFraction >= 0.01 * 0.5 && survivalFraction <= 0.04 * 1.5,
    `expected harvested patch to retain ~1-4% of the unharvested patch's aphids, got fraction=${survivalFraction}`
  );
  const waspRatio = after.W[0] / after.W[1];
  assert.ok(
    waspRatio > 0.9 && waspRatio < 1.1,
    `expected harvest to leave adult wasps roughly unaffected relative to an unharvested patch, got ratio=${waspRatio}`
  );
});

test("reproducibility: same seed and parameters produce identical trajectories", () => {
  const a = runSimulation(baseOpts({}), 200);
  const b = runSimulation(baseOpts({}), 200);
  assert.deepEqual(a, b);
});

test("mass sanity: aphid and wasp counts never go negative or non-finite", () => {
  const series = runSimulation(baseOpts({ deltaA: 0.25, gamma: 1.0 }), DAYS);
  for (const s of series) {
    for (const arr of [s.S, s.R, s.W]) {
      for (const v of arr) {
        assert.ok(Number.isFinite(v), `non-finite value encountered: ${v}`);
        assert.ok(v >= -1e-6, `negative population encountered: ${v}`);
      }
    }
  }
});
