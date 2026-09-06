---
tags: [area/process, type/reference]
---

# Traps That Have Bitten Us

A numbered field guide. **Symptom first** — you are most likely here because something is behaving
oddly and you do not yet know why. Every entry is a real defect that shipped or nearly shipped.

---

## Turn and effect timing

### 1. A per-turn skill deals one fewer instance than its text promises

**Symptom.** "Deal 15 damage each turn for 3 turns" deals it twice, or the whole window lands a turn
late and desynchronises from the skill's other clauses.

**Cause.** A side's ticking effects are **snapshotted before that turn's abilities execute** —
`battle_manager.process_turn_package` gathers `get_ticking_effect_information()` and only *then* calls
`start_round_loop()`; `turn_end_clicked` does the same. So an effect a skill plants **cannot appear in
its own cast turn's batch**. The same is true of a `START_OF_TURN_TRIGGER` applied during the caster's
own turn: that turn's start-of-turn triggers have already fired.

**Fix.** Deal instance 1 by hand, then apply the recurring effect for the remainder:

```gdscript
Character.resolve_damage(context, target, dmg, type)   # instance 1, right now
Effect.damage_effect(dmg, type, 2 * K - 1)             # K-1 further ticks
```

"for 3 turns" = immediate + duration **5**. `abilities/squalo1.gd` and `abilities/genos3.gd` are the
shipped precedents; `fern3` and `stark3` both had it wrong and were fixed 2026-07-28.

> [!danger] Do not "fix" a short window by lengthening the duration
> That restores the total but leaves the whole effect a turn late. Stark's Cowardice at duration 7
> healed on offsets `[+2,+4,+6]` while its own mark and redirect ran `+0..+5` — the last heal landed
> after the skill had ended.

See [[Effects and Durations]], [[The Turn Pipeline]].

### 2. Measuring a turn-boundary effect at the wrong point makes a broken skill look correct

**Symptom.** The probe says the heal/damage landed on the right turn. It did not.

**Cause.** `end_of_turn_effect_handling()` ends the turn **and fires the next turn's start-of-turn
triggers**. Sampling HP after it attributes the result to the wrong turn.

**Fix.** Walk one boundary at a time. Print the acting side and every relevant effect duration at each
step, and assert the **offsets** the effect fires on, not the total count. This exact mistake made a
broken Cowardice pass review.

### 3. `END_OF_TURN_TRIGGER` used where `TICKING_TRIGGER` is the convention

**Symptom.** A per-turn effect fires on the wrong side's turn, or needs a manual team gate that keeps
getting the polarity wrong.

**Cause.** Three firing models, easily confused:

| Trigger | Fires | Needs a team gate? |
| --- | --- | --- |
| `TICKING_TRIGGER` | End of the effect **user's** turn, via the ticking engine (`effect.user in acting_team`) | No — auto-gated |
| `START_OF_TURN_TRIGGER` | Every character, **both sides**, at every turn transition | Yes, manually |
| `END_OF_TURN_TRIGGER` | The rare exception | — |

**Fix.** Use `TICKING_TRIGGER` for anything that happens each turn. It is the convention — **84 files
under `abilities/` reference it against 18 for `END_OF_TURN_TRIGGER`** — it fires only for the acting side, and it is
what the ×2 duration arithmetic assumes. `START_OF_TURN_TRIGGER` is right only for machinery that must
reset every turn for everyone (a per-turn budget). Owner corrected this 2026-07-28 after Cowardice's
regen was built on `START_OF_TURN`; Frieza's Nova Strike payout was rebuilt on `TICKING_TRIGGER` for
the same reason — its text says "at the end of his next turn", and `START_OF_TURN` made it fire at the
*start* of the turn after that.

A **single delayed event** ("at the end of the following turn…") is not this case and correctly has
nothing on the cast turn.

### 4. A passive works in bot matches and breaks in PvP

**Symptom.** "Works against bots, broken against players."

**Cause.** `battle.waiting_for_turn` tracks the **side-1 (`battle.player`) vs side-2 (`battle.enemy`)
split**, not "my team". When the owner is the *second* player their team is the `enemy` side, so
`if battle.waiting_for_turn` is inverted and the trigger fires on the opponent's turn. Bot matches
never show it: the human is always side 1.

**Fix.** Derive the acting team and require membership:

```gdscript
var acting_team = battle.enemy.team if battle.waiting_for_turn else battle.player.team
if not me in acting_team.characters:
    return
```

Found in `abilities/mavis5.gd` 2026-07-05. See [[The Turn Pipeline]].

---

## Effect identity, visibility and teardown

### 5. A counter never advances, or a swap never fires

**Symptom.** An internal use-counter freezes at 1; an every-Nth-use transformation never triggers.

**Cause.** `effect.effect_name()` defaults to the **source ability's name**, so every effect one
ability applies shares a name. `add_effect` merges on `(effect_name, effect_type, user)`. An internal
counter MARK on the caster and a stacking MARK pile of the same ability on enemies are therefore *the
same effect* to the lookup, and `has_effect(COUNTER, MARK, user)` silently returns the wrong one or
nothing.

**Fix.** `effect.name_override` (`scripts/effect_component.gd:75`, checked first in `effect_name()`).
Set it **before** `add_effect`, since merging keys on `effect_name()`. Keep the *source* as the real
ability — `get_active_abilities` only honours an `ABILITY_SWAP` whose `source` is in `base_abilities`.
Both Frieza symptoms above were fixed purely by `name_override`, 2026-07-28.

The inverse also bites: effects that should **share** one stack counter must share one `set_source`.
Ryohei's stack mark used `set_source(self)` in one ability and a different source in another, so an
unrelated same-named buff mark merged into the stack counter and corrupted both.

### 6. An effect nobody can see, that you meant only to protect from cleanse

**Symptom.** A brand or counter that changes how the opponent should play is invisible to both
players. Or: an effect that must survive a revive silently disappears instead.

**Cause.** `Effect.system` was doing two unrelated jobs — **survival** (`clear_non_system_effects`
keeps only system effects on a dead or banished holder; `get_all_death_cleansable_effects` spares a
system effect whose `remove_on_death` is false) and **hiding** (it is stripped from the wire snapshot,
so *neither* player ever sees it).

**Fix.** `Effect.display_system = true` (`scripts/effect_component.gd:56`) keeps the survival
semantics and puts the effect back on the wire. The owner's rule: *only effects that are hidden
information, or are not helpful to either player to know, should be hidden from either player.*

> [!warning] Eight filter sites must agree
> `_serialize_wire_team`, `log_effect_applied`, `log_effect_expired`, `_serialize_effects_for_hash`,
> `_serialize_execution_preview`, `_validate_snapshot_drift`, `effect_storage_component.get_effect_clusters`,
> and `bot_observation.effect_visible` — plus `app.js effectClusters` and `scripts/display_effect.gd`.
> Miss `_validate_snapshot_drift` and it `push_warning`s "effect missing in live" **every single turn**.

`system` + `display_system` together on a ticking effect is deliberate, not contradictory: `system`
excludes it from the player-draggable execution preview (pinning it last), `display_system` puts it on
screen. See [[Effects and Durations]].

### 7. A passive dies permanently when its owner is revived

**Symptom.** A revived character silently loses their passive for the rest of the match.

**Cause.** The death-cleanse predicate is `effect.user == dying and (not effect.system or
effect.remove_on_death)`, and `remove_on_death` **defaults to `true`**. `startup_passives` is the only
caller of a passive's `execute()` and runs at battle start only — the revive abilities (`jeanne4`,
`madoka4`, `ichibe6`) just flip `dead = false`.

**Fix.** Permanent passive machinery needs **both**:

```gdscript
eff.system = true
eff.remove_on_death = false   # system alone is NOT enough
```

`abilities/death5.gd` is the shipped precedent. Adversarial review caught four effects across Stark
and Fern with `system = true` and nothing else, 2026-07-28. If the effect must stay visible, rebuild
it on demand instead — have the callback re-run `execute()` when it finds its state missing (`fern5`).

### 8. A permanent trigger outlives its own accumulator and dereferences null

**Symptom.** Deployed crash: `Invalid access to property or key 'mag' on a base object of type 'Nil'`.
The passive goes dead and stderr fills up, but nothing hard-fails.

**Cause.** `Effect.trigger_effect` sets `cleansable = (dur >= 0)`, so a **duration −1 trigger is
cleanse-proof**. `Effect.mark` never touches `cleansable`, so it inherits the class default `true`
(`scripts/effect_component.gd:63`). A buff-strip (`cleanse_all_ally_effects`, which reaches a
character's *own* self-applied buffs) splits the pair. `abilities/inuyasha3.gd` strips and then deals
damage on the very next line, so the surviving trigger fires against a missing accumulator
immediately.

**Fix.** Null-guard and **rebuild the mark at zero** — the strip fairly took the earned stacks, but a
permanent passive must keep counting. And gate `extra_usable` on the **trigger**, not the mark: keyed
on the mark, a strip re-enabled the skill and a recast stored a *second* permanent trigger (it is
neither stackable nor refresh, so `add_effect` falls through to a duplicate) and every hit accrued
twice, compounding per strip.

`Effect.empty` forces `cleansable = false`, so an EMPTY paired with a cleansable MARK desyncs the
other way. Check any permanent trigger + counter pair for this.

### 9. Removing a Shield with `erase_effect` leaks its companion effects

**Symptom.** A protected ally stays permanently invulnerable after the shield is gone; a character's
kit never resets.

**Cause.** Removal methods are not interchangeable. `erase_effect` fires only `effect_removed` and
skips `wrapup_func`. `consume_effect` → `end_effect(CONSUMED)` fires `effect_expired` → `erase_effect`
but **still skips `wrapup_func`**. Only `end_effect(CANCELLED)` runs wrapup. Many characters hang
cleanup on a shield's `wrapup_func`, and break-hooks like `break_vow` are wired into
`check_effect_breaking`, not the wrapup at all.

**Fix.** Use `character.shatter_shields(breaker)` / `shatter_barrier(breaker)` — the same teardown
natural damage uses. They set `eff.breaker`, run `check_effect_breaking`, then `consume_effect`, and
return the summed magnitude broken. Reference: `abilities/squalo2.gd`, `abilities/semiramis3.gd`.

Note "Nullify" is `EffectType.Type.BARRIER`, not a distinct type. And to count shields for a
"+N per shield removed" formula, read `get_shield_effects().size()` **before** shattering.

> [!info] Corollary
> A shield's `wrapup_func` fires on **break and on unbroken expiry**. A wrapup meant only for "expired
> unbroken" must early-out on `context.effect.breaker != null` (fixed in `cell3.gd`).

### 10. An on-death effect placed on an ally vanishes milliseconds later

**Symptom.** A dying character's parting gift never takes effect.

**Cause.** `die()` runs `check_death_triggers()` and **then** `cleanse_death_effects()`, which for
*every* character erases effects where `effect.user == dying`. A non-system effect the dying character
placed on an ally during its own on-death trigger is therefore erased immediately.
`remove_on_death = false` does **not** save it — that flag only protects *system* effects.

**Fix.** Either `system = true` (survives, but invisible — see trap 6), or apply it with the **ally as
the effect's user** (`add_allied_effect(ctx, ally, ally, eff)`) so `user != dying`; recover the origin
character in the callback via `eff.source.user`. Also: you cannot apply an effect to the dying
character inside its own on-death trigger — it is already `dead`, and `can_apply_allied_effect`
requires `is_alive(target)`.

> [!warning] The inverse
> A debuff cast **by** an attacker **on** a victim has `effect.user == attacker`, so it is not among
> the dying victim's own effects and **lingers on the corpse**. Any "is my debuff still on a living
> enemy?" poll must skip dead holders (`if not c.dead and c.has_effect(...)`). Banished — not dead —
> holders keep their effects and should still count.

### 11. "React to damage received" silently no-ops on the killing blow

**Symptom.** A reflect works on every hit except the lethal one.

**Cause.** Reflect fires from `Character.resolve_damage` **after** the damage lands. If that damage is
lethal, the call chain runs `die()` → `cleanse_death_effects()`, which erases the reflect marker
before the post-damage `has_effect` lookup runs.

**Fix.** Snapshot first. `Character._capture_reflect(target)` is called *before* the damage and
returns the effect reference; `Character._fire_reflect(...)` is called after. Holding the reference is
safe — `erase_effect` only unlinks it from storage. **General lesson: any logic reading effects after
a damage call must capture before it.** Locked by
`training/tests/yubel_lethal_reflect_probe.tscn`.

---

## Engine lifecycle

### 12. `Invalid access to … on a base object of type 'previously freed'` — a turn later

**Symptom.** A channel or control ability crashes, but not on the turn it was cast.

**Cause.** ~17 abilities (`kitara1`, `genos3`, `gogeta1`, `gray6`, `korra8`, `maka3`, `madoka2`,
`nonon3`, `sakura2`, `shiro4`, `tanjiro2`, `cell6`, `machinedramon3`, …) do `cancels.append(eff)` and
*then* apply it. Two ordinary outcomes free that node while the list still points at it: the
application is **rejected** (invulnerable / dead / ignoring target) → `_free_unapplied_effect`, or it
**merges** into an existing stack → the incoming node is freed.

**Fix.** Fixed engine-side with `Character._end_cancel_effects`, guarding on `is_instance_valid(eff)`
and `eff.is_queued_for_deletion()` at all three iteration sites.

> [!danger] `queue_free()` is DEFERRED
> Within the casting frame the node is still readable and the fault does not appear. **A probe must
> `await get_tree().process_frame` twice** before it can reproduce this. Also: always `queue_free()`,
> never `free()` — abilities write fields on effects after `Character.add_*_effect` returns in the
> same frame.

### 13. Orphaned nodes — and misreading the orphan count

**Symptom.** Live server at 561k objects and 478k orphaned nodes after one active day.

**Cause.** Effects, Abilities and Characters are **Nodes, not RefCounted**. Dropping the last
reference leaks them forever. The old architecture parented nothing and freed nothing.

**Fix.** Every runtime battle object must either be parented into the battle subtree (so match
teardown cascade-frees it) or explicitly `queue_free()`d when transient or rejected.
`training/tests/orphan_probe.tscn` gates the per-battle delta at ≤ 25 (`orphan_probe.gd:76`); it was
+140 before the fix and is 0 after.

> [!warning] `OBJECT_ORPHAN_NODE_COUNT` is not "nodes without a parent"
> It counts every live Node **not in a SceneTree** — an out-of-tree parent's whole subtree counts. The
> server keeps every cached `Player` out of tree, so a large baseline is expected and the deployed
> `orphans=16166` is not by itself evidence of a leak. Watch the **delta**.

See [[Node Lifecycle and Orphans]].

### 14. A cooldown-0 skill comes back unusable

**Symptom.** Every skill settles one turn above its printed cooldown; a cooldown-0 skill cannot be
re-used. Under a standing reactive Paralyze, a character who acts every turn never recovers any
cooldown at all.

**Cause.** `Ability.start_cooldown()` writes **`cooldown + 1 + cooldown_mod`** and
`MovesetComponent.advance_cooldowns()` takes the +1 back at the end of the acting team's turn.
Paralyze blocks exactly that decrement — nothing else. The old code pre-compensated *inside*
`start_cooldown`, but `battle_manager.execute_ability` calls `start_cooldown()` at :1190 and
`check_ability_use_triggers()` at :1206, and reactive Paralyze sources (Yoruichi's Shunko: Gather,
Rimuru's Gluttony counter) land in the **later** one. So the +1 was stranded.

**Fix.** Decide at decrement time, not stamp time: `Ability.cooldown_started_turn` records
`battle.current_turn_number`, and `MovesetComponent._advance_one` exempts a stamped ability from the
freeze and clears the stamp. The test is "is there an **unreclaimed** stamp", not "was it stamped this
turn" — they diverge when the advance never ran (a dead or banished holder), so a character who acts,
dies and is revived does not come back a turn short. Locked by
`training/tests/cooldown_paralyze_probe.gd` across all four quadrants. See [[Cooldowns and Energy]].

---

## Client

### 15. Every primary/splash skill resolves on the wrong character, with no error

**Symptom.** X-Burner's 25 lands on whoever happens to sit at the top of the clicked side, regardless
of who you clicked. ~21 abilities read `user.targeter.main_target` to split primary from splash.

**Cause.** `targeter_component.add_target` sets `main_target` on the **first** call and appends
thereafter, and `battle_manager.process_turn_package` walks `target_idxs` in the order the client
sent. **Ordering IS the primary-target signal** — there is no explicit `main_target` assignment
anywhere on the human path. `pickTarget` in `webclient/app/app.js` built AoE lists as
`t.special_targets.slice()`, and `special_targets` arrives in ascending canonical order.

**Fix.** `[canonTarget].concat(rest)`. SINGLE/COUNT/SELF were never affected (they send one index).
The bot path was always correct — `player_component` assigns `targeter.main_target` directly. Locked
by `battle: an AoE sends the CLICKED target first` in `webclient/app/aa-tests.js`; reverting the fix
fails with `expected [5,3,4], got [3,4,5]`. See [[Targeting and Main Target]].

### 16. A dropped `}` inside an `@media` block traps every later rule

**Symptom.** Body-level elements (chat panel, admin FAB, toasts) lose all styling **on desktop** while
`#app` menu buttons stay fine. The admin FAB renders as a giant blue rectangle.

**Cause.** An Edit inserting rules just before an `@media (max-width:760px)` block's closing `}`
dropped that `}`. Every rule after the block became nested *inside* the query, so those elements were
unstyled above 760px and fell back to a global `button { width:100%; background:accent }`.

**Why it slipped through.** The mobile edit was verified only at 375px — where the trapped rules
**still applied**. The break is only visible **outside** the media range.

**Fix.**

```bash
python -c "s=open('webclient/app/style.css').read(); print(s.count('{')==s.count('}'))"
```

`False` means a block is unclosed. When an Edit's `old_string` ends at a block's closing `}`, make
sure `new_string` re-emits it. Verify responsive CSS at **both** widths. Appending new rules at the
**end of the file, outside any `@media`**, avoids the whole class of problem.

### 17. The chat log silently freezes and never shows new messages

**Symptom.** Chat stops updating until you switch tabs.

**Cause.** The log's append fast-path. Channels are ring buffers capped at 100 via a **front
`shift()`**, so at the cap a new message does push+shift and `count` stays 100 == `panel._count`. A
naive `count >= _count` append loop runs `for (i=100; i<100)` — zero iterations.

**Fix.** Three precisely-gated branches: a no-op when nothing changed, an append only on
**strict** `count > _count`, and a full `replaceChildren` otherwise — all guarded by `headIntact`
(first-message **object identity**). Because each message is a fresh object literal, a shift changes
`msgs[0]` identity, so `headIntact` goes false and forces a full re-sync. The no-op branch is equally
essential: `syncSocialUI()` runs at the end of *every* `render()`, so without it the log rebuilds on
every unrelated state change and wipes any in-progress text selection.

### 18. A two-tap confirm button is already armed when you re-open the overlay

**Symptom.** Open a destructive overlay, and a single click fires the destructive action.

**Cause.** The module-scope arm flag (`let _xArm = false`) was reset only in the response handlers.
Arm → leave the overlay → re-open renders **synchronously** from cached state with the flag still
true, so the button already reads "Confirm?".

**Fix.** Reset the flag in the overlay's `openMenuOverlay` open branch as well. The clan branch does
`_clanDisbandArm = false` on open; every such guard needs the same.

### 19. A new character is invisible in char-select but appears in Mastery

**Symptom.** The character is in `roster.json` and everything looks registered, but the char-select
grid does not show them.

**Cause.** `gridArea()` filters `roster` by `CHAR_SELECT_SET` — a **hardcoded `CHAR_SELECT_ORDER`
array in `app.js`**, present in *both* the `webclient/app/` and `deploy/` trees.

**Fix.** Add the character there too — and **inside their own universe's contiguous block**, not
appended at the end. Both `CHAR_SELECT_ORDER` and `char_name_list()` are grouped by universe:
indices 0..N are the one-per-universe `starter_squads()` leaders, then every remaining character sits
with the rest of their universe. Owner asked for this explicitly 2026-07-28. Reordering
`char_name_list` is safe — its only consumers are membership pools, nothing persists an index.

---

## Data, registration and text

### 20. Editing `describe()` changes nothing the player sees

**Symptom.** The `.gd` says the new wording. The client shows the old one.

**Cause.** The client reads static JSON, none of it auto-synced to the `.gd`.
`webclient/app/ability_info.json` is **the only ability file the client fetches** — a merge of
`abilities_data.json` (name/description/classes/cooldown/cost) plus `ability_split.json` (`desc`). The
client displays `desc` (the coloured segments) and falls back to `description` only when `desc` is
empty — which never happens for a real ability.

**Fix.** The full recipe is in [[Changing Ability Text]]. In short: edit `describe()` **and**
`split_desc()`, regenerate `ability_split.json` with `extract_split_desc.gd`, patch the changed
entries' `desc` in `ability_info.json`, and `cp` both to `deploy/`. `abilities_data.json` is **not**
deployed.

> [!info] Effect tooltips are a different, live path
> An `Effect`'s `description` is baked server-side per snapshot in `_serialize_wire_effect`, so
> changing one means editing only the `.gd` — no JSON regen, no deploy copy.

### 21. A `class_name` written outside the Godot editor does not resolve

**Symptom.** `Parse Error: Identifier "Foo" not declared in the current scope`, even though the file
compiles fine on its own.

**Cause.** The global class registry lives in `.godot/global_script_class_cache.cfg` and is only
updated when the editor scans the project.

**Fix.** `godot --headless --import`, then confirm with
`grep '"Foo"' .godot/global_script_class_cache.cfg`. Hit while adding `class_name Campaign`.

### 22. Ability icons look fine in the browser but effect tooltips show a blank grey square

**Symptom.** Sneaky and asymmetric: the client renders the art, the server does not.

**Cause.** The art was **WebP renamed to `.png`** (`RIFF….WEBPVP8L` magic, not `\x89PNG`). Browsers
sniff and render it; Godot's importer decodes `.png` as PNG, chokes, and leaves the `.import` with
`valid=false` and no `[remap] path=` — so the server's `load(image_path)` throws
`No loader found for resource:`.

**Fix.** Re-encode to genuine PNG (WebP-lossless → PNG is lossless), delete the bad `.png.import` and
`.godot/imported/<name>.ctex`, re-run `--import`, and confirm the `.import` gained
`path="res://.godot/imported/….ctex"`.

### 23. `Expected closing "}" after dictionary elements` after adding a Nexus concept

**Cause.** Both dictionaries in `components/bucket_handler.gd` end their last entry **without** a
trailing comma.

**Fix.** Add the comma to the old last line. And a new `CharacterConcept.Universe` value goes at the
**very end, after `CUSTOM`** — ordinals are persisted into `bucket data/<path>.dat`, so inserting
above `CUSTOM` renumbers it. A new universe is also **two** edits: the enum *and* the per-universe
empty-bucket dict in `bucket_handler.gd`; miss the second and boot throws
`Invalid access to key '<new_index>' on a base object of type 'Dictionary'`.

### 24. "Gain a random energy" silently gives nothing

**Cause.** `RANDOM` is a **cost token, not a storable colour**. `EnergyPool.change_energy(RANDOM, …)`
`push_error`s and no-ops.

**Fix.** `character.gain_random_energy()` (rolls `battle.roll(0,3)` → a real colour, +1).
`gain_bonus_energy(<0-3>)` is only for a specific colour. Cost dict keys are the `Energy.Type`
ordinals: **0=GREEN, 1=BLUE, 2=WHITE, 3=RED, 4=RANDOM**. See [[Cooldowns and Energy]].

### 25. "`<Class>` skills cost more" applies to everything

**Cause.** `cost_mod_effect(mag, dur, Energy.Type.X, targets)` matches `targets` by ability **NAME**,
not by class — `if ability_name in effect.ability_targets`
(`abilities/scripts/ability_component.gd:308`) — and an **empty** targets array means ALL skills.

**Fix.** Collect the target's class-matching ability *names* first (the `adam1.gd` idiom) and guard
`if not names.is_empty()`.

### 26. A reflected AoE does nothing

**Cause.** The re-aim was gated on `ALL_FACTION` — but the common "hit all enemies" AoE is
**`ALL` (TargetType index 2, 107+ harmful abilities)**, not `ALL_FACTION` (index 1, only 11). The
first pass missed ~90% of AoEs.

**Fix.** The condition is `bounce_to_user and tt != SINGLE and tt != SELF`. Validity must mirror
`Condition.can_hostile_target` minus is_hostile — alive, `Condition.extra_targetable`, and
not-invuln-unless-bypassing. A bare `is_invuln` check is wrong twice over: it skips `extra_targetable`
and it is bypass-blind. Fall back to `[attacker]` when nothing is valid, since an empty targeter
crashes abilities that dereference `targets[0]`.

---

## Server, ops and harnesses

### 27. GDScript runtime errors LOG AND CONTINUE

**Symptom.** No crash, no failed assertion — just a passive that quietly stopped working, and stderr
filling with the same message every turn.

**Cause.** A null dereference in GDScript does not abort the function.

**Fix.** **A probe cannot self-assert this class of bug.** The regression signal is grepping stderr
for the message. Any "did it work?" check based only on return values passes against broken code.
Measured, not assumed.

### 28. An admin ejects themselves during maintenance, irreversibly

**Symptom.** The eject step throws the admin to the login screen, where the admin panel — and with it
the Cancel button — is hidden.

**Cause.** **Two peer-id namespaces.** `sessions[*].peer_id` is a **logical** id
(`JSON_PEER_BASE = 1000000000` + gateway id, `components/server_connection.gd:109`), while
`json_gateway` keys its peers by the **raw gateway id**. Excluding the logical id from
`broadcast_except` matched nothing and quietly ejected the admin anyway.

**Fix.** Convert with `_json_local()` (`components/server_connection.gd:712`). The comment at
`server_connection.gd:367` records exactly this. Two namespaces that are both plain ints fail
*silently* — no type error, just an empty match.

### 29. Ejected players take a real ranked loss

**Cause.** The eject only broadcast. An ejected player simply stops taking turns and the **AFK timer
forfeits them**; anyone inside their 120s reconnect grace is surrendered by `wipe_session` when the
login lock refuses their re-login.

**Fix.** `_maintenance_stand_down()` must do server-side work: **cancel every live match**
(`Match.cancel_match`, a no-contest) and **empty every queue**, or the matchmaker seats somebody into
a brand-new match seconds before the process dies. See [[Season Reset and Maintenance]].

### 30. Editing `ausers/*.dat` under a running server does nothing

**Cause.** `initialize_players()` loads *every* account into the `players` cache at boot, and that
cache is what fresh-login session creation and `resave_player` read from. A file edit is silently
reverted the moment that player logs in or is resaved for any reason.

**Fix.** Use the server op (`admin_season_reset`), which mutates the live `Player` objects and the
files in one pass. A file script is only safe with the server **fully stopped** — and confirm no
`godot` process survives first.

> [!danger] The corruption goes both ways
> A `resave_player` from a longer-lived in-memory `Player` can write progress the file on disk never
> had. Observed 2026-07-29: two accounts came back with ~12 more matches, more AP and a different
> rating than a snapshot taken earlier the same session. **A mid-session snapshot is not ground
> truth** — never blind-restore one over live saves.

### 31. A WebSocket harness reads a stale pushed message

**Symptom.** A post-match clan record reads back as the pre-match 0-0. The server is correct.

**Cause.** `waitFor(type)` returns the **first queued** message of that type, and several types are
also pushed **unsolicited** — `clan_state` (on create, invite, accept), `receive_player_update`,
`player_profile`. They pile up, so a `waitFor` after a request returns an older push.

**Fix.** Drain that type immediately before the request:
`c.q = c.q.filter(m => m.type !== "clan_state")`. This cost ~30 minutes chasing a non-existent server
bug.

### 32. `file://` pages render as static snapshots

**Symptom.** Client edits appear to have no effect.

**Cause.** Re-navigating a `file://` URL does not pick up changes to `app.js` / `style.css`.

**Fix.** Serve over HTTP from the **repo root** and navigate to localhost. Note also that the in-app
Browser pane **cannot open `ws://127.0.0.1:5695`**, so a full UI match against the local gateway is
not possible there — use `webclient/app/tests.html` for client logic and a Node harness for the wire.

### 33. `godot --headless --import` "passes" on a file with a parse error

**Cause.** `--import` does not compile scripts nothing loads.

**Fix.** `godot --headless --check-only --script res://path.gd` per new file — remembering that
scripts reaching the `GlobalPlayerSettings` autoload chain false-fail that check, and must be
validated by running the scene.

### 34. A `.ps1` file produces cascading parse errors far from the real site

**Cause.** Windows PowerShell 5.1 reading BOM-less UTF-8 decodes an **em-dash inside a double-quoted
string** as a smart quote (U+201D) that **terminates the string**.

**Fix.** Keep `.ps1` files strictly ASCII. Two neighbours in the same family: `2>&1` on a native exe
under `ErrorActionPreference = Stop` turns the first benign stderr line into a terminating error; and
**never name a parameter `-Matches`** — `$Matches` is the automatic regex-capture variable and
`-match` clobbers it mid-loop (hit twice in one session; the parameter is now `-MatchesPerWorker`).
`[Math]::Max(0, x)` also binds the *int* overload and rounds a double bound — use `0.0` / `1.0`, or
every confidence interval prints `[0%, 100%]`.

---

## Related

- [[Verification Playbook]] — the loop designed to catch these
- [[Hard Rules and Guardrails]] — the traps promoted to absolutes
- [[The Turn Pipeline]], [[Effects and Durations]], [[Trigger Types]] — the systems most of these live in
- [[Node Lifecycle and Orphans]], [[Cleanse Silence and Effect Removal]], [[Targeting and Main Target]]
