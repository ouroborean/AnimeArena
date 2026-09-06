# Anime Arena — Implementation Debt / Broken Kits

Classification of non-functional, bugged, and stale-metadata characters from the Phase 1 roster analysis.
Group 1 is **verified directly against the code**; Groups 2–4 are profiling-agent reports (confirm in Phase 2).

## Group 1 — FULLY NON-FUNCTIONAL (verified) — nothing to balance
### 1a. Source files missing entirely (0 ability `.gd` on disk, no char def — metadata only)
ash, atomeve, gaia_, squirtle, pikachu, invincible, omniman, river_daughter_, pyrrha  *(9)*

### 1b. All abilities are empty template stubs (`#Put execution per target here` + `pass`, 0 implemented)
guts (0/5), snowwhite (0/4), ruler (0/4), pucelle / La Pucelle (0/4), urahara (0/5)  *(5)*

**→ 14 characters that literally do nothing in the live build. Strong exclude-from-balance candidates (engineering backlog instead).**

## Group 2 — IMPLEMENTED — ALL KEPT IN the Phase 2 balance pass
DECISION: Group 1 (14) omitted; **all Group 2 characters are included.** Profiling agents only read the
*ability* `.gd` files, so mechanics that resolve in `character_component.gd` / `ability_component.gd`
(damage pipeline, effect flags like `health_drain`, mark/boost handling) were invisible — several
"bugs" below are likely FALSE POSITIVES. Phase 2 agents MUST read the component scripts before flagging.

### 2a. Verified real bug (specific, fixable) — but character is otherwise functional
- **uraraka** — functional energy-denial/attrition controller (uraraka1/2/3 all work; Comet Shower's 0
  damage is BY DESIGN, a mark-spreader). REAL BUG: `uraraka4` (Float) builds the 20 Shield + the
  HARMFUL_RECEIVE float-counter but **never calls `Character.add_allied_effect`** on either → the whole
  defensive skill does nothing. 2-line fix. (Agent's "Comet Shower 0 dmg = bug" was wrong.)

### 2b. Likely FALSE POSITIVE — mechanic resolves in a component, re-verify in Phase 2 (per user)
- **myotismon** — `health_drain` lifesteal is handled in the damage pipeline (character_component), not the skill.
- **nobara** / **uranus** — the "missing" rider (−10 heal debuff / +5 amp) may apply via a component hook.
- **ban** / **esdeath** — boost "double-count" goes through `get_true_damage` (ability_component); confirm it's actually a bug vs intended per-stack math.
- **rakko** — Bleed→Shatter observer may be wired through a component trigger, not rakko5.

### 2c. Still worth a Phase-2 code check (agent-reported, not yet component-verified)
- **ladydevimon** — "Nullify" barrier applied to the ENEMY in ladydevimon3 (likely bug).
- **alphamon** — advertised mitigation-proportional damage ramp (`pre_damage` declared, unused → flat 30?).
- **diane** — damage typed NORMAL (gets mitigated); Queen's Embrace grants DR to enemies too.
- **gohan** — "living-Goku +15" rider likely unintended.

## Group 3 — MINOR / flavor-only bug (kit works fine; would NOT exclude)
aang (flavor "Avatar State" never delivered), allmight (death-passive is an intentional no-op placeholder),
genos (Rocket Boosters upgrade unimplemented), natsu (Consume Flame swap unimpl + stale numbers),
asta (dead taunt line), touka (dead +5 boost var), zenitsu (0-damage thorns), kid (AI-hint no-op, doesn't
affect play), todoroki (Fire Wall 0 dmg early), king (possible first-tick double-count), midoriya (HP-drain
compounding edge), sayaka (heal value mismatch), noelle (roar consumes cradle edge), meliodas (data drift).

## Group 4 — STALE METADATA ONLY — NOT broken (kit works; JSON/.gd numbers drift)
**Do not exclude — these function correctly; they just need a JSON/description fix.**
ace, emiyaarcher, hashirama, ichigo, jaden, ken, maka, mami, misaka, muichiro, rimuru, sasuke, sheele,
tamaki, tsuyu (Froppy), yubel, yuji, zoro, gon
