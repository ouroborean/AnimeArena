---
tags: [area/playbook, type/reference]
---

# Roulette 11 - Nonon Jakuzure

**Draw:** `draw 112/174 -> nonon`       **Universe:** Kill la Kill   **Gate:** `nonon_unlock` (gated, playable)
**Verdict (as drawn):** Buildable with fidelity loss (3/5 exact, 2 near-misses)
**Verdict (after this run built 2 systems):** **Fully buildable — exact behavioral fidelity on all 5 skills**

Third run under the "build the missing system in-run" rule, and the first to surface **two** gaps in one
draw — both closed. Nonon is a mark-synergy piercing/control kit: two marks (Overture Barrage, Concentrated
Climax) drive bypass, auto-targeting and a finisher, wrapped in a swap chain and a control-channel. The two
near-misses were a **damage-type-filtered vulnerability** (a five-line reuse of last run's `damage_boost`
filter) and a genuinely new targeting capability — **per-candidate conditional invuln-bypass**. Closing the
second also flushed out a **latent red probe** the adversarial pass caught (a stale hostility oracle left by
Roulette 10). The full kit was then authored as block JSON and proven through the real
`AuthoredRegistry.validate_character` (0 errors) and a headless battle (`creator_nonon_spec_probe`: 35/0).

## The kit
Five abilities (`nonon5` is a swap-in reachable only via nonon3). Names from `ability_info.json`; behaviour
from the scripts.

- **Flute Missile** (`nonon1`, cd1, 1 Random): 10 Piercing to one enemy + **+5 non-Affliction vulnerability** for 2 turns.
- **Overture Barrage** (`nonon2`, cd2, 1 Blue): 5 Piercing to all enemies + a 5-Piercing DoT (3 turns) + the "Overture Barrage" mark + self-swap to Concentrated Climax.
- **Concentrated Climax** (`nonon3`, cd1, 1 Blue, Control): 10 + a 10 DoT (3 turns) + the "Concentrated Climax" mark — **all bypassing iff the target is marked by Overture Barrage** — self-swap to Unstoppable Performance, bundled in a control-channel.
- **Sound Negation** (`nonon4`, cd4, 1 Random): self-Invulnerable 1 turn.
- **Unstoppable Performance** (`nonon5`, cd0, 1 Blue): 10 Piercing to the main target + 10 to every Overture-marked enemy + 10 to every Concentrated-Climax-marked enemy.

## Mechanic audit
| Skill | Mechanic | Verdict | Notes / blocks |
| --- | --- | --- | --- |
| nonon1 | 10 Piercing | **Buildable** | `damage {amount:10, damage_type:"PIERCING"}` |
| nonon1 | **+5 non-Affliction vulnerability** | **Approximable → BUILT** | vulnerability kind had no type filter → added include/exclude types |
| nonon2 | AoE 5 Piercing + AoE DoT + AoE mark + self-swap | **Buildable** | `damage` all_enemies, `damage_over_time ticks:5`, `mark`, `swap` |
| nonon3 | 10 + DoT + mark under a **control channel** | **Buildable** | ability-level `channel:"control"` plants the control_cancel over everything applied |
| nonon3 | conditional bypass — **apply** half | **Buildable** | `group {when:has_effect("Overture Barrage"), blocks:[…bypassing], else:[…]}` |
| nonon3 | conditional bypass — **target** half | **Approximable → BUILT** | Layer-1 computed bypass once for the whole ability → added per-candidate `bypass_when` |
| nonon3 | swap into a hidden skill (nonon5) | **Buildable** | `swap {into:<hidden slot>}` names hidden moveset slots by design |
| nonon4 | self-Invulnerable 1 turn | **Buildable** | `apply {to:"user", effect:{kind:"invulnerable", turns:1}}` |
| nonon5 | main + two mark-pools, 10 Piercing each | **Buildable** | `damage main_target` + `damage any_enemy when has_effect("Overture Barrage")` + same for "Concentrated Climax" |

**Adversarial checks that passed:** the marks auto-name to their ability names (`effect_name()` fallback), so
nonon3/nonon5's cross-ability `has_effect("Overture Barrage")` references resolve, and a mark (MARK) + DoT
(DAMAGE) sharing a name don't collide (dedup keys on name+type+user); the channel plants the `control_cancel`
over the full accumulator exactly like the shipped `cancels` list; nonon5's filtered pools hit exactly the
marked enemies. **No third gap.**

## Gap 1 — damage-type-filtered vulnerability (BUILT)
The shipped nonon1 calls `vulnerability_effect(5, 4, [], [], [AFFLICTION])` — +5 to all NON-Affliction
damage. The factory already carries the two damage-type lists (`class_targets` include, `exclusion_targets`
exclude); the block `vulnerability` kind exposed only `[amount, turns]`, so an authored nonon1 amplified
*all* types including Affliction and the card lied. Fixed by adding `include_types`/`exclude_types` to the
kind, **reusing** the `damage_boost` machinery shipped last run (`_damage_type_list`,
`_validate_damage_type_list`, the type-phrase prose, the `creatorDamageTypeList` editor picker — which is
data-driven off the schema, so **no `app.js` change was needed**). Unlike `damage_boost`, vulnerability is
always hostile and always positive, so **no sign axis** — only the filter. **Reach 5/174** (ganta, gunha,
korra, kurotsuchi, nonon). Probe `creator_nonon_vuln_filter_probe` 25/0, hand-reversed.

## Gap 2 — per-candidate conditional invuln-bypass targeting (`bypass_when`, BUILT)
The shipped nonon3 overrides `target()` to bypass invulnerability **per candidate**: an enemy marked by
Overture Barrage is targetable *through* invuln, an unmarked invuln enemy is not. Creator Layer-1 computed
its bypass **once for the whole ability** (`var bypassing := class_bypassing or target_pierce`), so
`bypass_invuln` was all-or-nothing and no condition could gate targeting on invuln state — the *execute* half
(apply bypassing iff marked) was already buildable via group-branching, but the *targeting* reach was not.

Fixed with **`bypass_when`**, a condition on the Layer-1 target object evaluated **per candidate** (through
the *same* `check_condition_public` the `only` predicates use), so `cand_bypass := class_bypassing or
target_pierce or bypass_when.holds(candidate)`. nonon3's target now carries
`bypass_when {has_effect "Overture Barrage", MARK, mine}` and reaches a marked-invuln enemy while refusing an
unmarked one — byte-faithful.

- **Family (bar 1):** any condition × the bypass flag, per candidate.
- **Reach (bar 2):** **8/174** compute a per-candidate conditional bypass in `target()` — crona, ganta, gasai, maka, minene, nonon, omnimon, tamaki.
- **Safety (bar 4):** only conditionally *expands* reach exactly as the existing all-or-nothing pierce does; the sole guard is that `bypass_when` be a valid eligibility condition (it earns the no-`chance` / no-relative-selector rules `only` has, since `target()` re-runs).
- **No-op (bar):** absent `bypass_when` is byte-identical — the per-candidate value collapses to the old single one, flag order and pick measure untouched (targeting is where past bugs lived — verified).
- **Engine cost (bar 7):** none; scripted_ability + validator + prose + editor. Probe `creator_bypass_when_probe` 16/0, hand-reversed (drop the wiring → the marked-invuln enemy goes untargetable).

## The adversarial pass earned its keep again
The `bypass_when` judge isolated a **second red probe** unrelated to its own work: `creator_hardening_a2a4`'s
independent hostility oracle still returned `amount > 0` for `damage_boost` — a stale copy of the pre-Roulette-10
assumption. Roulette 10 fixed the code (`damage_boost` is hostile-when-negative) and *one* oracle
(`creator_phase_a_verify`) but missed this second one, and that run's sweep hadn't included it. Corrected the
a2a4 oracle to the same `damage_boost → amount < 0` rule; both independent oracles now agree with the code, and
a grep confirmed there is no third.

## The create-ability proof
Full kit authored as block JSON (id `auth_zz_nonon_roulette`), passed the real `validate_character` (0 errors,
direct + save/load), built an `AuthoredCharacter`, every mechanic fired in a headless battle — including
nonon1's Affliction-sparing vulnerability, nonon3's channel + mark-gated bypass (targets a marked-invuln enemy,
refuses an unmarked one), and nonon5's two mark-pools. `creator_nonon_spec_probe`: **35/0**. Compile clean;
`deploy/app.js` byte-identical; `self_check` green; whole creator suite green apart from the one known
`semantic_feature` failure.

## Verdict for the roadmap
Both systems shipped this run. `bypass_when` is the more consequential: it is the first **conditional
targeting-reach** primitive, and it composes with any condition, so "bypass invuln only against enemies in
state X" is now a general capability. The vulnerability filter completes the damage-type-filter family the
`damage_boost` work opened. With both, Nonon is fully buildable at exact behavioral fidelity.
