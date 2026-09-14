// Diagnostic tool, not a pass/fail test: sweeps δ_a and γ and classifies the resulting
// long-run regime, to calibrate js/model.js's non-transcribed constants
// (patchCarryingCapacity, attackH) against docs/MODEL.md's acceptance-criteria table.
// Run with: node test/sweep.mjs [patchCarryingCapacity] [attackH]

import { runSimulation, CALIBRATED_DEFAULTS } from "../js/model.js";

const K = Number(process.argv[2] ?? CALIBRATED_DEFAULTS.patchCarryingCapacity);
const H = Number(process.argv[3] ?? CALIBRATED_DEFAULTS.attackH);

const DAYS = 3000;
const TAIL = 800; // days at the end used to classify the regime

function classify(series, patches) {
  const tail = series.slice(-TAIL);
  const lastN = tail.map((s) => s.N);
  const lastW = tail.map((s) => s.W);
  const lastR = tail.map((s) => s.resistantProportion);

  let aphidExtinct = false;
  let waspExtinct = false;
  let resistantExcluded = false;
  let susceptibleExcluded = false;

  for (let i = 0; i < patches; i++) {
    const nVals = tail.map((s) => s.N[i]);
    const wVals = tail.map((s) => s.W[i]);
    const rProp = tail.map((s) => s.resistantProportion[i]);
    if (nVals.every((v) => v < 0.5)) aphidExtinct = true;
    if (wVals.every((v) => v < 0.5)) waspExtinct = true;
    if (rProp.every((v) => !Number.isNaN(v) && v < 0.01)) resistantExcluded = true;
    if (rProp.every((v) => !Number.isNaN(v) && v > 0.99)) susceptibleExcluded = true;
  }

  // Coefficient of variation of total N across the tail, as a crude cycle-amplitude proxy.
  const totalN = tail.map((s) => s.N.reduce((a, b) => a + b, 0));
  const mean = totalN.reduce((a, b) => a + b, 0) / totalN.length;
  const sd = Math.sqrt(totalN.reduce((a, b) => a + (b - mean) ** 2, 0) / totalN.length);
  const cv = mean > 0 ? sd / mean : NaN;

  let label = "persistent-stable";
  if (aphidExtinct) label = "aphid-extinct";
  else if (waspExtinct) label = "wasp-extinct";
  else if (resistantExcluded) label = "resistant-excluded";
  else if (susceptibleExcluded) label = "susceptible-excluded";
  else if (cv > 0.15) label = "cycling";

  return { label, cv: Number.isFinite(cv) ? cv.toFixed(3) : "NaN" };
}

function run(deltaA, gamma, patches = 2) {
  const half = 250;
  const opts = {
    patches,
    deltaA,
    gamma,
    initialS: new Array(patches).fill(half),
    initialR: new Array(patches).fill(half),
    initialW: new Array(patches).fill(10),
    seed: 12345,
    patchCarryingCapacity: K,
    attackH: H,
  };
  const series = runSimulation(opts, DAYS);
  return classify(series, patches);
}

console.log(`K=${K} attackH=${H}`);
console.log("\n-- delta_a sweep (gamma = 1) --");
for (const deltaA of [0.02, 0.04, 0.06, 0.10, 0.15, 0.20, 0.258, 0.3, 0.4]) {
  const { label, cv } = run(deltaA, 1.0);
  console.log(`deltaA=${deltaA.toFixed(3)}  gamma=1.0  -> ${label} (cv=${cv})`);
}

console.log("\n-- gamma sweep (delta_a = 0.10) --");
for (const gamma of [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.5]) {
  const { label, cv } = run(0.10, gamma);
  console.log(`deltaA=0.10  gamma=${gamma.toFixed(2)}  -> ${label} (cv=${cv})`);
}
