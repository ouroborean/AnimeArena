/**
 * Diff the TypeScript generator against the same engine-captured fixtures the Python one uses.
 * Exact equality only. This is the version the replacement backend will actually ship, so it gets
 * the same proof, not a "should be equivalent" hand-wave.
 *
 *   node compare.ts        (Node >= 23 strips the types natively; no build step)
 */

import { readFileSync, readdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  BountyTables,
  GodotRNG,
  generateBounty,
  godotHash,
  type BountyReferenceData,
  type Mission,
} from "./bountyGen.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const load = (name: string) => JSON.parse(readFileSync(join(HERE, name), "utf-8"));
const eq = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b);

let failures = 0;

// --- primitives -------------------------------------------------------------------------------
{
  const fxText = readFileSync(join(HERE, "primitives_fixture.json"), "utf-8");
  const fx = JSON.parse(fxText);
  // JSON.parse turns the int64-extreme seeds into imprecise Numbers (2^63-1 becomes
  // 9223372036854776000). Recover the exact literals from the source text so the RNG is fed the
  // value the engine was fed. Real bounty seeds are uint32 hashes, so this only matters for the
  // extreme-value rows — but it is exactly the trap a TS backend would fall into if a seed ever
  // came off the wire as JSON.
  const seedLiterals = [...fxText.matchAll(/"seed_in":\s*(-?\d+)/g)].map((m) => BigInt(m[1]));
  fx.rng.forEach((row: any, i: number) => { row.seed_in = seedLiterals[i]; });
  let bad = 0;
  for (const row of fx.hashes) {
    if (godotHash(row.s) !== row.global_hash) {
      bad++;
      console.log(`  FAIL hash ${JSON.stringify(row.s)} got=${godotHash(row.s)} exp=${row.global_hash}`);
    }
  }
  for (const row of fx.rng) {
    let rng = new GodotRNG(row.seed_in);
    const raw = row.randi.map(() => rng.randi());
    if (!eq(raw, row.randi)) {
      bad++;
      console.log(`  FAIL randi seed=${row.seed_in}\n    got ${raw}\n    exp ${row.randi}`);
    }
    rng = new GodotRNG(row.seed_in);
    const rr: number[] = [];
    for (let i = 0; i < 8; i++) rr.push(rng.randiRange(0, 5));
    for (let i = 0; i < 4; i++) rr.push(rng.randiRange(0, 8));
    for (let i = 0; i < 4; i++) rr.push(rng.randiRange(0, 38));
    if (!eq(rr, row.randi_range)) {
      bad++;
      console.log(`  FAIL randi_range seed=${row.seed_in}\n    got ${rr}\n    exp ${row.randi_range}`);
    }
    rng = new GodotRNG(row.seed_in);
    const deg = [
      rng.randiRange(0, 5), rng.randiRange(0, 0), rng.randiRange(0, 5),
      rng.randiRange(7, 7), rng.randiRange(0, 5), rng.randiRange(5, 0),
      rng.randiRange(0, 5), rng.randiRange(-3, 3), rng.randiRange(0, 5),
    ];
    if (!eq(deg, row.degenerate_mix)) {
      bad++;
      console.log(`  FAIL degenerate_mix seed=${row.seed_in}\n    got ${deg}\n    exp ${row.degenerate_mix}`);
    }
  }
  console.log(`primitives: ${fx.hashes.length} hash cases + ${fx.rng.length} rng seeds, ${bad} failures`);
  failures += bad;
}

// --- generation -------------------------------------------------------------------------------
const raw = load("reference_data.json") as BountyReferenceData;
const tables = new BountyTables(raw);

function runCases(fixtureName: string, label: string, extraUniverses?: Record<string, number>) {
  if (!existsSync(join(HERE, fixtureName))) {
    console.log(`${label}: no fixture, skipped`);
    return;
  }
  const fx = load(fixtureName);
  if (extraUniverses) {
    for (const [name, u] of Object.entries(fx[extraUniverses as unknown as string] ?? {})) void u;
  }
  for (const [name, u] of Object.entries((fx.off_roster_universes ?? {}) as Record<string, number>)) {
    if (!tables.universeOf.has(name)) tables.universeOf.set(name, u);
  }
  let bad = 0;
  for (const c of fx.cases) {
    const { missions, seedInput, seedHash } = generateBounty(
      tables, c.player, c.path, c.rerolls, c.type);
    if (seedInput !== c.seed_input || seedHash !== c.seed_hash || !eq(missions, c.missions)) {
      bad++;
      console.log(`  FAIL ${label} ${JSON.stringify(c.player)}/${c.path}/rr=${c.rerolls}/${c.type}`);
      (missions as Mission[]).forEach((m, i) => {
        if (!eq(m, c.missions[i])) {
          console.log(`      square ${i}  got ${JSON.stringify(m)}  exp ${JSON.stringify(c.missions[i])}`);
        }
      });
    }
  }
  console.log(`${label}: ${fx.cases.length} cases, ${bad} failures`);
  failures += bad;
}

runCases("generation_fixture.json", "generation");
runCases("roster_fixture.json", "roster");   // every roster character
runCases("fallback_fixture.json", "fallback");

// --- live in-flight save data (read-only) ------------------------------------------------------
{
  const ausers = join(HERE, "..", "..", "ausers");
  if (!existsSync(ausers)) {
    console.log("live: no ausers/ directory, skipped");
  } else {
    let cards = 0, checked = 0, bad = 0;
    for (const fname of readdirSync(ausers).sort()) {
      if (!fname.endsWith(".dat")) continue;
      let acct: any;
      try {
        acct = JSON.parse(readFileSync(join(ausers, fname), "utf-8"));
      } catch {
        continue;
      }
      const active = acct.active_bounties;
      if (!active || typeof active !== "object") continue;
      const rerolls = acct.bounty_rerolls ?? {};
      for (const [key, progress] of Object.entries(active as Record<string, number[]>)) {
        const mastery = key.endsWith("_mastery");
        const rawPath = mastery ? key.slice(0, -"_mastery".length) : key;
        const rr = typeof rerolls === "object" && rerolls && key in rerolls
          ? Math.trunc(Number((rerolls as any)[key])) : 0;
        const { missions } = generateBounty(
          tables, acct.username, rawPath, String(rr), mastery ? "mastery" : "unlock");
        cards++;
        progress.forEach((got, i) => {
          checked++;
          if (got > missions[i][2]) {
            bad++;
            console.log(`  FAIL ${acct.username}/${key} square ${i}: ${got} > ${missions[i][2]}`);
          }
        });
      }
    }
    console.log(`live: ${cards} real cards, ${checked} square constraints, ${bad} violations`);
    failures += bad;
  }
}

console.log(`\nTOTAL FAILURES: ${failures}`);
process.exit(failures ? 1 : 0);
