---
tags: [area/process, type/howto]
---

# Verification Playbook

The order matters. Each step catches a class of defect the previous one structurally cannot, and
running them out of order wastes the expensive ones on problems the cheap ones would have found.

Steps 1–3 are the core loop. **Step 3 is the one that actually decides whether the work is real.**

## 1. Compile

```bash
godot --headless --import
```

Regenerates `.godot/global_script_class_cache.cfg` and the texture imports, and surfaces parse errors
in scripts that something loads.

> [!warning] Trap — `--import` does not compile unloaded scripts
> A parse error in a brand-new file that nothing references yet survives `--import` **silently**.
> This cost a 30-minute hang chasing a runtime symptom. To compile a specific new file:
> `godot --headless --check-only --script res://path/to/file.gd`.

> [!warning] Trap — `--check-only --script` has no autoloads
> Scripts that reach the `GlobalPlayerSettings` autoload chain false-fail the per-file check. That is
> a known false positive, not a defect. To validate a whole-project compile *with* autoloads:
> `godot --headless --editor --quit-after 300`, then grep stderr for
> `SCRIPT ERROR|Parse Error|Compile Error`.

A new `class_name` written outside the Godot editor is a special case: other scripts fail with
`Parse Error: Identifier "Foo" not declared in the current scope` until `--import` regenerates the
class cache. Confirm with `grep '"Foo"' .godot/global_script_class_cache.cfg`.

## 2. A headless probe driving the REAL engine

Probes live in `training/tests/` as a `.gd` plus a `.tscn`, run with:

```bash
godot --headless --path . res://training/tests/<name>_probe.tscn
```

**A scene, not `--script`.** `BattleManager` (`new multiplayer/battle_manager.gd`) references the
`GlobalPlayerSettings` autoload, so under `--script` it fails to compile and `BattleManager.new()`
reports `Nonexistent function 'new'`. A scene loads autoloads; the server does not auto-start.

**Never a mock.** The simpler `scripts/battle.gd` exists and is `--script`-testable, but it lacks
`log_damage` / `log_*`, so damage aborts against it — and more importantly a mock cannot reproduce
the ordering bugs that are the whole reason to test. Set up a real `BattleManager` by hand instead of
calling `start_battle` (which blocks headless for bot matches):

```gdscript
bm.player = ...; bm.enemy = ...          # add_child each
bm.match_type = BattleManager.MatchType.BOT
bm.passive = false
bm.die.set_seed(n)                        # all gameplay RNG is this one generator
for c in bm.all_characters():
    c.initialize(true); c.startup(bm); c.startup_passives(bm)
```

Seeding matters: the whole sim funnels randomness through `battle_manager.gd`'s `die` / `roll()`,
and Godot 4's `RandomNumberGenerator` is PCG32 and bit-reproducible — so a seeded probe is exactly
repeatable.

### Probe traps

> [!danger] The ticking queue is built at TURN START
> A probe that casts a skill and then gathers ticks *for the same side* manufactures a phantom
> same-turn tick that no real match can produce. End the cast turn with a bare `start_round_loop()`
> (no gather), then emulate turns normally.

> [!danger] `end_of_turn_effect_handling()` crosses two turns
> It ends the turn **and** fires the *next* turn's start-of-turn triggers. Sampling HP after it
> attributes a heal to the wrong turn — that exact mistake made a broken Stark regen look correct.
> Walk one boundary at a time, print the acting side and the effect durations at each step, and
> assert the **offsets**, not the count.

> [!danger] `queue_free()` is DEFERRED
> Within the casting frame a freed node is still readable, so a use-after-free does not appear. A
> probe must `await get_tree().process_frame` **twice** before it can reproduce
> `Invalid access to property or key '…' on a base object of type 'previously freed'`.

> [!danger] GDScript runtime errors LOG AND CONTINUE
> They do not abort the function. So the symptom of a null dereference is a *dead passive plus stderr
> spam*, not a hard failure — and a probe **cannot self-assert it**. The regression signal is
> grepping stderr for the message. Measured, not assumed.

Shipped probes worth copying:

| Probe | Locks down |
| --- | --- |
| `training/tests/orphan_probe.tscn` | 3 full battle lifecycles; per-battle `OBJECT_ORPHAN_NODE_COUNT` delta. Was +140, now 0; gate is `worst <= 25` (`orphan_probe.gd:76`) |
| `training/tests/cooldown_paralyze_probe.gd` | All four quadrants: Paralyze before / during / absent × used / not used this turn |
| `training/tests/cleanse_wrapup_probe.tscn` | Cleanse fires the same teardown as a shatter (12/12) |
| `training/tests/yubel_lethal_reflect_probe.tscn` | Non-lethal regression + lethal single-target + lethal team-wide + an unarmed control |
| `training/tests/effect_visibility_probe.gd` | Both directions of `system` / `display_system` against the real serializer |
| `training/tests/reflect_aoe_probe.tscn` | `ALL_FACTION` excluding invuln, `ALL` + Bypassing including it, `SINGLE` regression |

Note the pattern in the last three: every one carries a **control** — an unarmed case, a regression
case, a negative direction. A probe with only positive cases cannot distinguish "the fix works" from
"the assertion is vacuous".

## 3. Revert the fix and re-run

> [!danger] A test that passes both with and without the fix is not a test
> This is the step that gets skipped and the step that matters. Put the buggy code back, run the
> probe, and **watch it fail**. Then restore the fix and watch it pass.

This has caught bad tests repeatedly. The failure mode is not exotic — it is the ordinary one:

- **The assertion never reached the changed code.** A probe that sets up an AoE but asserts on total
  damage passes identically whether the primary target is right or wrong. The
  target-order regression test only became a test once reverting produced
  `expected [5,3,4], got [3,4,5]` — the assertion had to read the *order*, not the outcome.
- **The setup silently did not reproduce the condition.** The cancel-effects use-after-free needs two
  frames to pass before the node is actually freed; before that, the probe "passed" against unfixed
  code.
- **The symptom is stderr, not a return value.** Anything relying on a GDScript runtime error must be
  checked by grepping stderr, because the engine logs and continues. A probe asserting a return value
  passes against broken code every time.
- **The measurement point was wrong.** A heal sampled after `end_of_turn_effect_handling()` reads the
  next turn's state, so both the broken and the fixed version produce the "expected" number.

Record what the reverted run printed. "Reverting the fix makes it fail with `<exact message>`" is the
only durable evidence that a regression test is load-bearing.

## 4. A live WebSocket harness

Anything that crosses the wire — a new message type, a queue rule, an admin op, a persistence field —
gets a Node harness in `scratchpad/*.mjs` speaking JSON-over-WebSocket to a **real running server**
(`ws://localhost:5695`). Two clients that `queue_quick` and pair into a real match is the standard
shape; one surrenders so the other wins.

> [!warning] Trap — `waitFor(type)` returns the first *queued* message
> Several message types are also **pushed unsolicited** by the server: `clan_state` (on create,
> invite, accept), `receive_player_update`, `player_profile`. They pile up in the queue, so a
> `waitFor("clan_state")` issued after a request can return a **stale push** instead of the fresh
> reply. This cost ~30 minutes chasing a non-existent server bug — a post-match clan record read back
> as the pre-match 0-0, and the server was correct the whole time.
> Fix: drain that type immediately before the request —
> `c.q = c.q.filter(m => m.type !== "clan_state")`.

For a live match against a real bot, assert the **shape** of an outcome, not raw numbers: bot teams
are random, so a damage split should be checked as "main > splash, splash values equal", never as
`25/10/10`. A bot with flat damage reduction or a guardian redirect shifts every number.

Account safety applies in full here — see [[Hard Rules and Guardrails]]. Every account the harness
creates is `ZZ_`-prefixed, and it is deleted afterwards.

## 5. The browser, including 375px

Anything visible gets checked in a real browser.

> [!warning] Trap — `file://` pages render as static snapshots
> Edits to `app.js` / `style.css` are **not** picked up by re-navigating a `file://` URL. Serve over
> HTTP (a one-line static server from the repo root) and navigate to localhost.

> [!warning] Trap — verify responsive CSS at BOTH widths
> A dropped `}` inside an `@media (max-width:760px)` block traps every later rule inside the query.
> At 375px the trapped rules still apply, so the mobile check passes; the breakage is only visible
> **outside** the media range. This shipped a user-visible regression on 2026-07-20 — the admin FAB
> became a giant blue rectangle on desktop and the chat panel lost all styling.
>
> After any `webclient/app/style.css` edit:
> ```bash
> python -c "s=open('webclient/app/style.css').read(); print(s.count('{')==s.count('}'))"
> ```
> `False` means a block is unclosed and swallowing everything after it.

> [!warning] Trap — the headless preview pane freezes CSS animations
> `visibilityState === "hidden"` freezes the animation clock at frame 0, so a slide-in leaves the
> element stuck at its start transform (a panel looked 10px off). Not a layout bug — force
> `el.getAnimations().forEach(a => a.finish())` and re-measure.

Two more habits:

- **Assert on computed styles, not source inspection.** "The rule is in the file" is not evidence the
  element renders that way. Read `getComputedStyle` values — e.g. badge `rgb(255,59,71)`, border
  `rgb(50,58,82)` after a clear.
- **The in-app Browser pane cannot open `ws://127.0.0.1:5695`**, so a full UI match against the local
  gateway is not possible there. Use `webclient/app/tests.html` (the browser suite in `aa-tests.js`,
  driven headlessly via `window.__AATEST`) for client logic, and the Node harness for the wire.

## 6. Adversarial review

A separate pass, with a different posture from implementation:

1. **Independent finders** look for defects without being told what the implementer believed was
   safe.
2. **A verifier** attempts to *refute* each finding — reproduce it against the real engine, or
   demonstrate it cannot occur.
3. **Confirmed vs refuted is reported honestly.** The maintenance/update flow produced **24 findings,
   12 confirmed**, all fixed. Reporting 24 fixes would have been false; reporting 12 findings would
   have hidden what the review cost.

Review is where the class of defect that no probe was written for gets caught, because the finder is
not working from the implementer's mental model. Confirmed catches include the missing
`remove_on_death = false` on four permanent effects across Stark and Fern (all had `system = true`
and stopped there), the two-tap arm flag that stayed armed across an overlay re-open, and the chat
log freeze at the ring-buffer cap.

## 7. Final gates before saying "done"

| Gate | Check |
| --- | --- |
| **Full probe suite** | Every `training/tests/*_probe.tscn`, not just the new one. Plus a multi-match roster regression (40 matches is the standard sweep) grepped for `SCRIPT ERROR`. |
| **Orphan count** | `orphan_probe.tscn` after anything that instantiates battle objects. Delta ≤ 25 per battle. |
| **Deploy sync** | Every client file touched exists in `deploy/` with identical content. `app.js` is the usual miss. |
| **Account integrity** | Re-fingerprint `ausers/`, confirm byte equality against the pre-session snapshot, and confirm every `ZZ_` account this session created is gone. |
| **stderr is clean** | Grep the server log for `SCRIPT ERROR` / `push_warning`. A runtime error here logs and continues — a green probe run does not mean a clean run. |

> [!info] Reading `OBJECT_ORPHAN_NODE_COUNT` correctly
> It counts every live Node **not in a SceneTree**, not "nodes without a parent" — an out-of-tree
> parent's entire subtree counts. The server keeps every cached `Player` (with their characters,
> abilities and effects) out of tree, so a large baseline is expected. The deployed `orphans=16166`
> is not by itself proof of a leak; the health metric is the **per-battle delta staying flat**.

## Related

- [[How I Work in This Repo]] — where this fits in the loop
- [[Hard Rules and Guardrails]] — the constraints verification runs under
- [[Traps That Have Bitten Us]] — what each step is looking for
- [[The Turn Pipeline]], [[Node Lifecycle and Orphans]] — the systems most probes measure
