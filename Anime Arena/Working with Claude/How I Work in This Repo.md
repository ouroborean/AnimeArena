---
tags: [area/process, type/howto]
---

# How I Work in This Repo

The working loop the assistant follows here, and why each step exists. This is descriptive, not
aspirational — every habit below exists because skipping it produced a specific failure recorded in
[[Traps That Have Bitten Us]].

## Orientation before code

Four sources rank above my own reading of any single file:

| Source | What it is good for |
| --- | --- |
| The engineering memory (`~/.claude/projects/.../memory/`, 47 topic notes + `MEMORY.md`) | Behaviour that was *measured*, not inferred. Almost every note exists because an assumption was wrong. |
| `CODEBASE_CHEATSHEET.md` | Where things live. |
| `ABILITY_AUTHORING_COOKBOOK.md` | The idioms for writing a skill — counter, reflect, swap, DoT. |
| `MATCH_PROTOCOL.md` | The wire contract between server and client. |

`LOCAL_TESTING.md` documents the run loop: `run-local.ps1` launches the headless Godot server
(gateway on `ws://localhost:5695`) plus a static file server rooted at the **repo root**, and opens
`http://localhost:8777/webclient/app/index.html`. Serving from `webclient/app/` instead of the repo
root breaks image loading, because the client fetches JSON from `/webclient/app/…` and art from
`/assets/images/…` and needs both on one origin.

> [!tip] Read the memory note before reading the code
> The code tells you what happens. The memory note tells you what happened when someone assumed the
> obvious thing. For anything turn-scoped, `ticking-first-instance` and `effect-duration-model` are
> worth more than an hour in `battle_manager.gd`.

## The shape of a task

Nearly every substantial piece of work in this repo decomposes the same way, because the codebase has
a server half, a client half and a mirror:

1. **Recon.** Grep for an existing precedent. Almost nothing here is genuinely novel — there is
   usually a shipped ability, an existing admin op, or an existing overlay that already solves the
   structural problem. Precedents cited by memory: `abilities/squalo1.gd` and `abilities/genos3.gd`
   for a manual first DoT instance, `abilities/adam2.gd` for the retaliate-counter idiom,
   `abilities/death5.gd` for permanent passive machinery, `abilities/squalo2.gd` /
   `abilities/semiramis3.gd` for shield teardown.
2. **A written plan** for anything multi-phase (campaign mode, bot training v3, the block DSL all got
   one in `.claude/plans/`). Phases get tracked as tasks so the work survives a context reset.
3. **Server first, then client, then the deploy mirror.** Engine changes land before the data that
   describes them; client JSON is authored last because it is derived from the `.gd`.
4. **Verify in the order given in [[Verification Playbook]]** — and treat "it compiles" as step one
   of seven, not as done.
5. **Adversarial review** as a separate pass with a different posture (see below).

## Editing discipline

- **Files are edited in place.** Git is read-only here — see [[Hard Rules and Guardrails]]. Syncing
  the client to `deploy/` is `cp`, or a full rebuild with `build-pages-deploy.ps1` (which does a
  clean `Remove-Item -Recurse` of `deploy/` and re-copies `webclient/app` minus `tests.html`,
  `aa-tests.js`, `aa-test-harness.js`).
- **Data files are edited as raw text, not parsed and re-emitted.** `abilities_data.json` is CRLF
  with mixed tab/2-space indent; a `json.load`/`json.dump` round-trip reformats the entire file. The
  same applies to `roster.json`, `char_index.json` and `character_colors.json`, which each have their
  own committed formatting. Details and the exact per-file conventions are in
  [[Data Files and the Deploy Mirror]].
- **Temporary work goes in the scratchpad**, never in the repo. Probe scripts that are meant to stay
  become `training/tests/<name>_probe.gd` + `.tscn`; one-off WebSocket harnesses stay as
  `scratchpad/*.mjs`.
- **Uncertain claims get verified or dropped.** If a file:line cannot be confirmed, it does not go in
  a note, a commit message or a summary.

## What I write down, and where

Two different artefacts, deliberately kept apart:

- **Memory notes** record a *lesson* — a measured behaviour, a rule the owner set, a mistake and its
  fix. They are written after the work, not during, and they are the reason a trap is only paid for
  once. `MEMORY.md` is the index; a note that is not in the index effectively does not exist.
- **This vault** records the *system* — how the pieces fit, for someone new. It is distilled from the
  memory notes and the code, not from recollection.

Owner corrections are recorded verbatim in memory when they set policy, because they are not
recoverable from the code. Examples that changed the default behaviour permanently:

- new characters default **locked** (`gate: "<path>_unlock"`) — corrected on Levi, 2026-07-05;
- playable characters do **not** belong in the Nexus bucket handler — corrected 2026-07-15;
- `TICKING_TRIGGER`, not `START_OF_TURN_TRIGGER`, is the convention for "each turn" — corrected
  2026-07-28;
- only genuinely hidden information should be hidden from a player — 2026-07-28, which is what
  produced `Effect.display_system`;
- a new character is inserted **inside their own universe's block** in `CHAR_SELECT_ORDER` and
  `char_name_list()`, not appended at the end — 2026-07-28.

## Adversarial review

The last phase of any nontrivial change is a review pass run as a genuinely separate exercise, not a
re-read:

1. **Independent finders** go looking for defects with no knowledge of what the implementer believed
   was safe.
2. **A verifier** whose job is to *refute* each finding — reproduce it against the real engine or
   demonstrate it cannot happen.
3. **Confirmed vs refuted is reported honestly.** On the maintenance/update flow, 24 findings came
   back and **12 were confirmed** and fixed; the other 12 did not survive verification. Reporting 24
   fixes would have been a lie, and reporting 12 findings would have hidden the review's cost.

This pass has caught things nothing else did: the permanent-machinery `remove_on_death` omission on
Stark and Fern (four effects, all with `system = true` and nothing else), the two-tap arm flag that
stayed armed across an overlay re-open, and the chat log's ring-buffer freeze.

## Naming and placement conventions

Where a thing goes is not arbitrary — it determines whether the next session finds it.

| Artefact | Location | Convention |
| --- | --- | --- |
| A regression test for the engine | `training/tests/<name>_probe.gd` + `.tscn` | The `.gd` opens with a comment block stating **the bug this locks** — `cooldown_paralyze_probe.gd` cites `battle_manager.gd:1190` vs `:1206` in its header |
| A client-logic test | `webclient/app/aa-tests.js` | Named as a sentence describing the invariant, e.g. `battle: an AoE sends the CLICKED target first (it becomes the server's main_target)` |
| A one-off wire harness | `scratchpad/*.mjs` | Disposable; `ZZ_`-prefixed accounts only |
| A multi-phase design | `.claude/plans/<topic>.md` | Written before the first phase, not after |
| A durable lesson | a memory note + an `MEMORY.md` index line | Written after the work |

A probe whose header does not say what bug it locks is a probe nobody will trust enough to keep
green. The header is the difference between "this failed, so something is wrong" and "this failed, so
the cooldown +1 is being stranded again".

## The deploy path

Client changes are not live until they reach `deploy/`, which is the Cloudflare Pages upload root.
Two ways:

```bash
cp webclient/app/app.js deploy/app.js          # targeted, for a single file
```

```powershell
.\build-pages-deploy.ps1                        # clean rebuild of deploy/
```

The rebuild deletes `deploy/` outright, re-copies every file from `webclient/app` except
`tests.html`, `aa-tests.js`, `aa-test-harness.js` and `roster.json.bak`, mounts `assets/{images,
avatars, backgrounds, bounty, cosmetics, videos, sounds}` under `deploy/assets/`, and strips Godot
`*.import` sidecars. Server-side data — `abilities_data.json` above all — is **not** deployed.

## What I decide, and what I ask about

Decided without asking: implementation approach, which precedent to copy, effect durations derived
from the ×2 rule, where a probe goes, how to structure a refactor.

Asked about, every time:

- **Anything that writes the working tree via git.** See [[Hard Rules and Guardrails]].
- **Anything that touches live accounts** beyond a `ZZ_` throwaway.
- **Balance intent.** "Should this heal 5 or 10" is a design question, not an engineering one.
- **Scope creep into known-deferred items.** The legacy account-safety holes and the four abilities
  that hard-set another ability's `cooldown_remaining` are documented and deliberately untouched.
- **Anything whose failure mode is irreversible** — a season reset, a maintenance eject, a Nexus
  round close. These have two-step confirmations in the product for the same reason.

## Working with the live server

- The server is **stateful in memory**. `initialize_players()` loads every account into a `players`
  cache at boot, and that cache — not the file — is what a login or a `resave_player` reads. So a
  script that edits `ausers/*.dat` under a running server is silently reverted. Anything that touches
  accounts goes through a server op (see [[Season Reset and Maintenance]]).
- **Peer ids live in two namespaces.** `sessions[*].peer_id` is a *logical* id
  (`JSON_PEER_BASE = 1000000000` + gateway id, `components/server_connection.gd:109`); the gateway
  keys its own peers by the raw gateway id. Converting between them is `_json_local()`
  (`components/server_connection.gd:712`). Mixing them fails silently — matching nothing rather than
  erroring.
- **Restarting the process is the reset.** Maintenance state is in-memory and `boot_id` is
  regenerated every launch, which is exactly the signal clients poll for.

## Tooling notes that cost time to learn

- `godot --headless --import` regenerates the class cache and the texture imports — but it does
  **not** compile scripts that nothing loads. A parse error in a brand-new file survives it silently.
- `--check-only --script res://path.gd` compiles a single file, but scripts that reach the
  `GlobalPlayerSettings` autoload chain false-fail it, because `--script` mode has no autoloads.
- Headless probes that need autoloads must run as a **scene** (`godot --headless res://…​.tscn`), not
  as `--script`. `BattleManager` is in this category.
- `.ps1` files must stay strictly ASCII. Under Windows PowerShell 5.1 reading BOM-less UTF-8, an
  em-dash inside a double-quoted string decodes to U+201D and *terminates the string*, producing
  cascading parse errors far from the real site.
- Never name a PowerShell parameter `-Matches`: `$Matches` is the automatic regex-capture variable
  and `-match` clobbers it mid-loop. (Hit twice in one session; the parameter is now
  `-MatchesPerWorker`.)

## Related

- [[Hard Rules and Guardrails]] — the absolutes this loop is built around
- [[Verification Playbook]] — the seven-step verification order
- [[Traps That Have Bitten Us]] — the field guide
- [[System Overview]], [[Server Authority Model]] — what the loop operates on
