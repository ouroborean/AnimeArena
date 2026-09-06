/**
 * TypeScript port of scripts/bounty.gd generate_from_details (lines 224-328), for the replacement
 * backend. Line-for-line equivalent to backend_port/bounty/bounty_gen.py, which is diffed against
 * an engine-captured fixture by compare.py.
 *
 * Feed it the JSON dumped by training/tests/bounty_refdata_probe.gd (reference_data.json).
 * Do NOT feed it webclient/app/bounty_data.json: that file was written with Godot's
 * JSON.stringify default sort_keys=true and its `categories` keys are ALPHABETISED, while the
 * generator indexes categories in the GDScript source's INSERTION order.
 *
 * BigInt is used for the 64-bit PCG state on purpose. Number cannot hold it, and a float-truncated
 * multiply silently produces a different stream after a handful of draws.
 */

const MASK64 = (1n << 64n) - 1n;
const MASK32 = (1n << 32n) - 1n;
const PCG_DEFAULT_INC_64 = 1442695040888963407n; // 0x14057B7EF767814F
const PCG_MULT = 6364136223846793005n;
const MASTERY_SUFFIX = "_mastery";

/**
 * Godot String::hash — DJB2 over UNICODE CODE POINTS.
 * `for (const ch of s)` iterates code points; s.charCodeAt would split an emoji into two
 * surrogates and hash it differently from the engine.
 */
export function godotHash(s: string): number {
  let h = 5381 >>> 0;
  for (const ch of s) {
    // Math.imul keeps the 32-bit multiply exact; h*33 + cp would lose precision past 2^53.
    h = (Math.imul(h, 33) + (ch.codePointAt(0) as number)) >>> 0;
  }
  return h >>> 0;
}

/** Godot 4 RandomNumberGenerator, for `.seed = X` + randi()/randi_range(). */
export class GodotRNG {
  private state = 0n;
  private inc = 0n;

  constructor(seedValue: number | bigint) {
    this.setSeed(seedValue);
  }

  setSeed(seedValue: number | bigint): void {
    const s = BigInt(seedValue) & MASK64; // negative seeds wrap into uint64, as in GDScript
    // canonical pcg32_srandom_r(rng, initstate = s, initseq = PCG_DEFAULT_INC_64)
    this.state = 0n;
    this.inc = ((PCG_DEFAULT_INC_64 << 1n) | 1n) & MASK64;
    this.step();
    this.state = (this.state + s) & MASK64;
    this.step();
  }

  private step(): number {
    const old = this.state;
    this.state = (old * PCG_MULT + this.inc) & MASK64;
    const xorshifted = (((old >> 18n) ^ old) >> 27n) & MASK32;
    const rot = (old >> 59n) & 31n;
    const out = ((xorshifted >> rot) | (xorshifted << ((-rot) & 31n))) & MASK32;
    return Number(out);
  }

  randi(): number {
    return this.step();
  }

  /**
   * RandomNumberGenerator::randi_range, via RandomPCG::random(int, int).
   *
   * *** THE DEGENERATE CASE DOES NOT DRAW. *** `from === to` returns immediately and advances the
   * stream ZERO times. bounty.gd hits that on every square for a character with exactly one
   * archetype (bountyTypes[randiRange(0, len - 1)] with len 1) and for a universe holding exactly
   * one other character. Always drawing here reproduced only 72 of 168 engine-captured cards.
   *
   * Reversed ranges (to < from) DO draw and behave as a plain swap — also verified against the
   * engine, though bounty.gd never produces one.
   */
  randiRange(from: number, to: number): number {
    if (to < from) {
      const t = from;
      from = to;
      to = t;
    }
    if (from === to) return from;
    return (this.step() % (to - from + 1)) + from;
  }
}

export interface BountyReferenceData {
  category_order: string[];
  categories: Record<string, string[]>;
  mission_types: string[];
  char_name_list: string[];
  roster: { path_name: string; universe: number }[];
  universe_enum: Record<string, number>;
}

export type Mission = [string, string[], number];

export class BountyTables {
  readonly categoryOrder: string[];
  readonly categories: Record<string, string[]>;
  readonly missionTypes: string[];
  readonly charNameList: string[];
  readonly universeOf: Map<string, number>;
  readonly allUniverses: number[];

  constructor(raw: BountyReferenceData) {
    this.categoryOrder = raw.category_order;
    this.categories = raw.categories;
    this.missionTypes = raw.mission_types;
    this.charNameList = raw.char_name_list;
    this.universeOf = new Map(raw.roster.map((r) => [r.path_name, r.universe]));
    this.allUniverses = [...new Set(Object.values(raw.universe_enum))];
  }

  getArchetypes(pathName: string): string[] {
    return this.categoryOrder.filter((k) => this.categories[k].includes(pathName));
  }

  /** CharacterDatabase.by_universe: universe ordinal -> path_names, minus excludePath. */
  byUniverse(excludePath: string): Map<number, string[]> {
    const out = new Map<number, string[]>();
    for (const u of this.allUniverses) out.set(u, []);
    for (const name of this.charNameList) {
      if (name !== excludePath) {
        out.get(this.universeOf.get(name) as number)!.push(name);
      }
    }
    return out;
  }
}

export function generateBounty(
  tables: BountyTables,
  playerName: string,
  pathName: string,
  rerolls: string | number,
  bountyType: "unlock" | "mastery" = "unlock",
): { missions: Mission[]; seedInput: string; seedHash: number } {
  const requiresBountyTarget = bountyType === "mastery";
  let seedInput = `${playerName}${pathName}${rerolls}`;
  if (requiresBountyTarget) seedInput += MASTERY_SUFFIX;
  const seedHash = godotHash(seedInput);
  const rng = new GodotRNG(seedHash);

  const cats = tables.categories;
  let bountyTypes = tables.getArchetypes(pathName);
  // A character in no category would index bountyTypes[-1] in GDScript; bounty.gd falls back to
  // every category. No roster character hits this today, but the branch must exist.
  if (bountyTypes.length === 0) bountyTypes = [...tables.categoryOrder];

  const universeDict = tables.byUniverse(pathName);
  const sameUniverse = universeDict.get(tables.universeOf.get(pathName) as number) as string[];

  const missions: Mission[] = [];
  for (let i = 0; i < 25; i++) {
    const missionType = tables.missionTypes[rng.randiRange(0, 5)];

    if (missionType === "with") {
      const specificOdds = rng.randiRange(0, 4);
      const bountyCategory = bountyTypes[rng.randiRange(0, bountyTypes.length - 1)];
      if (specificOdds === 0) {
        const members = cats[bountyCategory];
        const target = members[rng.randiRange(0, members.length - 1)];
        missions.push(target === pathName ? ["with", [bountyCategory], 6] : ["with", [target], 4]);
      } else if (specificOdds === 1 && sameUniverse.length !== 0) {
        const target = sameUniverse[rng.randiRange(0, sameUniverse.length - 1)];
        missions.push(["with", [target], 4]);
      } else {
        missions.push(["with", [bountyCategory], 6]);
      }
    } else if (missionType === "against") {
      const specificOdds = rng.randiRange(0, 8);
      const bountyCategory = bountyTypes[rng.randiRange(0, bountyTypes.length - 1)];
      if (specificOdds === 0) {
        const members = cats[bountyCategory];
        const target = members[rng.randiRange(0, members.length - 1)];
        missions.push(
          target === pathName ? ["against", [bountyCategory], 4] : ["against", [target], 3],
        );
      } else if (specificOdds === 1 && sameUniverse.length !== 0) {
        const target = sameUniverse[rng.randiRange(0, sameUniverse.length - 1)];
        missions.push(["against", [target], 3]);
      } else {
        missions.push(["against", [bountyCategory], 4]);
      }
    } else {
      let withOdds = rng.randiRange(0, 4);
      let targetOdds = rng.randiRange(0, 8);
      const withCategory = bountyTypes[rng.randiRange(0, bountyTypes.length - 1)];
      const targetCategory = bountyTypes[rng.randiRange(0, bountyTypes.length - 1)];
      const versus: string[] = [];

      if (withOdds === 0) {
        const members = cats[withCategory];
        const target = members[rng.randiRange(0, members.length - 1)];
        if (target === pathName) {
          versus.push(withCategory);
          // bounty.gd rewrites the odds here and scores win_count from it afterwards, so this
          // self-target collision counts as a specific pick (2), not a category (1).
          withOdds = 1;
        } else {
          versus.push(target);
        }
      } else if (withOdds === 1 && sameUniverse.length !== 0) {
        versus.push(sameUniverse[rng.randiRange(0, sameUniverse.length - 1)]);
      } else {
        versus.push(withCategory);
      }

      if (targetOdds === 0) {
        const members = cats[targetCategory];
        const target = members[rng.randiRange(0, members.length - 1)];
        if (target === pathName) {
          versus.push(targetCategory);
          targetOdds = 1;
        } else {
          versus.push(target);
        }
      } else if (targetOdds === 1 && sameUniverse.length !== 0) {
        versus.push(sameUniverse[rng.randiRange(0, sameUniverse.length - 1)]);
      } else {
        versus.push(targetCategory);
      }

      let winCount = withOdds ? 2 : 1;
      winCount += targetOdds ? 1 : 0;
      missions.push(["versus", versus, winCount]);
    }
  }

  return { missions, seedInput, seedHash };
}
