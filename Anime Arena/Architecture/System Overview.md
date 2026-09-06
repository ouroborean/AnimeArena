---
tags: [area/architecture, type/concept]
---

# System Overview

Anime Arena is a turn-based 3v3 anime fighting game. Two processes, two deploy targets, one
authoritative simulation:

| | What | Language | Where it runs | How it ships |
|---|---|---|---|---|
| **Server** | `web_anime_server.x86_64` — headless Godot 4.6 | GDScript | a GCP box (`35.208.245.67`), behind nginx | `scp` by `deploy.ps1` |
| **Client** | `webclient/app/` — 3 files, no build step | vanilla JS | the player's browser | Cloudflare Pages from `deploy/` |

They speak **JSON text frames over one WebSocket** on port 5695. That's the entire interface.

> [!info] Godot is a server, not a game engine here
> There was a Godot desktop client. It was deleted on 2026-07-26. `root.gd:9` now forks on
> `DisplayServer.get_name() == "headless"` and the non-headless branch just prints
> "Anime Arena is server-only". The legacy Godot high-level-multiplayer RPC listener on port 5696 —
> ~80 `@rpc("any_peer")` handlers — is gone too (`components/server_connection.gd:690`). Do not spend
> effort preserving desktop or RPC parity; the browser is the only peer that exists.

## Boot path

```
root.gd _ready()
  └── server_root.tscn (ServerConnection + BucketHandler only)
        └── ServerConnection.actually_start_server()      # server_connection.gd:690
              ├── _load_server_flags()
              └── _start_json_gateway()                    # :701
                    └── JsonGateway.listen(5695)
```

`webclient/json_gateway.gd` is **transport only** — accept TCP, complete the WS handshake, parse
inbound text frames as JSON objects, emit `message_received(peer_id, msg)`. It knows nothing about
the game. Everything above it hangs off one `match msg.type` dispatch in
`ServerConnection._on_json_message` (`server_connection.gd:730`).

`components/server_connection.gd` is the god object — 5.5k lines covering sessions, login,
matchmaking, chat, clans, the Nexus, campaign intents, admin ops, replays, and spectating. When you
are looking for "where does the server handle X", the answer is almost always a case in that match
block. See [[Server Authority Model]] for how it decides what to trust.

## The battle stack

```
Match (components/match.gd)              # one per live game: seats, timer, draft, validation
 └── BattleManager  shadow_mode = true   # new multiplayer/battle_manager.gd — the simulation
       ├── Player (p1) ── TeamComponent ── Character ×3
       │                                    ├── MovesetComponent ── Ability ×N
       │                                    └── EffectStorage    ── Effect ×N
       └── Player (p2) ── …
```

`Match.begin_match()` (`components/match.gd:195`) instantiates the `BattleManager`, sets
`shadow_mode = true`, attaches a `MatchEventRecorder`, and calls `start_battle`. This shadow is the
*only* place game logic runs. The browser renders what it is told — see
[[Server Authority Model]].

> [!warning] Trap
> Effects, Abilities and Characters are **Nodes**, not `RefCounted`. Dropping the last reference
> leaks them as orphans forever; the live server once hit 478k orphaned nodes in a day. Every runtime
> battle object must be parented into the battle subtree or explicitly `queue_free()`d. Details in
> [[Node Lifecycle and Orphans]].

## Abilities are code, not data (mostly)

There are 1,020 ability scripts in `abilities/` — one `.gd` per skill, e.g. `abilities/frieza2.gd` —
backing 1,090 entries in `abilities_data.json`, across 174 roster characters. Each extends `Ability`
and overrides `execute()`, `target()`, `describe()`, `split_desc()`, `extra_usable()`,
`custom_behavior()`. Static properties (cost, cooldown, classes, target type, image path) live in
`abilities_data.json` and are loaded at runtime by `Ability.from_database`.

A parallel **block authoring** system lets players compose abilities as validated JSON block trees,
run by `ScriptedAbility` through the same engine primitives — data-never-code, forced by the fact
that players write it. That's why the engine primitives are shaped the way they are.

## What lives where

| Path | Contents |
|---|---|
| `abilities/` | ~900 ability scripts |
| `character/` | one `.gd` + `.tscn` per playable character |
| `scripts/` | engine components — `character_component.gd`, `effect_component.gd`, `moveset_component.gd`, `targeter_component.gd`, `player_component.gd`, `bounty.gd`, `campaign.gd` |
| `components/` | server-side systems — `server_connection.gd`, `match.gd`, `bucket_handler.gd`, `stats_db.gd`, `clan.gd`, replay + event recorder |
| `new multiplayer/` | `battle_manager.gd` — the simulation (the folder name is historical) |
| `webclient/` | `json_gateway.gd` + `app/` (the client) |
| `deploy/` | the assembled Cloudflare Pages bundle — see [[Data Files and the Deploy Mirror]] |
| `training/` | the offline bot trainer and its probe tests |
| `ausers/`, `clans/`, `replays/`, `bucket data/` | flat-file persistence |
| `stats.db`, `mastery.db` | SQLite (via `libgdsqlite`) |

## Determinism

Every gameplay roll funnels through one seeded generator: `BattleManager.die` and
`roll(min, max, desc)` (`new multiplayer/battle_manager.gd:1884`). The match seed is agreed at
match creation and even decides who acts first (`match.gd:129` — a `RandomNumberGenerator` seeded
with the match seed, so both sides derive the same answer without an extra round-trip).

> [!tip] Godot's RNG is bit-reproducible outside Godot
> Godot 4's `RandomNumberGenerator` is PCG32. Verified by fixture (Godot 4.6.2 vs a JS
> reimplementation, exact match): `set_seed(s)` == canonical
> `pcg32_srandom_r(initstate = s, initseq = 1442695040888963407)` — **not** `state = seed` — and
> `randi_range(from, to)` == `from + rand() % (to - from + 1)`, plain modulo. Fixture for seed
> `12345`: `randi()` → `1321476956, 17539747, 3348728241, …`; `randi_range(0,3)` → `0, 3, 1, 0, …`.
> This means any reimplementation of the engine can be made **bit-identical**, so exact differential
> testing (same seed + same inputs → byte-identical event stream) is achievable.

On a passive client `roll()` returns `0` unconditionally — the client must never source its own
randomness, or the pool fills with phantom GREEN energy and drifts permanently.

## Local development

```bash
# starts headless Godot (gateway ws://localhost:5695) + a python static server at the repo root
./run-local.ps1
# open http://localhost:8777/webclient/app/index.html in two tabs to play a match
```

The client auto-targets `ws://<host>:5695` on any dev origin (localhost, `192.168.*`, `10.*`,
`*.local`) and the hosted `wss://` otherwise — `webclient/app/app.js:38`. A `?ws=<url>` override is
honoured **only** on dev origins so a crafted link can never redirect a production login to a hostile
gateway.

> [!warning] A new `class_name` needs a cache regen
> Writing a `class_name Foo` file outside the Godot editor leaves other scripts failing at load with
> `Identifier "Foo" not declared in the current scope`. The registry is
> `.godot/global_script_class_cache.cfg` and only the editor's project scan writes it. Fix:
> `godot --headless --import`, then confirm `"Foo"` appears in that file. Full-project compile check:
> `godot --headless --editor --quit-after 300`, grepping stderr for `SCRIPT ERROR|Parse Error`.

## Where to go next

- [[The Turn Pipeline]] — the single most load-bearing ordering in the codebase.
- [[Server Authority Model]] — peer ids, validation, and the surprisingly long list of things the
  client *is* trusted for.
- [[Web Client Architecture]] — the `S`/`set()`/`render()` loop.
- [[Data Files and the Deploy Mirror]] — why editing a `.gd` doesn't change what players see.
- Engine internals: [[Effects and Durations]], [[Trigger Types]], [[Damage Pipeline]],
  [[Targeting and Main Target]], [[Cleanse Silence and Effect Removal]],
  [[Cooldowns and Energy]].
- Systems: [[Matchmaking and the Ladder]], [[Bots and Training]], [[Campaign Mode]],
  [[Admin and Live Ops]], [[The Nexus]], [[Social Clans and Chat]].
- Doing the work: [[Adding a Playable Character]], [[Changing Ability Text]],
  [[Adding Nexus Concepts]], [[Season Reset and Maintenance]].
- Working with Claude here: [[How I Work in This Repo]], [[Hard Rules and Guardrails]],
  [[Verification Playbook]], [[Traps That Have Bitten Us]].
- Home: [[Anime Arena]].

## Two repo-level rules

> [!danger] Never do this
> The working tree has a large amount of **uncommitted** work. Never run `git checkout`,
> `git restore`, `git reset`, `git clean`, or `git stash` here. Edit files directly; propagate to the
> deploy bundle with a copy. See [[Hard Rules and Guardrails]].

> [!danger] Never write real usernames into `ausers/`
> A test harness once wrote `mk("Cheshire")` (a hardcoded admin) into the live accounts directory and
> destroyed the account. Harnesses use throwaway `ZZ_`-prefixed names, always.
