---
tags: [area/engine, type/concept]
---

# Node Lifecycle and Orphans

Almost every runtime battle object in this engine is a **Godot `Node`**, not a `RefCounted`. Nodes
are not reference-counted: dropping the last reference to one does not free it, it *orphans* it —
the object stays alive, outside any `SceneTree`, for the lifetime of the process.

On a long-lived headless server that is a slow, total memory leak. The live server reached
**561k objects / 254 in-tree nodes / 478k orphaned nodes after a single active day** before this was
fixed. Trainer exits leaked ~1,200 RIDs and ~2,300 in-use resources per run (now 2 and 7).

## The rule

> [!info] Every runtime battle object must either be
> **(a)** parented into the battle subtree, so match teardown's cascade-free reclaims it, **or**
> **(b)** explicitly `queue_free()`d when it is transient or rejected.

The objects in question:

| Object | Created by | Node? |
| --- | --- | --- |
| Effect | `components/effect_component.tscn` instantiate | yes |
| Ability | `Ability.from_database` → script `.new()` | yes |
| Character | `character/<path>.tscn` instantiate | yes (~10 nodes each) |
| EnergyPool | `components/energypool.tscn` | yes |

## Ownership chain

| Child | Parent | Where |
| --- | --- | --- |
| Character | `TeamComponent` | `scripts/team_component.gd:15-23` (`add_character`, guarded on `get_parent() == null`) |
| Ability | `MovesetComponent` | `scripts/moveset_component.gd:18-37` (`set_base_abilities` / `add_ability`) |
| Effect | the target's `EffectStorage` | `scripts/effect_storage_component.gd:59-65` (`_store_effect`) |
| Copied Ability (SKILL_COPY) | the copying Effect | `scripts/effect_component.gd:585-595` |
| replacement EnergyPool | `TeamComponent` | `scripts/team_component.gd:46-54` |

```gdscript
func _store_effect(effect: Effect, prepend: bool):
	if prepend:
		_effects.insert(0, effect)
	else:
		_effects.append(effect)
	if effect.get_parent() == null:
		add_child(effect)
```

An **erased** effect keeps its parent. That is deliberate and bounded per match: the
restore-on-removal pattern re-adds the *same* Node, and both the parent guard above and the
`is_connected` guards in `add_effect` (`:27-30`) make re-adding safe.

## Frees

```gdscript
## Free every per-match Character instance along with the roster array. A bare
## `characters.clear()` (the old idiom at match build) leaked all six character
## subtrees of the previous match, every match.
func clear_characters():
	for character in characters:
		if is_instance_valid(character):
			character.queue_free()
	characters.clear()
```

`scripts/team_component.gd:40-44`. `Match.from_players` uses it; `remove_character` (`:31-35`) frees
too; `reset_energy_pool` / `instantiate_energy_pool` free the old pool and `add_child` the new one.

**Rejected effects** are freed centrally by `Character._free_unapplied_effect`
(`scripts/character_component.gd:2107-2109`), called from `apply_effect`'s bails and from the
`add_allied_effect` / `add_hostile_effect` gates:

```gdscript
static func _free_unapplied_effect(effect):
	if effect != null and is_instance_valid(effect) and effect.get_parent() == null:
		effect.queue_free()
```

The `get_parent() == null` check is what stops a *re-application* of an already-stored effect from
freeing the live node.

**Merged effects** are freed by the stack-merge branch of `add_effect`
(`scripts/effect_storage_component.gd:34-44`) — the incoming node contributes its magnitude and
stacks to the existing effect and is then stored nowhere. That was one orphan per stack application.

**Transient roster reads** free their instances:

- `CharacterDatabase.by_universe` (`scripts/character_database.gd:250-262`) instantiates the *entire*
  roster (~226 scene subtrees, 2000+ nodes) just to read `path_name` and `universe` — it frees every
  instance, or each bounty generation leaked all of them.
- `scripts/bounty.gd:328` and `:339`.
- The disguise-portrait read (`scripts/character_component.gd:323-326`): the returned `Texture2D` is
  refcounted, so the Character node can be freed before returning it.

## queue_free, never free

> [!danger] Never do this
> Do not call `free()` on a battle Node. Abilities routinely write fields on an Effect *after*
> `Character.add_*_effect` returns, in the same frame — `orihime3` assigns `wrapup_func` post-add. An
> immediate `free()` turns that into a use-after-free.

`queue_free()` is **deferred**: the node is freed at the end of the frame. A freed-this-frame node is
still perfectly readable, which is why one whole class of bug **only shows up a turn later**.

### The cancel_effects use-after-free

The ~17 channel/control abilities (`kitara1`, `genos3`, `gogeta1`, `gray6`, `korra8`, `maka3`,
`madoka2`, `nonon3`, `sakura2`, `shiro4`, `tanjiro2`, `cell6`, `machinedramon3`, …) all
`cancels.append(eff)` and *then* apply it. Two ordinary outcomes free that exact node:

- the application is **rejected** (target Invulnerable / dead / ignoring the skill) →
  `_free_unapplied_effect`;
- it **merges** into an existing stack → `effect_storage_component` frees the incoming node.

Either way the cancel list keeps a dangling reference and reading `.removed` off it raises
`Invalid access to property or key 'removed' on a base object of type 'previously freed'`. Fixed once,
engine-side, for every ability (`scripts/character_component.gd:263-269`):

```gdscript
func _end_cancel_effects(cancel) -> void:
	for eff in cancel.cancel_effects:
		if not is_instance_valid(eff) or eff.is_queued_for_deletion():
			continue   # never stored (rejected or merged) — there is nothing live to end
		if eff.removed:
			continue
		eff.end_effect()
```

Guarded at all three iteration sites (`check_cancels` ×2 at `:275-282`, `cancel_channels`).
`is_queued_for_deletion()` covers the same-frame case, where the node is still valid but already
doomed.

> [!warning] Trap
> A probe cannot reproduce this without `await get_tree().process_frame` **twice** after the casting
> frame. Within the casting frame the node is still readable and the fault does not appear at all.

## Reading the orphan counter

> [!warning] Trap
> `Performance.OBJECT_ORPHAN_NODE_COUNT` counts **every live Node not in a SceneTree** — not "nodes
> without a parent". An out-of-tree parent drags its whole subtree into the count. The server keeps
> every cached `Player` (with their characters, abilities and effects) out of tree, so a **large
> baseline is expected**: the deployed `orphans=16166` is not by itself evidence of a leak.

The health metric is the **delta per battle**, not the absolute number.
`training/tests/orphan_probe.gd` plays three full battle lifecycles (build → 12 bot turns → teardown →
4 settle frames) and reports the delta each time:

```gdscript
func orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
```

Pre-fix it was **+140/battle**; post-fix **0**. The gate is `worst <= 25`
(`training/tests/orphan_probe.gd:76`).

```bash
godot --headless --path <repo> res://training/tests/orphan_probe.tscn
```

Run it after any change that instantiates battle objects. See [[Verification Playbook]].

Parentless `queue_free()` was probe-tested on Godot 4.6.2 and frees reliably one frame later, so
option (b) of the rule is genuinely sufficient — you do not have to parent something just to free it.

## Why parenting everything was safe

Two facts were verified before the change:

- Every battle-component `_ready()` is a bare `pass`, and none of them use `@onready` — entering the
  tree changes no behaviour. (`TargeterComponent`, `MovesetComponent`, `EffectStorageComponent`,
  `TeamComponent`, `EnergyPool` all have the empty `_ready`.)
- The empty `_process(delta): pass` definitions now actually run for in-tree battle nodes. Negligible,
  but it is a real behavioural difference.

> [!info]
> In-tree node counts **during** a match are now higher than before the fix — effects, abilities and
> characters genuinely live in the tree. That is expected and is not the metric. Watch the orphan
> delta.

## Known-deferred

- Session logout does not free the persistent `Player` node. Bounded at one per login, and risky to
  free while a match may still reference it.
- Effects created by an ability but never routed through the `add_*_effect` gates (rare, negligible).

Related: [[Effects and Durations]], [[Cleanse Silence and Effect Removal]],
[[The Turn Pipeline]], [[Server Authority Model]], [[Traps That Have Bitten Us]],
[[Verification Playbook]].
