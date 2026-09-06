---
tags: [area/systems, type/concept]
---

# The Creator

The Creator is the player-facing **block authoring system**: players compose skills as validated
JSON block trees, and `ScriptedAbility` interprets those trees at runtime **through the same engine
primitives every hand-written ability uses**. A player-made character is not simulated, sandboxed,
or approximated — it stands in the battle line and calls `Character.resolve_damage` exactly like
Toji or Frieza does.

Related: [[Block Palette Reference]] (the complete lookup), [[Creator Gap Analysis]] (how much of
the game it can express, measured), [[What Cannot Be Built Yet]] (the per-factory gaps),
[[Creator Roadmap]] (the plan). Engine context: [[System Overview]],
[[Effects and Durations]], [[Damage Pipeline]], [[Trigger Types]], [[Server Authority Model]].

---

## The one-line version

> A block tree is **data all the way down**. There is no `eval`, no `load()` of an author-supplied
> path, no `Callable` built from a string. `BlockRunner` is a `match` statement over a whitelist.
> Everything else in this note is a consequence of that.

---

## Architecture: the chain

```
authored/<id>.json           the spec on disk (one file per character)
        |
        v
AuthoredRegistry             load / save / validate / status + permissions
        |  validate_character()  ->  BlockValidator.validate_ability()  ->  BlockSchema
        v
AuthoredCharacter            a real Character node, same 7-component scene shape
        |  _build_moveset()
        v
ScriptedAbility (x1-5)       an Ability subclass; execute / target / split_desc / custom_behavior
        |  execute(user, battle)
        v
BlockRunner                  the interpreter: walks the tree
        |
        v
Character.resolve_damage / resolve_healing / add_hostile_effect / add_allied_effect
Effect.<factory>()           the same ~70 factories hand-written kits call
```

| Layer | File | Lines | Job |
|---|---|---|---|
| Palette | `blocks/block_schema.gd` | — | The whitelist. Ops, effect kinds (each with its FACTORY fields plus the universal `Effect` field set), plain + condition-filtered selectors, conditions, trigger hooks, damage types, limits |
| Safety | `blocks/block_validator.gd` | 241 | Rejects anything not on the whitelist, out of range, too deep, or carrying an unknown key |
| Interpreter | `blocks/block_runner.gd` | 301 | Walks a validated tree; defensive at runtime so it can never abort a live match |
| Ability | `blocks/scripted_ability.gd` | 254 | `execute` / `target` / `extra_usable` / generated `split_desc` / generated bot hints |
| Character | `blocks/authored_character.gd` + `.tscn` | 89 + 34 | Builds a `Character` from a spec instead of a hand-written `character/<name>.gd` pair |
| Store | `blocks/authored_registry.gd` | 252 | Disk store, statuses, permissions, character-level validation |
| Assets | `blocks/authored_assets.gd` | 154 | Chunked PNG upload, 256 KB / 1024 px caps, server-derived paths |
| Server | `components/server_connection.gd` | — | 11 `authored_*` message types, kill switch, venue gating |
| Editor | `webclient/app/app.js` (≈ 5128–5441) | — | The overlay: character identity, ability tabs, block list, live preview |

### Why the chain has exactly this shape

**`BlockSchema` is the single source of truth, and the editor is downstream of it.** The
`authored_palette` server reply (`components/server_connection.gd:4132`) ships `OPS`,
`EFFECT_KINDS`, `SELECTORS`, `CONDITIONS`, `REACTIVE_TRIGGERS`, `DAMAGE_TYPES` and `LIMITS`
straight out of `BlockSchema`, so the editor's dropdowns and min/max spinners **cannot drift from
the validator**. Adding a capability is: one entry in `BlockSchema`, one case in `BlockRunner`, one
rule in `BlockValidator`. Nothing else in the engine changes.

**`BlockRunner` is not a rules engine.** Its header says it outright:

```gdscript
# That is the whole trick: authored abilities are not a parallel rules engine.
# They funnel into the same code paths, so every existing interaction — invuln,
# counters, reflect, shields, death-cleanse, Blood Spear interception, the lot —
# applies to them for free and stays bug-for-bug consistent with hand-coded kits.
```

That is why `_op_apply` (`blocks/block_runner.gd:201`) bothers to route hostile kinds through
`Character.add_hostile_effect` rather than just storing the effect: hostility routing is what makes
shrug-off, `IGNORE_SKILL` and application gating apply.

---

## The safety model, and why data-never-code is *forced*

The authors are **players**. Not modders with repo access, not staff — arbitrary logged-in
accounts. That single fact eliminates every design that generates or loads code:

> [!danger] Never do this
> A "compile the block tree to GDScript and `load()` it" editor is remote code execution the
> instant a player hits Save. So is any effect kind that takes a **path or scene name** as a
> string — see the Disguise entry in [[What Cannot Be Built Yet]], where
> `Character.from_character_name(disguise_path)` concatenates into
> `load("res://character/" + name + ".tscn").instantiate()`.

Nine things carry the boundary:

1. **No code path at all.** `Ability.from_database` branches on `ability_info.has('blocks')` and
   instantiates `ScriptedAbility` *instead of* `load(script_path).new()`
   (`abilities/scripts/ability_component.gd:131`). The only `Callable` in the whole system is the
   trigger payload closure that the **engine** constructs (`_build_trigger`), closing over
   engine-held references, never over author text. The universal effect fields are scalars
   (bool/int/String) for exactly this reason — every `Callable` field on `Effect` is excluded.
2. **Closed vocabulary.** Every op, kind, selector, condition, damage type, class and trigger is a
   whitelist lookup against `BlockSchema`.
3. **Unknown-field rejection.** Not "ignore unexpected keys" — *reject*. `_validate_block:140`,
   `_validate_effect:184`, `_validate_condition:222`. A submitted tree cannot smuggle a field that
   a future runner version might start reading.
4. **Bounded work.** 40 blocks per ability, depth 4 (trigger nesting charged **double**), amounts
   0–500, turns −1 or 0–20, `then` ≤ 12, cost total ≤ 5. A tree cannot hang a match.
5. **Same primitives.** No parallel damage math, no parallel effect store. Invuln, counters,
   reflect, shields, death-cleanse all apply for free.
6. **Runtime is defensive *as well as* validated.** `# Runtime posture: NEVER crash a live match.`
   Unknown op / selector / kind / condition each `push_warning` once and skip; `_amount` re-clamps
   to 0–500; `gain_energy` re-clamps 0–5; there is a second depth guard at `block_runner.gd:41`.
7. **Validate on save AND on load.** `AuthoredRegistry.load_all` re-runs `validate_character` on
   every file off disk and *skips* failures (`:57`). A hand-edited JSON cannot reach a match.
   `_sanitize_icons` (`:89`) coerces every `icon` to a real slot or `""` on both paths, so no
   client string ever reaches `AuthoredAssets.asset_path`.
8. **Server-decided identity.** The author is always the authenticated session; `status` is clamped
   to author-settable values in `_authored_save`; `approved` is admin-only.
9. **Filesystem safety for uploads.** The stored path is derived from `(char_id, slot)`, never a
   client filename. PNG magic bytes + IHDR dimensions are verified. One in-flight upload per
   session, byte/chunk caps, out-of-order rejection, 2-minute TTL.

> [!info] Why XSS is not a vector
> Names, descriptions and effect `text` get **length caps only** — no HTML/profanity filtering.
> That is safe because the web client builds every node with `document.createTextNode`
> (`webclient/app/app.js:10`). See [[Web Client Architecture]]. It is *not* safe if anyone ever
> introduces an `innerHTML` path for authored strings.

The safety model is exercised, not asserted: `training/tests/block_dsl_probe.gd` asserts that
`exec_shell`, damage 999999, selector `everyone_everywhere`, kind `instant_win`, a smuggled
`script` field, missing name, empty ability, cost 99, turns 9999 and a 10-deep `group` chain are
**all** rejected.

---

## Authoring lifecycle

### Statuses

```
draft ──▶ testing ──▶ submitted ──▶ approved   (anyone, everywhere)
  ▲          ▲            │
  └──────────┴────────────┴──▶ rejected  (back to the author with a note)
```

| Status | Who can play it | Where |
|---|---|---|
| `draft` | author | bot / private only |
| `testing` | author | bot / private only |
| `submitted` | author (review pending) | bot / private only |
| `approved` | **anyone** | everywhere |
| `rejected` | author | bot / private only |

`AuthoredRegistry.can_use(id, username, is_private_or_bot)` (`:161`) is the whole rule. It is
enforced at **two funnels** — `_json_enqueue` (quick/ranked/private) and
`start_immediate_bot_match` — both via `_authored_team_error`, which strips `:` suffixes (Toga
disguise / Jin-woo form tokens) before the lookup.

### The 11 server messages

`authored_list` · `authored_get` · `authored_save` · `authored_submit` · `authored_unsubmit` ·
`authored_delete` · `authored_review` · `authored_validate` · `authored_asset_fetch` ·
`authored_upload_begin` / `_chunk` / `_end`.

Three behaviours worth knowing:

- **`authored_validate` renders the real thing.** It validates without persisting and returns each
  ability's `{name, desc:[{text,color}], damage_hint}` produced by the *actual*
  `ScriptedAbility.split_desc()`. The editor preview and the battle tooltip are the same code.
- **Editing an approved character forces status back to `submitted`.** `_authored_save`
  (`server_connection.gd:4148`) also erases `review_note` and refuses to overwrite another
  player's id.
- **Uploading art does *not* demote an approved character.** `authored_upload_end` binds the slot
  through `save_spec` on a deep copy, deliberately not through `_authored_save`.

### The kill switch

`creator_enabled` (`server_connection.gd:183`) persists to `res://server_flags.json` and defaults
to **false**. `_creator_blocked(username)` = not enabled and not admin, applied to the *entire*
`authored_*` frame surface in **one place** at `_on_json_message` (`:733`) — not per-handler,
because hiding the button is only cosmetic. `admin_toggle_creator` broadcasts `creator_state` to
every online session; the client hides the menu entry and force-closes the overlay mid-session.
See [[Admin and Live Ops]].

---

## Auto-generation: descriptions and bot hints

Authored content must not owe the debt hand-written kits owe (~34% of ability code is description).
`ScriptedAbility` derives everything from the same tree:

- **`split_desc()`** (`:69`) emits, in order: the author's flavour line; a dim-grey
  `Requires: …` line per `requires` entry; an aquamarine `Passive — active from the start of the
  battle` line; then one line per top-level block. Grammar helpers exist so it reads right:
  `_sentence_case` (deliberately *not* `String.capitalize()`, which title-cases every word),
  `_is_plural`/`_verb`/`_possessive` so it says "all enemies **take**", not "takes".
- **`bot_damage_hint()`** (`:201`) sums damage ops plus DoT `amount × turns` (`× 1` when delayed).
  It ignores `when` guards and `to` selectors — it is an **upper bound**, on purpose.
- **`custom_behavior()`** (`:226`) switches on `target_mode` into the shared behavior helpers:
  self → panic button, ally → heal or helpful, all_enemies → AoE damage, otherwise single-target
  damage or hostile. See [[Bots and Training]].

---

## Current state — honest

> [!warning] The Creator is dark on this machine
> `server_flags.json` does not exist, so `creator_enabled` defaults to **false**: only admins can
> reach any `authored_*` message. `authored/` holds exactly one spec — `auth_testchar.json`, the
> probe fixture, status `testing`. There is no `authored_assets/` directory; no art has ever been
> uploaded here.

### Half-built and unreachable

**Approved authored characters cannot be picked in char-select (task #72).** `gridArea`
(`app.js:2181`) builds the grid from `S.roster` filtered by `CHAR_SELECT_SET`; authored ids are in
neither, and nothing merges `S.creator.approved` into the roster. The **only** way to field an
authored character today is `creatorTestMatch` (`app.js:5264`), which fires `queue_bot` with the
authored id plus two starters — the author's own bot match, launched from inside the editor. The
entire server-side venue-gating ladder is live but unreachable for everyone except an author
testing. Toga's disguise picker is roster-only for the same reason.

**Authored characters fight with no portrait (task #73, partially done).** `portraitUrlFor(pn)`
routes `auth_`-prefixed paths to `authoredArtUrl` — so menus and the creator list work. But the
battle character strip and the battle description panel call `portraitUrl(c)` → `portraitRel(c)`,
which looks the character up in the static `portraits.json` manifest and returns `null` for an
`auth_` path with no fallback. Ability icons in battle *do* work (the server ships
`icon_char`/`icon_slot`). Secondary consequence: `authored_asset_fetch` sits inside the
kill-switch gate, so with the Creator off even legitimately-approved art cannot be fetched by an
opponent or spectator.

**Bot semantic tags never resolve.** `training/bot_policy.gd:211` tests `if "bot_tags" in ability`
with the comment "ScriptedAbility (player-authored) carries its own derived tags" — but **no
`bot_tags` property exists** on `ScriptedAbility` or on `Ability` (the only references in the whole
repo are in `bot_policy.gd` itself). Authored abilities fall through to the script-basename lookup,
which yields `scripted_ability`, which is not in `bot_tags.json` ⇒ bitmask 0 ⇒ every semantic
feature is 0 for the v3 policy. The legacy `custom_behavior` path still works.

### Live correctness bugs

> [!warning] Trap — a `damage` block in a Passive or a trigger payload can silently no-op
> `Character.resolve_damage` returns immediately when `owner.used_ability` is null
> (`scripts/character_component.gd:2112`). `_op_heal` guards against this by borrowing
> `used_ability` (`block_runner.gd:183`); **`_op_damage` does not**. `startup_passives` calls
> `execute()` without setting `used_ability`, so a Passive containing a `damage` block does nothing
> at battle start, and a trigger `damage` payload on a character who has not yet acted this match
> does nothing. The probes pass only because they set `used_ability` by hand.

- **`_op_heal`'s restore line is a no-op where it mattered.**
  `user.used_ability = prev if prev != null else user.used_ability` (`:190`) leaves the *borrowed*
  `used_ability` in place when `prev` was null, instead of clearing it.
- ~~**Authored effects never get the permanence treatment.**~~ FIXED. `system`, `display_system`,
  `remove_on_death` and `cleansable` are **universal effect fields** now — every kind accepts them,
  applied by `_apply_universal_fields` after the factory returns. A Passive's permanent machinery can
  be authored to survive a revive or a buff-strip. See
  [[Cleanse Silence and Effect Removal]] and [[Effects and Durations]].
- ~~**`stacks_at_least` is dead vocabulary.**~~ FIXED. `stackable` is universal, so any effect can
  stack; `EffectStorageComponent.add_effect` merges a re-application into the stored effect. There is
  no `stack` op — stacking is emergent — and consequently **no block that SPENDS a stack**.
- **Trigger payload attribution.** `_build_trigger` closes over `owner_ability`, so effects
  applied by a payload carry `set_source(owner_ability)` and hence `effect.user` = the **original
  caster**, even when the trigger sits on an ally.
- **Runtime depth does not carry across a trigger boundary.** A payload starts a fresh
  `BlockRunner` at `_depth = 0`; only the validator's double-charged accounting bounds
  trigger-in-trigger, and nothing bounds engine-level trigger re-entrancy.
- **Two classes lie.** `Bypassing` is whitelisted but `ScriptedAbility.target()` hardcodes the
  2-arg call, so the skill still cannot *select* an invulnerable enemy — while
  `Ability._skill_pierces_invuln` treats it as piercing for reflect re-aiming. `Control`,
  `Channeled` and `Preserves Channel` are whitelisted but the cancel behaviour is driven entirely
  by `CONTROL_CANCEL`/`CHANNEL_CANCEL` effects the palette cannot build — an author ticks the label
  and gets none of the drawback.
- **Minor validator softness.** `_validate_cost` does `int(str(k))` on the key, so a non-numeric
  cost key parses to `0` and passes as the Green slot. `damage_type` is accepted on *every* effect
  kind but only `damage_over_time` reads it. `stun`/`invulnerable` `classes` strings are **not**
  whitelisted (they are only stringified).

### Editor-vs-validator drift (cosmetic, but confusing)

The class chip row offers **12** of the validator's 17 classes; `Control`, `Channeled`,
`Uncounterable`, `Stealthed`, `Preserves Channel` are accepted server-side but not offered.
`creatorBlock` renders no controls at all for `stun`/`invulnerable` `classes`, for effect `text`,
for `invisible`, for **`when` guards**, for **`requires`**, or for a `group`'s children (though
`group` can be added and `requires` survives a round-trip).

> [!tip] The single highest-value fix in the whole system — SHIPPED
> Two of the six conditions' worth of expressiveness is fully implemented server-side and shipped
> to the client in `authored_palette` — and at the time of writing there was **no UI that wrote
> `b.when` or `ability.requires`**. That UI has since landed (`app.js:5529`, `:5396-5403`); see
> the "shipped since the last roadmap" ledger in [[Creator Roadmap]].

### A second, unused entry point

`Ability.from_database` will build a `ScriptedAbility` for any `abilities_data.json` entry carrying
a `blocks` key (`ability_component.gd:131`). **No entry has one today** (grep count 0). Authored
abilities reach battle only via `AuthoredCharacter._build_moveset`. That path exists so a shipped
character could one day be authored in blocks — see [[Adding a Playable Character]] and
[[Data Files and the Deploy Mirror]].

---

## See also

- [[Block Palette Reference]] — every op, field, limit and condition, with a worked example
- [[Creator Gap Analysis]] — **how much of the game the Creator can express, measured across all 174
  roster characters at once**: 7/174 fully expressible today, a 150/174 ceiling, the cumulative
  coverage curve, the selector-system design, and the explicit do-not-build tier
- [[What Cannot Be Built Yet]] — 40+ measured gaps, ranked, with what blocks each one
- [[Ticking and Passives]] — the two mechanics that are not effect factories
- [[Creator Roadmap]] — the implementation roadmap (rewritten 2026-08-03 from the gap analysis):
  phases A–G covering engine and editor-palette work, the shipped ledger, the verification
  contract, open owner decisions, and the do-not-build list
- [[Hard Rules and Guardrails]] · [[Traps That Have Bitten Us]] · [[Verification Playbook]]
