---
tags: [area/playbook, type/reference]
---

# Roulette 10 - LadyDevimon

**Draw:** `draw 78/174 -> ladydevimon`       **Universe:** Digimon   **Gate:** `ladydevimon_unlock` (gated, playable)
**Verdict (as drawn):** Buildable with fidelity loss (4/5 exact, 1 near-miss)
**Verdict (after this run built the system):** **Fully buildable — exact behavioral fidelity on all 5 skills**

Second run under the "should be buildable / build the missing system in-run" rule. LadyDevimon is a
poison-retaliation kit, and it came within one field of being fully expressible today. The one gap — a
*hostile, damage-type-filtered* damage-dealt weaken — was the ledger's usual shape (the engine factory
already had every axis; the block kind exposed none of the interesting ones), and closing it flushed out a
**latent correctness bug** in the fix itself that the adversarial pass caught and killed. The whole kit was
then authored as block JSON and proven through the real `AuthoredRegistry.validate_character` (0 errors) and
a headless battle (`creator_ladydevimon_spec_probe`: 39/0).

## The kit
Five abilities (`character_ability_counts.ladydevimon = 5`, `ladydevimon5` the passive). Names from
`ability_info.json`; behaviour from the scripts (`split_desc` is the contract).

- **Black Wing** (`ladydevimon1`, cd1, 1 Random, Affliction): 20 Affliction damage to one enemy.
- **Devil Slap** (`ladydevimon2`, cd1, 1 Blue): 20 damage + Taunt the target 1 turn.
- **Darkness Spear** (`ladydevimon3`, cd1, 1 Red), on one enemy: 10 Nullify; **decrease their non-Affliction damage by 10 for 1 turn**; if not already poisoned, 5 Affliction now; and a stack of Lady's Poison.
- **Darkness Wave** (`ladydevimon4`, cd4, 1 Random): LadyDevimon becomes Invulnerable 1 turn.
- **Lady's Poison** (`ladydevimon5`, passive): enemies who use a Harmful skill on her gain a permanent stacking Lady's Poison — 5 Affliction/turn **per stack**.

## Mechanic audit
Every "Buildable" row is backed by JSON that **validates and runs**.

| Skill | Mechanic | Verdict | Notes / blocks |
| --- | --- | --- | --- |
| ladydevimon1 | 20 Affliction, single | **Buildable** | `damage {amount:20, damage_type:"AFFLICTION"}` |
| ladydevimon2 | 20 damage | **Buildable** | `damage {amount:20, damage_type:"NORMAL"}` |
| ladydevimon2 | Taunt 1 turn | **Buildable** | `apply {effect:{kind:"taunt", turns:1}}` (taunt kind, hostile) |
| ladydevimon3 | 10 Nullify, permanent | **Buildable** | `apply {effect:{kind:"barrier", amount:10, turns:-1}}` (barrier kind is hostile, applies to an enemy) |
| ladydevimon3 | **−10 non-Affliction damage dealt** | **Approximable → BUILT** | `damage_boost` was allied-only & unfiltered → added sign + damage-type filter |
| ladydevimon3 | conditional first 5 Affliction | **Buildable** | `group {when:{not_has_effect:"Lady's Poison"}, blocks:[damage 5 AFFLICTION]}` |
| ladydevimon3 | stack of Lady's Poison | **Buildable** | `damage_over_time {amount:5, damage_type:"AFFLICTION", turns:-1, stackable, per_stack, display_stacks, name_override:"Lady's Poison"}` |
| ladydevimon4 | self-Invulnerable 1 turn | **Buildable** | `apply {to:"user", effect:{kind:"invulnerable", turns:1}}` |
| ladydevimon5 | passive `on_harmful_received` | **Buildable** | `apply {to:"user", effect:{kind:"trigger", trigger:"on_harmful_received", turns:-1, then:[…]}}` |
| ladydevimon5 | poison **the attacker** | **Buildable** | in the trigger payload, `to:"target"` = the attacker (`_build_trigger` `set_explicit_targets([context.owner])`); dispatcher already skips ally attackers |
| ladydevimon5 | per-stack permanent DoT | **Buildable** | `per_stack:true` (a universal field) — 5 Affliction × stack count |

**Adversarial checks that passed:** the `on_harmful_received` payload genuinely lands on the *attacker*
(`context.owner`), not on LadyDevimon; the two Lady's Poison sources merge because both use
`name_override:"Lady's Poison"` and `Effect.effect_name()` couples the `not_has_effect` guard to that name;
the Nullify (a `barrier`, `hostile:true`) applies to an enemy. **No second character-mechanic gap.**

## What blocked it — one gap
Darkness Spear's *"decrease the target's non-Affliction damage by 10 for 1 turn"*. The engine factory
`damage_mod_effect(mag, dur, targets, class_targets, exclusion_targets, type_targets)` already does all of
it — a negative `mag` is a weaken, and `class_targets`/`exclusion_targets` are **damage-type** include/exclude
lists (`type_targets` is dead code). But the block `damage_boost` kind exposed only
`[amount, turns, skills]`, was `hostile:false` (allied-only), and its build arm clamped the amount unsigned
(a negative was silently zeroed). So a hostile, Affliction-sparing weaken was unauthorable.

## System built this run: signed + damage-type-filterable `damage_boost`

Expose the axes the factory already had — the mechanic, not the character.

- **Signed amount:** `damage_boost` joins `SIGNED_AMOUNT_KINDS` and builds via `_signed_amount` (like `cost_change`); a positive amount is an allied boost (today's behavior), a negative amount is a hostile weaken.
- **Damage-type filter:** `include_types` → the factory's `class_targets` (only these types modified), `exclude_types` → `exclusion_targets` (all types *except* these). LadyDevimon3 = `{amount:-10, exclude_types:["AFFLICTION"]}`.
- **Absent fields = today's exact behavior** (unfiltered positive boost) — a pure additive change; existing authored `damage_boost` content is unaffected.

### The correctness sub-finding (why the adversarial pass earned its keep)
The first cut made `damage_boost` `HOSTILE_BY_SIGN` *"mirroring cost_change"* — but the polarity is
**inverted**: a cost/cooldown **tax is positive**, while a damage **weaken is negative**. So the negative
weaken read *not-hostile* and routed through `add_allied_effect`, landing on an **invulnerable** enemy the
hand-written kit refuses (bypassing invuln / shrug-off / skill-ignore). The damage *number* was right on
ordinary targets (`get_true_damage` reads the mod regardless of routing), so it looked fine — a probe on an
invulnerable enemy exposed it. Fixed with `SIGN_HOSTILE_WHEN_NEGATIVE := ["damage_boost"]`, read by
`_is_hostile_effect` and mirrored in the independent oracle; a dedicated routing probe now pins the parity
(the block weaken is refused by an invulnerable enemy identically to `add_hostile_effect`).

- **Family (bar 1):** sign (boost/weaken) × damage-type (include/exclude), one factory, both reactive to the same fields.
- **Reach (bar 2):** **19/174** use a negative (hostile) damage-mod weaken (aang, ban, gohan, vegeta, zoro, …); **19/174** use a damage-type-filtered damage-mod; **union ≈26/174**. Clearly a system, not a band-aid.
- **Safety (bar 4):** no invented cap; the type filter only ever *narrows* what a mod touches; `amount:0` now rejected (a signed inert value), matching `cost_change`.
- **Prose (bar 5):** swings on sign ("more"/"less") and inserts the type phrase ("non-Affliction").
- **Engine cost (bar 7):** none — `damage_mod_effect` already had every arg and `get_true_damage` honors them. Schema + runner + validator + prose + editor. Probe `creator_damage_weaken_probe` 26/0 (+ the routing regression guard), hand-reversed.

## The create-ability proof
The full kit was authored as block JSON (id `auth_zz_ladydevimon_roulette`), passed the real
`validate_character` (0 errors, direct + save/load), built an `AuthoredCharacter`, and every mechanic fired
in a headless battle: 20 Affliction; 20 + Taunt; 10 Nullify + the weaken cutting Normal/Physical to 10 while
**Affliction stays 20** + conditional first 5 + a merging poison stack; self-Invuln; and the passive
poisoning an enemy attacker for a per-stack 5/turn (1 hit → 5, 2 → 10) while skipping ally attackers.
`creator_ladydevimon_spec_probe`: **39/0**.

**Residual loss (honest, minor):** the two Lady's Poison sources carry different survival flags — skill-3's
is a plain cleansable/dies-on-death DoT, while the passive's rides `AuthoredCharacter`'s permanent-effect
survival (system, non-cleansable, survives death). The shipped kit applies both through one function, so
both are plain; the authored passive path makes its copy sturdier. A nuance of how authored passives
preserve permanent effects, not a damage-number difference.

## Verdict for the roadmap
Shipped this run; the ledger's through-line holds again — the gap was **surfacing, not capability**. The
signed/filterable `damage_boost` is a widening of the existing damage-mod kind (a **damage-dealt
modification** sub-row), and the polarity bug it surfaced hardened the `HOSTILE_BY_SIGN` machinery for any
future inverse-signed kind. With it, LadyDevimon is fully buildable at exact behavioral fidelity.
