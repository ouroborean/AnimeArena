# Anime Arena — Non-Godot Backend Roadmap

**Written:** 2026-08-05 · **Revised:** 2026-08-05 (see the revision note below) · **Scope:** the
non-battle backend only · **Status:** proposal; no server code written, but two of Phase 0's data
tasks are now *done* (§3.3, §3.5).

This document plans the replacement of the headless Godot server (`components/server_connection.gd`,
5 935 lines) with a non-Godot backend. It covers **connection/session, accounts, social, clans,
matchmaking, ladder, economy, campaign, nexus and admin** — and the *boundary* where matches are
handed off.

It deliberately does **not** design:

* **battle execution** (turn resolution, effects, the combat engine), and
* the **new block-based Creator**.

Those two will be designed and built together, later. The most valuable thing this roadmap can do
for them is hand them a clean, well-specified seam. §4 is that seam, and it is the section to read
first if you only read one.

**Companion documents — read these as the specification; this roadmap is the plan, not the contract:**

| Document | Role |
|---|---|
| `WIRE_CONTRACT.md` (920 lines) | The acceptance criteria. 89 inbound / 71 outbound message types, auth levels, rate limits, invariants, persistence format. Every phase below cites it. |
| `wire_contract.json` (schema `anime-arena-wire-contract/1`) | Machine-readable companion. **Used at runtime** — see §2.4. |
| `MATCH_PROTOCOL.md` §2–3 | Battle snapshot/event schemas. Deferred, cross-referenced only. |
| `REFERENCE_DATA_INVENTORY.md` | **New.** The complete data-side inventory — every reference dataset, where it lives, whether it needs Godot, whether it is in sync. It supersedes what §3.3 used to say. |

> ### Revision note — 2026-08-05
>
> The first draft of this document was written while the reference-data inventory stage **crashed**.
> §3.3 was therefore a first-hand inventory taken by reading sources under time pressure, and it was
> **wrong in a way that mattered**: it claimed the character name list and the bounty categories were
> "the only reference data that cannot simply be pointed at". Two follow-up stages have since run — a
> full adversarial data extraction and a dedicated bounty-RNG portability proof — and both contradicted
> that claim. What changed:
>
> 1. **§3.3 is replaced.** There were **15** GDScript-trapped datasets, not two. All 15 are now
>    extracted to `data/`, re-derivable without Godot, and verified against the running engine. The
>    Phase-0 export task is *done*.
> 2. **§3.5 is new** — the *generator pipeline* is itself Godot (`extract_*.gd`), which the first draft
>    did not account for at all. It says what replaces each generator and which single one must stay.
> 3. **§1.1's RNG bullet is corrected.** Bounty generation **is** portable and is now proven bit-exact
>    by two independent non-Godot implementations — but the model this document originally asserted
>    (`randi_range` is `from + rand() % span`) is **incomplete**, and building to it would have
>    scrambled roughly a fifth of every player's bingo card at cutover. See §1.1, Phase 4 and risk 5.
> 4. **Phase 0, Phase 4, §6.4 and §8 are updated** to match. §7.3 is a new table of seven data
>    decisions (D12–D18) the extraction surfaced, and §8.2 gains five new ranked rows (12–16). Risk 5
>    is rewritten and risk 6 is new.
>
> Everything else — the stack recommendation, the migration approach, the cutover shape, the seam, the
> security holes D1–D11 — was re-checked against the new evidence and stands unchanged.

---

## 0. The five facts that shape every decision below

1. **The client is fixed.** `webclient/app/app.js` (6 147 lines) + its byte-identical `deploy/app.js`
   mirror is the only client. The new server serves *it*. Every phase is testable by pointing the
   real client at the new server — that is the whole verification strategy.
2. **The protocol is JSON over one raw WebSocket**, `{type, ...fields}` both directions, no request
   ids, no correlation, responses matched by type alone (`WIRE_CONTRACT.md` §1).
3. **Identity is the socket.** `get_player(peer_id)` → `sessions[peer_map[peer]].player_data`
   (`server_connection.gd:322`). No tokens, no cookies. This is simple and it is *also* the anti-spoof
   cornerstone — every invariant in `WIRE_CONTRACT.md` §3 leans on it.
4. **The scale is small.** 76 accounts (`ausers/*.dat`), 1 clan, 47 replays, 174 characters, one live
   host. This is a correctness problem, not a scaling problem. Choose boring, single-process
   technology.
5. **Battle execution is not in this project.** Therefore *the new server cannot serve production
   until Milestone 2 lands.* That is the dominant constraint on cutover (§6) and the top risk (§8).

---

## 1. Target stack

### 1.1 Recommendation — Node.js LTS + TypeScript, single process, minimal dependencies

```
runtime     Node.js 22 LTS
language    TypeScript, compiled ahead of deploy (tsc), strict mode
websocket   ws              (the de-facto raw-WS server; no framework)
sqlite      better-sqlite3  (synchronous API, WAL — matches current usage exactly)
http        node:http       (health endpoint only; nginx already terminates TLS)
tests       node:test + a hand-written protocol harness (Phase 0, §6.4)
deps        target ≤ 5 direct production dependencies, lockfile committed
```

No web framework, no ORM, no DI container, no message bus. The whole surface is one WebSocket and
some files.

**Why, tied to facts about this specific system:**

* **The protocol and the database are both JSON.** `ausers/<user>.dat` is one line of
  `JSON.stringify(player.save())` (`server_connection.gd:1846-1853`), and every wire frame is a JSON
  object. In JS this is `JSON.parse` and done. GDScript's loose numeric typing has already leaked
  into the data — real saves hold `ap: 25050.0` and `bot_queue_delay: 15.0` (`WIRE_CONTRACT.md` §7.1)
  — and JS's single number type models that with zero conversion decisions. A strictly-typed
  language forces an int/float ruling on every numeric account field before you can read the first
  file.
* **The concurrency model is preserved for free.** The Godot server is a single-threaded frame loop:
  `JsonGateway.poll()` drains every socket in one pass (`webclient/json_gateway.gd:70-114`) and every
  handler runs to completion with no preemption. The entire correctness argument of the existing code
  assumes that — `_release_queues` idempotency, the session/peer maps, the "re-check
  `peer_map[peer] == expected_username` before every match send" guard (`server_connection.gd:3852`).
  Node's event loop reproduces that assumption exactly. A threaded runtime would import a brand-new
  class of race into a rewrite that is already the riskiest thing this project has done.
* **One person + AI assistance, and the client is already JS.** Same language on both sides of the
  socket means one mental model. More concretely: the **new Creator will need the same validation
  logic in two places** — in the browser editor (instant feedback) and on the server (authority).
  In JS that is one module imported twice. In any other stack it is two implementations that must be
  kept in agreement forever, which is precisely the kind of duplication that already bit this
  codebase once (`_calculate_ap_gain` vs the client's `matchApGain()` — `WIRE_CONTRACT.md` F10).
* **Deterministic RNG is portable — now proven, not assumed.** Bounty missions are generated from
  `hash(player+path+rerolls)` fed into Godot's PCG32 (`scripts/bounty.gd:224-240`). This *must*
  reproduce exactly or every player's in-flight bingo card scrambles. A dedicated stage captured
  engine fixtures and wrote **two** independent non-Godot ports (Python and TypeScript) that reproduce
  **347/347 engine-generated cards exactly**, including one card per roster character. JS reproduces
  the primitives with `BigInt`. Artefacts: `backend_port/bounty/`. ⚠ **The exact spec is subtler than
  the sentence this bullet used to contain** — see the box below; getting it wrong is a silent
  data-corruption bug, not a crash. (Phase 4 still owns the decisive live diff — see §5.)

> #### ⚠ The bit-exact RNG contract (get this wrong and 21 % of bingo cards scramble)
>
> The first draft of this document said `randi_range` is `from + rand() % span`. **That is incomplete
> and building to it is a blocker-class defect.** Godot's `RandomNumberGenerator::randi_range`
> delegates to `RandomPCG::random(int,int)`, which **short-circuits a degenerate range and consumes no
> draw at all**. The correct spec, verified against Godot 4.6.2-stable:
>
> ```
> hash(s)             DJB2: h = 5381; for each CODE POINT c: h = h*33 + c; return h as UNSIGNED u32
>                     (hash('') == 5381, hash('a') == 177670; global hash() == String.hash() for all
>                      19 test strings incl. CJK and a >BMP code point)
> seed = X            canonical pcg32_srandom_r(state = X, initseq = PCG_DEFAULT_INC_64),
>                     multiplier 6364136223846793005; negative seeds wrap into uint64
> randi_range(a, b)   if (b < a) swap(a, b)
>                     if (a == b) return a          // <-- DOES NOT DRAW. This is the trap.
>                     return a + rand() % (b - a + 1)
> ```
>
> `bounty.gd` hits the degenerate case on **every square** for any character with exactly one
> archetype, and on the specific-target branch for any character whose universe holds exactly one
> other member. Modelled the naive way, **96 of 168** fixture cards and **37 of 174** roster cards come
> out wrong — a wrong card for 37 of the 174 roster characters, silently, with no error anywhere.
>
> Two more input-side traps, both proven, both easy to get backwards:
>
> * **Category order is load-bearing and the client's copy has the wrong one.** Generation indexes
>   `get_archetypes()` output in the GDScript source's **insertion** order (`sword`, `air`, `water`,
>   `earth`, …). `webclient/app/bounty_data.json` is **alphabetised** (`air`, `assassin`, `beast`, …)
>   because `extract_bounty_data.gd` calls `JSON.stringify` with its default `sort_keys = true`.
>   **Never generate from `bounty_data.json`** — it is a membership/display file. Generate from
>   `data/bounty/bounty_tables.json`, which preserves insertion order (§3.3, decision D15).
> * **Self-collision scores as a specific pick.** In the versus branch, when the rolled specific target
>   *is* the bounty character, `bounty.gd` rewrites `with_specific_odds`/`target_specific_odds` to `1`
>   **before** `win_count` is computed, so the square is worth 2 points, not 1.
>
> `CharacterDatabase.by_universe()` **excludes the character itself** from every bucket.
> `data/characters/by_universe.json` stores the **un-excluded** form (correct as stored) — apply the
> exclusion at generation time.
* **The host does not change.** `deploy.ps1` scps a binary to a plain Linux VM
  (`team_anima_arena@35.208.245.67`) with nginx in front terminating TLS to port 5695. Node installs
  there in one apt/nvm step and runs under systemd. The deploy script's shape (`scp` + restart) barely
  changes; only the payload does (a directory + `npm ci --omit=dev`, or a bundled single file).
* **SQLite carries over unchanged.** `mastery_db.gd` and `stats_db.gd` already use synchronous
  queries with `PRAGMA journal_mode = WAL` and parameterised upserts. `better-sqlite3` is the same
  shape of API against the same files. No schema change, no migration.

**Honest weaknesses, and the mitigations:**

| Weakness | Mitigation |
|---|---|
| No types unless you enforce them | TypeScript `strict`, and generate the wire types from `wire_contract.json` so the router and the contract cannot drift (§2.4). |
| npm supply chain | Cap direct deps at ~5, commit the lockfile, `npm ci` only, no framework. `ws` and `better-sqlite3` are both small and long-lived. |
| Floating-point currency | AP is *already* a float on disk, so this is not a regression — but round on write and treat AP as integer-valued in the domain layer. |
| Single thread = one slow turn blocks everyone | Not a Milestone-1 concern (no combat). The §4 seam is designed so the match handler can move to a worker thread or a separate process later **without a protocol change**. |
| `better-sqlite3` is a native module | It needs a compiler on the box, or a prebuilt binary. Verify at Phase 0, before anything depends on it. If it is friction, `node:sqlite` (built into Node 22+) is a drop-in fallback for these two tiny tables. |

### 1.2 Runner-up — Go

Genuinely close, and it wins on two axes:

* **Deploy story is better than Node's and identical to today's**: one static binary, `scp` it, restart.
  `deploy.ps1` would need almost no edit.
* **Static types and a real compiler** on a 6 000-line rewrite is worth something.
* Trivially handles many concurrent matches later.

Why it is the runner-up and not the pick:

* **It changes the concurrency model.** goroutine-per-connection introduces true parallelism where
  the current design has none. Every shared structure (`sessions`, `peer_map`, `queued_players`,
  `ranked_queue`, the live match table) becomes a mutex or a channel discipline. The idiomatic fix is
  a single hub goroutine owning all shared state — which is re-implementing the event loop, in a
  language where you pay for it in ceremony. The bugs this creates are exactly the ones that are
  hardest to reproduce on a live server with 76 players.
* **Dynamic JSON is verbose.** `save_cosmetics.update` is a partial bag of ~22 keys, `submit_turn_input.input`
  is a nested package, and account fields are int-or-float. Every one becomes a struct with pointers
  or a `map[string]any` with assertions.
* **No sharing with the client**, so the Creator's validator gets written twice (see above).

Pick Go if the owner values a single-binary deploy and compile-time types more than client/server code
sharing and the preserved single-threaded model. Both are defensible; the tie-breaker here is the
**new Creator**, which is a shared-validation problem.

### 1.3 Other options, honestly

| Option | For | Against |
|---|---|---|
| **Deno** or **Bun** | TypeScript, WebSocket and SQLite all built in — could hit ~0 direct dependencies. Bun is very fast. | Smaller ecosystem, shorter production track record, more surprises on a long-lived process on an old VM. Deno is the safer of the two. Reasonable if the owner wants to minimise npm exposure. |
| **Python + asyncio/websockets** | Fastest to write; excellent for the migration/verification scripts regardless of the pick. | Weak typing story, and Milestone 2 puts the battle engine on the hot path where CPython is the wrong tool. Recommended **for the tooling** (the Phase 0 harness, §6.4), not for the server. |
| **C# / .NET** | Strong types, good perf, real threads, good WS support. | Heaviest runtime on the box; least familiar to a solo JS-and-GDScript author; no client sharing. |
| **Stay on Godot** | Zero migration. | Rejected by the owner. Also: the whole battle engine and Creator are being rewritten anyway, which is where the Godot dependency actually hurts. |

### 1.4 ⚑ Open decision #1 (blocks everything)

**The owner must choose the stack before Phase 1.** Recommendation: **Node.js + TypeScript**.
Runner-up: **Go**. Everything below is written to be stack-neutral except where it names a library;
if Go is chosen, §2's module layout survives, and §2.3's concurrency section becomes "one hub
goroutine + channels" instead of "the event loop".

---

## 2. Target architecture

### 2.1 Process layout

**One process.** One WebSocket listener. No microservices, no separate queue service, no Redis.
At 76 accounts, every additional process is a new failure mode bought with no benefit.

```
                       nginx (TLS)  wss://server.animaslashanimearenaserver.org
                             │
                    ┌────────▼─────────┐
                    │  aa-server       │  single Node process, systemd-managed
                    │                  │
                    │  net/  ────────► gateway, frame codec, backpressure queue,
                    │                  rate limiter, router
                    │  session/ ─────► session registry, presence, login FSM
                    │  store/  ──────► accounts, clans, replays, flags, sqlite
                    │  domain/ ──────► rank, ap, bounty, campaign, nexus, shop
                    │  api/    ──────► one handler table per message category
                    │  match/  ──────► queues, matchmaker, MATCH-HANDLER SEAM (§4)
                    └────────┬─────────┘
                             │  files on the same box
        ausers/*.dat   clans/*.dat   replays/*.replay   bucket data/*.dat
        server_flags.json   bot_tuning.json   mastery.db   stats.db
        data/**.json  (read-only reference data, §3.3)
```

`data/` is the only genuinely *new* directory in that list: it holds the reference tables that used to
be GDScript declarations. It is read-only at runtime and must be deployed with the binary.

The **only** thing that may later leave this process is the match handler, and the §4 seam is designed
for that (all messages JSON-serialisable, no shared mutable objects across the boundary).

### 2.2 Module layout and ownership

| Module | Owns | Replaces (Godot) |
|---|---|---|
| `net/gateway` | TCP+WS accept, frame decode/encode, per-peer outbound queue with headroom check, disconnect detection | `webclient/json_gateway.gd` |
| `net/router` | type→handler dispatch, **declarative auth/admin/rate enforcement**, unknown-type error | the `match t:` block at `server_connection.gd:770` |
| `session/registry` | `sessions{username→Session}`, `peers{connId→username}`, login Case A/B/C, 120 s disconnect hold, presence fan-out | `server_connection.gd:322-340, 1495-1607` |
| `store/accounts` | read/write `ausers/*.dat`, **atomic**, field parity, traversal rejection | `load_player`/`save_player`/`resave_player` (`:1807-1876`) |
| `store/clans` | `clans/*.dat` | `load_clan`/`save_clan` (`:1824-1866`) |
| `store/stats` | `mastery.db`, `stats.db` via SQLite | `components/mastery_db.gd`, `components/stats_db.gd` |
| `store/flags` | `server_flags.json`, `bot_tuning.json` | `_load_server_flags` (`:182`, `:4665`) |
| `domain/rank` | rating, rank/tier derivation, win/loss application | `components/rank_component.gd`, `components/Rating.gd` |
| `domain/economy` | AP table, shop purchase (**new**), unlock tokens | `_calculate_ap_gain` (`:1894`) + the client-side shop |
| `domain/bounty` | mission generation (RNG-exact), bingo validation, rewards | `scripts/bounty.gd` |
| `domain/campaign` | chapter/node/activation rules, intent validation | `scripts/campaign.gd` |
| `domain/nexus` | buckets, poll state, donations | `components/bucket_handler.gd` (the non-battle parts) |
| `api/*` | one file per category: auth, player, social, clan, queue, ladder, bounty, campaign, nexus, admin | the corresponding `_json_*` handlers |
| `match/queue` | quick/ranked/private/bot queues, rating gate sweep, bot fallback timers | `_json_enqueue` (`:1446`), `_gate_tick` (`:2593`), `_start_bot_fallback` (`:2383`) |
| `match/seam` | `MatchSpec`, `MatchIO`, `MatchHandle`, live-match registry, result bookkeeping | `Match.from_players` (`components/match.gd:102`) + `handle_server_match_ended` (`:3642`) |

### 2.3 Where state lives

| State | Home | Durable? | Notes |
|---|---|---|---|
| Session registry (who is online, which socket, which match) | memory | no | Correct: it *is* connection state. Lost on restart, which is what a restart means (see `boot_id`, §6.4). |
| Account record | memory **while a session is live**, disk is the truth | yes | Mirrors today: the session holds the live `Player` and every mutation write-throughs. |
| Offline account (an admin op target, a friend-request recipient) | **read-through from disk, do not cache** | yes | ⚠ **Deliberate divergence.** The Godot server keeps a global `players{}` cache and `resave_player` writes it back (`:1868-1876`), which silently reverts hand-edits to `.dat` files and has already burned this project once (season reset had to become a server op for exactly this reason). The new server should have **one** in-memory copy per *logged-in* account and no global cache. |
| Chat buffers (global 100, dm 50/pair ≤2000 pairs LRU, match 50) | memory | no | Matches today. `WIRE_CONTRACT.md` §4.3 — "no durable chat history" is the contract. |
| Queues, private invites, ranked buckets, fallback generation counters | memory | no | Released on disconnect (`_release_queues`, invariant 24). |
| Maintenance state | memory | no | Deliberate: the restart *is* the reset (`WIRE_CONTRACT.md` §2.7). |
| Feature flags | `server_flags.json` | yes | Only `creator_enabled` today — which **dies with the Creator**. Keep the file mechanism for the next flag; drop the key. |
| Rate-limit buckets | memory, per session, **keyed by a bounded action name** | no | The bounded key matters: keying on user input (e.g. a DM target) grows unboundedly. Enforced by the router, not by handlers (`server_connection.gd:470-484`). |
| Live match | memory, owned by `match/seam` | replay only | See §4. |

### 2.4 The gateway and the router

**Gateway** (`net/gateway`) is transport only, exactly like `JsonGateway`:

* Accept, handshake, decode UTF-8 text frames as JSON **objects**; drop non-objects with a warning
  and no reply (contract §1).
* **Two send paths, and the distinction is load-bearing.** `send()` is direct; `sendQueued()` goes
  through a per-connection FIFO drained as the socket's outbound buffer frees up. The Godot version
  silently drops direct sends once the 64 KB buffer backs up — only reproducible over a real network
  (`json_gateway.gd:128-134`). **In the new server, make the queued path the default** and reserve
  the direct path for nothing. There is no reason to keep a footgun that only fires in production.
  Frames that *must* be queued today: `replay_data`, `admin_training_status` (contract §1).
* `broadcast()` / `broadcastExcept(ids)` — the maintenance eject needs the exclusion form so it does
  not throw out the admin holding the Cancel button (contract §2.7).

**Router** (`net/router`) is where the rewrite's biggest safety win lives. Today, auth, admin and rate
checks are written *inside* each of 89 handlers; a rewrite that reproduces that shape will eventually
forget one. Instead, declare them:

```ts
export const adminRoutes: RouteTable = {
  admin_announce:       { auth: "admin",  handle: announce },
  admin_modify_player:  { auth: "admin",  handle: modifyPlayer },
  // …
};
export const socialRoutes: RouteTable = {
  friend_request: { auth: "session", rate: { key: "friend_request", n: 6,  ms: 60_000 }, handle: friendRequest },
  chat_send:      { auth: "session", rate: { key: "chat",           n: 5,  ms: 10_000 }, handle: chatSend },
  clan_search:    { auth: "session", silent: true, handle: clanSearch },
  // …
};
```

The router enforces `auth` (`none` / `session` / `admin`), `silent` (return with **no reply** when
unauthenticated — a real distinction in the contract), and `rate` before the handler runs. A handler
that needs a session simply cannot run without one.

**Boot-time conformance assertion (do this — it is ~20 lines and it is the cheapest insurance in the
project):** load `wire_contract.json` at startup and assert that the router's key set equals its
inbound name list, minus the deliberate exclusions (the 12 `authored_*` types, `admin_toggle_creator`,
and whichever of the 4 dead draft types the owner decides to drop — §7.2 decision D6). The process
refuses to start on a mismatch. A typo'd message name becomes a boot failure instead of a support
ticket.

### 2.5 Concurrency and timers

Single event loop. Handlers run to completion. No `await` inside a handler that mutates shared state
unless the mutation happens *before* the await — this is the one discipline rule, and it is the same
rule the current `_start_bot_fallback` coroutine already has to obey (`server_connection.gd:2383-2400`,
which re-validates *everything* after its `await` because the world moved).

Timers:

| Timer | Period | Purpose | Source |
|---|---|---|---|
| ranked gate sweep | 1 s | pair ranked players whose wait time has opened their rating band | `_gate_tick` (`:2593`) |
| bot fallback (quick) | per-player `bot_queue_delay`, clamped ≥15 s | seat a bot | `_start_bot_fallback` |
| bot fallback (ranked) | fixed 20 s | seat a bot at ×0.1/×0.5 rating | contract §4.5 |
| disconnect hold | 120 s one-shot per disconnected session | then `wipeSession` (auto-surrender if in a match) | contract §2.5 |
| turn timer | per match, 120 s base with the AFK ladder | **lobby-owned** — see §4.4 | `components/match.gd:711-765` |
| replay retention sweep | boot + 24 h | 30 days / 5 000 files | contract §7.4 |

**Do not port** the 15 s `server_ping_cycle`: it explicitly skips JSON peers and is dead code with the
Godot transport gone (contract §2.4). Port the **client's** 25 s `ping` keepalive instead — it exists
because nginx was closing idle lobby sockets (`webclient/app/net.js:18-26`).

---

## 3. The data layer

### 3.1 Player records — recommendation: **read the existing files as-is. Do not convert.**

`ausers/<username>.dat` is one line of JSON; the filename *is* the username; 40 documented fields
(`WIRE_CONTRACT.md` §7.1). The new server reads and writes the same format, same path, same keys.

**Why not convert to SQLite now**, even though SQLite is objectively the better long-term home:

1. **Rollback.** The whole cutover plan (§6) depends on being able to flip nginx back to the Godot
   binary in 30 seconds. That only works if the Godot server can still read every account the new
   server has written. A format conversion makes rollback a *reverse migration under pressure*,
   which is how people lose accounts.
2. **A bad migration loses real players' accounts** and there is no upstream to restore from.
3. The performance argument is empty at 76 accounts.

Consolidating accounts into SQLite is a good project — **after** the Godot binary is deleted and the
new server has been stable for a month. Not during the rewrite. Schedule it as its own thing with its
own backup and verification.

**What the new store must fix regardless (all format-preserving):**

* **Atomic writes.** `save_player` opens the file `WRITE` (truncating) with **no null check** and
  calls `store_line` on the result (`server_connection.gd:1846-1853`). A failed open crashes the save;
  a crash mid-write leaves a truncated or empty account file. Replace with: serialise → write
  `ausers/.<user>.dat.tmp` in the same directory → `fsync` → `rename` over the target. Rename within
  a directory is atomic on Linux; a crash leaves either the old file or the new one, never a stub.
  (Note `save_clan` *does* null-check — `:1858-1862` — so the omission in `save_player` is an
  oversight, not a policy.)
* **Fail loud, not open.** A write error must log at error level and, for account writes, refuse to
  report success to the caller.
* **Traversal rejection lives in the store**, not in each handler. Today `_admin_get_target` (`:447`)
  rejects `""`, `/`, `\`, `..` and every target-resolving handler must remember to call it. In the new
  server the accounts store rejects an invalid name at the API boundary, so forgetting is impossible.
* **Tolerate partial updates.** `absorb_cosmetic_update` indexes with `data['key']` rather than
  `.get()` (`scripts/player_component.gd:189+`), so a `save_cosmetics` frame missing any expected key
  raises server-side. The new implementation must ignore absent keys — and must **keep the
  server-only field list exactly** (`friends`, `friend_requests_*`, `ignored`, `muted`,
  `match_history`, `allow_spectators`, `ranked_allow_bots`, `campaign_state`, `mastery_xp`, W/L,
  rating — contract invariant 21).

### 3.2 Migration story, step by step

There is no schema conversion, so "migration" is really **adoption + proof**:

1. **Backup.** Copy `ausers/` to `ausers_backup_<stamp>/` before the new server's first write. The
   season-reset code already implements exactly this copy loop (`server_connection.gd:579-590`) — reuse
   the shape. Copy `clans/`, `bucket data/`, `mastery.db`, `stats.db` too. Keep the backup off the box
   as well.
2. **Read-only verification pass** (`aa-server --verify-accounts`): parse all 76 `.dat`, report any
   that fail to parse, any missing field, any unexpected field, and a type histogram per field. This
   catches the int-vs-float reality (`ap: 25050.0`) before code depends on it.
3. **Round-trip proof**: for every account, `load → save → load` with **no mutation** into a scratch
   directory, then assert deep JSON equality against the original parse (**not** byte equality — key
   order and float formatting will differ, and that is fine as long as the Godot server can still
   read it). Then feed a sample of the round-tripped files to the Godot server in a staging copy and
   confirm it logs in normally. That last step is the one that actually protects rollback.
4. **First-write canary**: the new server's first production write should be a single ZZ_-prefixed
   throwaway account, verified by hand.
5. **Never** point both servers at the same `ausers/` directory at the same time with both accepting
   logins. Two live servers with in-memory account copies will overwrite each other. Staging gets a
   **copy** (§6).

### 3.3 Reference data inventory — **superseded and done**

> **This section was the first draft's worst error.** It asserted that `char_name_list` and the bounty
> categories were "the only reference data that cannot simply be pointed at". An adversarial extraction
> stage found **15** GDScript-trapped datasets, swept every `.gd` in the repo twice to prove that was
> all of them, and extracted the lot. The full treatment now lives in **`REFERENCE_DATA_INVENTORY.md`**
> — read that as the data-side spec. What follows is the roadmap-level summary.

**Status: this is no longer a Phase-0 task. It is finished.** All 15 datasets are in `data/`, and both
of the following pass today:

```bash
python tools/reference_data.py    # no Godot: re-derives every data/ file by PARSING the .gd source
                                  # 15/15 ok, exit 1 on any drift (proven in both directions)
"<godot>" --headless --path . --script res://tools/check_extraction_vs_godot.gd
                                  # read-only: proves PARSING the source == RUNNING it. 47/47 checks.
```

That second script is the load-bearing one: it is the proof that a static parser and the live engine
agree, which is what lets the new server stop caring about GDScript at all.

#### What was trapped (all now in `data/`)

| Dataset | GDScript home | Extracted to |
|---|---|---|
| `char_name_list` (**174**), `starter_character_list` (21), `starter_squads` (34) | `scripts/character_database.gd` | `data/characters/character_lists.json` |
| per-character display name + universe | `character/<path>.gd` | `data/characters/character_universes.json` |
| `by_universe()` — **order is load-bearing for bounty generation** | `scripts/character_database.gd:250` | `data/characters/by_universe.json` |
| Jin-woo's 5 summon-form ability-key lists | `character/jinwoo.gd:14` | `data/characters/jinwoo_form_kits.json` |
| `Universe` **ordinals** (54, append-only, **persisted in save data**) | `components/character_concept.gd:8` | `data/nexus/universe_enum.json` |
| Nexus concepts (**639**, not ~654 — 15 are commented out) | `components/bucket_handler.gd:33` | `data/nexus/all_chars.json` |
| `PERMANENT_EXCLUDED` (12), seeded bucket-universe order | `components/bucket_handler.gd:19,706` | `data/nexus/nexus_tables.json` |
| `mission_types`, `winning_patterns` (**12**, not 13), `categories` (35), `archetypes` (36) | `scripts/bounty.gd` | `data/bounty/bounty_tables.json` |
| `rp_thresholds`, `ranked_streak_thresholds`, tier spans | `components/rank_component.gd:57,68` | `data/ladder/rank_tables.json` |
| `GATE_BANDS`, `MM_TICK`, `ADMIN_USERNAMES` | `components/server_connection.gd:56,63,358` | `data/server/matchmaking.json` |
| `title_data` | `scripts/player_component.gd:23` | `data/server/title_data.json` |
| **14 enums whose ordinals are wire- and save-visible** | `scripts/types/*.gd`, `battle_manager.gd`, `clan.gd`, … | `data/engine/enums.json` |
| `RESERVED_EFFECT_NAMES` (30), `HERO_SHIELD_BOUND` (4) | `scripts/character_component.gd:81,1246` | `data/engine/name_tables.json` |
| `CLASS_NAMES` (19, append-only), `FREE_SKILLS_MARK` | `abilities/scripts/ability_component.gd:28` | `data/engine/ability_classes.json` |
| Mastery XP ladder (101 rows), `UNLOCK_THRESHOLDS` | `components/mastery_config.gd` | `data/progression/mastery.json` |

Three of these matter more than their size suggests:

* **Enum ordinals are a migration surface, not a rename.** `abilities_data.json` stores `target_type`
  and cost keys as these ints; battle snapshots carry effect/damage types as these ints; **save data
  stores `Universe` and clan `Rank` as these ints**; and `match_type == 3` *is* what "ranked" means on
  the wire. Renumbering any of them silently corrupts existing accounts. `data/engine/enums.json`
  records the ordinals **and who observes each one** — consult it before touching an enum.
* **`by_universe` ordering** feeds bounty generation directly (§1.1 box).
* **`GATE_BANDS`** is what Phase 6's rating-gated pairing is built from; it was previously undocumented
  as trapped data and would have been retyped by hand from a code read.

#### What was *not* trapped — point the new server at these unchanged

| Data | Where | Migration action |
|---|---|---|
| Campaign rules | `webclient/app/campaign_chapters.json`, `campaign_dialogue.json`, `campaign_encounters.json` | **No migration.** Same three files, same path, read by **both** sides (`scripts/campaign.gd:10-12`). One copy is what keeps them honest. |
| Shop catalogue | `webclient/app/shop_catalog.json` | Server must read it once `buy` exists (D1). Same file — do not fork it. |
| Roster / unlock gates | `webclient/app/roster.json` (174) | Read the same file. **Verified: an exact set match with `char_name_list()`**, both 174. Hand-maintained, no generator. |
| Ability cost / cooldown / classes / `target_type` | `abilities_data.json` (1087 rows) | **It is the sole source of truth** — there is no `.tscn` to disagree with it. 96 rows have a dangling `script_path` and 45 are classless stubs; both sets are unreachable and every extractor skips them. |
| Ability display text | `webclient/app/ability_split.json` (989), `ability_info.json` (1085) | In sync today (0 drift, proven). **The one remaining Godot dependency** — see §3.5. |
| Nexus buckets | `bucket data/*.dat` (**667** files) + `poll.dat` + `removed_list.dat` | Keep the format. The concept list is now `data/nexus/all_chars.json`. **667 files vs 639 concepts is benign**: 28 orphan AP rows from promoted or renamed concepts, nothing ever deletes one. Ignore unknown `.dat` names. `removed_list.dat` is currently absent, which is valid. |
| Clans | `clans/*.dat` (1 file) | Keep as-is. |
| Mastery / stats | `mastery.db`, `stats.db` (SQLite, WAL) | **Keep as-is**, same schema, new binding. The legacy `stats/<char>.stats` flat-file fallback can be dropped. |
| Replays | `replays/*.replay` (47) | Keep. Format is battle-owned and **deferred** (§4.5). |
| Bot tuning / training | `bot_tuning.json`, `training/…` | Keep the files; the consumer is battle-side (§8.2 #11). |
| Battle-side ability *scripts* | ~1020 `abilities/*.gd` | **Out of scope** — Milestone 2 / the Creator redesign. The lobby never reads them. |

#### Tables that are *logic*, not literals — a port must reimplement these by hand

They are hard-coded inside function bodies, so no extractor can reach them. Values are recorded in
`REFERENCE_DATA_INVENTORY.md` §4 so they cannot be lost:

* **AP payout** (`server_connection.gd:_calculate_ap_gain`, `:1894`) — flat per queue, no streak
  scaling: Bot 50/0, Quick (incl. its bot fallback) 100/50, Ranked-vs-human 500/50, Ranked-vs-bot
  250/50, Private 0/0. Pinned by `training/tests/queue_rewards_probe.gd` (all 10 cases).
* **`tier_for_rating`** (`rank_component.gd:40`) — 400 rating per tier, 4 divisions of 100,
  Grandmaster open-ended. (The *constants* are in `data/ladder/rank_tables.json`.)
* **Bounty mission win-counts** (`bounty.gd:generate_from_details`) — described under
  `mission_target_counts` in `data/bounty/bounty_tables.json`.
* **AFK / draft timers** (`components/match.gd:25-36`).

#### Dormant data a port must **not** "restore"

The extraction found tables that look like live spec but have zero readers. Wiring them up would
invent behaviour the game does not have:

* **`rp_thresholds` / `ranked_streak_thresholds`** — no readers. The promo-series design that used
  them was removed; tiers derive from rating. Extracted as a spec *if* that layer is ever rebuilt.
* **`title_data`** (`player_component.gd:23`) — no readers at all. The live title system is the
  client's `titles.json`.
* **The ranked draft surface** — already covered by D6; this is the data-side echo of it.

Two latent defects were also found and **deliberately not fixed** (no-behaviour-change rule). The port
inherits the decision, not the bug: `archetypes` contains `"non human"` which is not a `categories`
key (unreachable today, would throw in `check_bounty_progress` the moment anything else can name an
archetype), and **`categories["lightning"]` contains the string `"lightning"`**, which is not a
character at all — *reachable*, and it produces a bingo square nobody can ever complete. See D16.

> **Do not port `missions/objective.gd`.** It holds a third, much older copy of the categories table
> with different membership and misspelled names (`bakugou`, `tsuna`, `satuski`). `missions/` has no
> references from anywhere outside itself. It is dead code, and it is the most plausible thing for a
> port to mistake for the real table.

### 3.4 SQLite usage

Two tiny databases, unchanged schemas:

* `mastery.db` — `character_mastery(character_path, username, xp, updated_at)`, PK `(path, username)`,
  index `(character_path, xp DESC)` (`components/mastery_db.gd:26-38`).
* `stats.db` — one row per `(character_path, match_type)` with cumulative picks/wins/losses; bucketing
  (PvP = QUICK+RANKED vs BOT; PRIVATE excluded) is a **read-time** roll-up
  (`components/stats_db.gd:1-20`). Preserve that — it is a deliberate anti-lossy-write decision.
  Also preserve `EXCLUDED_USERS` (admin/test accounts are dropped from usage aggregates, but only
  their own team — their opponents still count).

Keep WAL. Keep parameterised statements. No ORM.

### 3.5 The data *pipeline* is Godot too — what replaces it, and when

The first draft treated reference data as a one-time export problem. It is not: several of these JSON
files are **generated**, and **every generator is itself a GDScript program run under the editor**. If
the Godot binary is deleted and the generators are not replaced, the data quietly becomes
unregenerable — you can still read it, but you can never legitimately change it again.

| Generator | Writes | Replacement | When |
|---|---|---|---|
| `extract_char_index.gd` | `webclient/app/char_index.json` | Trivial — read `data/nexus/all_chars.json`, trim the `res://assets/images/` prefix. **But see D13 first: regenerating it today would delete 18 rows the client still uses.** | Phase 0 |
| `extract_bounty_data.gd` | `webclient/app/bounty_data.json` | Trivial — read `data/bounty/bounty_tables.json` + `data/characters/character_lists.json`. ⚠ **Must pass `sort_keys = false`**; the current default silently alphabetises `categories` (§1.1 box, D15). | Phase 0 |
| `regenerate_character_colors.gd` | `character_colors.json` | Direct port; it is *already* regex-based over `character/*.gd`. Carries an in-script `EXCLUDED` (8) + `OVERRIDES` list that must come with it. | Phase 0 |
| `extract_ability_info.gd` | `webclient/app/ability_info.json` | Pure JSON→JSON. Two deliberate behaviours to preserve: `description` falls back to the *previous* file when the DB value is empty, and rows failing the completeness gate are **carried forward, never pruned**. | Phase 0 |
| `extract_split_desc.gd` | `webclient/app/ability_split.json` | **Cannot be ported.** See below. | — |

**`split_desc()` is the one true remaining Godot dependency, and it is not portable by parsing.** It is
an arbitrary GDScript *function body* returning an array of `String` or `[String, Color]`, where the
`Color` is a GDScript constant serialised via `to_html(false)`. Bodies branch and call helpers. No
static reader covers that in general.

**The plan is to freeze it, not to port it.** `ability_split.json` is currently **100 % in sync** —
989 live entries vs 989 stored, 0 text drift, proven by `tools/check_split_desc_sync.gd` against the
running engine. So: treat the file as **authored content** from cutover onward, and keep that checker
in CI for as long as the `.gd` abilities exist, so the freeze cannot silently rot. When ability
authoring moves off GDScript (Milestone 2 / the Creator redesign), the new ability format emits its
own description segments and the dependency dies with the old one.

**Consequence for Phase 0:** "export the GDScript lists" is done, but "**replace the four portable
generators**" is not, and it inherits the slot. It is a half-day of scripting and it is what actually
removes Godot from the Milestone-1 loop.

⚠ **The verifier that guards all of this is currently untracked.** `.gitignore:8` is a blanket `*.py`,
which silently excludes `tools/reference_data.py` and `tools/gdlit.py` — the only things that can
detect `data/` drifting from the `.gd` source — as well as the Python half of the bounty proof.
Verified with `git check-ignore -v`. See D17; this is a one-line fix and it should happen before
anyone relies on the check.

---

## 4. The seam: what a "match handler" is

**This is the section that exists for Milestone 2.** Battle execution and the new Creator are not
designed here — but the *shape of the hole they plug into* is, and getting it right now is what keeps
them from re-entangling with account and session code the way the current implementation did.

### 4.1 The one-sentence contract

> The lobby seats two players and hands a **match handler** an immutable `MatchSpec` plus an I/O
> port. The handler resolves the game and eventually reports a `MatchResult`. **The handler knows
> nothing about accounts, currency, rating, bounties, mastery, stats, clans, sessions or sockets.
> The lobby knows nothing about combat rules.**

### 4.2 What today's code gets wrong, and what the seam fixes

| Today | Problem | Seam rule |
|---|---|---|
| `Match.from_players(peer, player, chars, …)` takes the **live, session-owned `Player` objects** and mutates them: `team.clear_characters()`, `recruit_character(...)` (`components/match.gd:154-171`) | Building a second match for a player wipes the first match's live board. The code carries a 20-line "SINK GUARD" comment and a static guard function to survive this (`match.gd:86-130`). | **Pass values, not objects.** `MatchSpec.seats[].team` is an array of strings. The handler never sees an account object, so the failure mode cannot exist. |
| `handle_server_match_ended` does rating, AP, clan W/L, bounty progress, mastery XP, stats, match history and persistence — inside the match-end path (`server_connection.gd:3642-3790+`) | Combat teardown and economy are one function. Any battle rewrite touches account bookkeeping. | The handler emits **only** `MatchResult`. All of the above lives in `match/seam`'s `onResult`, in the lobby, untouched by Milestone 2. |
| The AFK turn timer lives in `Match` and reaches into session/disconnect state (`match.gd:711-765`, `_refresh_timer_pause`) | Presence logic inside the battle object. | **The lobby owns the clock** (§4.4). |
| Bot turns are driven by the lobby, which runs the policy directly on the shadow `BattleManager` | Lobby imports the whole combat engine to play a bot. | A bot is **a seat kind**. The handler drives it. The lobby says "seat p2 is a bot at difficulty X" and nothing more. |
| `session.current_match` points at the `Match` node | Coupling, but *also* the anti-spoof cornerstone (contract §2.8). | **Keep the property, change the type**: the session holds an opaque `matchId` + role. Routing still never trusts a client-supplied match id. |

### 4.3 The interface

Everything crossing the boundary is JSON-serialisable. No shared mutable objects. This is what makes
the handler relocatable to a worker or a separate process later without a protocol change.

```ts
// ---- Lobby → handler, at creation ------------------------------------------
type MatchSpec = {
  matchUid: string;            // "YYYYMMDD_<id>_<rand>" — minted by the LOBBY (durable, used by replays/chat)
  matchType: "QUICK" | "RANKED" | "PRIVATE" | "BOT" | "CAMPAIGN";
  seed: number;                // decides first actor AND all combat RNG (see note below)
  seats: [Seat, Seat];
  rules: {                     // knobs the lobby owns; the handler reads, never redefines
    turnSeconds: number;       // 120
  };
  meta: {                      // opaque to combat, echoed back on the result
    practice: boolean;
    ranked: boolean;
    campaignEncounter?: string;
    campaignActivation?: string;
  };
};

type Seat = {
  role: "p1" | "p2";           // canonical: p1 owns character indices 0,1,2; p2 owns 3,4,5
  kind: "human" | "bot";
  seatRef: string;             // OPAQUE lobby handle. NOT a username, NOT a socket.
  team: string[];              // path_names, plus the existing suffix tokens
                               //   (a Toga disguise as a 4th element, a "form:<color>" Jin-woo token)
  botDifficulty?: string;      // bot seats only
};

// ---- Handler → lobby, during the match -------------------------------------
interface MatchIO {
  toSeat(role: "p1" | "p2", frame: object): void;   // lobby routes to that seat's socket if live
  toSpectators(frame: object): void;                // lobby fans out; handler supplies the STRIPPED copy
  ended(result: MatchResult): void;                 // terminal, exactly once
  replayBlob(blob: object): void;                   // optional, opaque to the lobby
  log(level: "info" | "warn" | "error", msg: string): void;
}

// ---- Lobby → handler, during the match -------------------------------------
interface MatchHandle {
  submitInput(role, input: object): { ok: true } | { ok: false; reason: string };
  surrender(role): void;
  timeout(role): void;               // the LOBBY decided the clock ran out; handler resolves as a pass
  snapshotFor(role): object;         // reconnect payload
  snapshotForSpectator(): object;    // hidden-info-stripped
  actingRole(): "p1" | "p2";         // so the lobby knows whose clock is running
  cancel(reason: "maintenance" | "admin" | "abandoned"): void;   // no-contest, no result bookkeeping
  dispose(): void;
}

// ---- Handler → lobby, at the end -------------------------------------------
type MatchResult = {
  matchUid: string;
  outcome: "p1" | "p2" | "no_contest";
  reason: "normal" | "surrender" | "afk" | "cancelled";
  turns: number;
  teams: { p1: string[]; p2: string[] };   // as actually fielded
  meta: MatchSpec["meta"];                 // echoed
};

interface MatchHandler {
  create(spec: MatchSpec, io: MatchIO): MatchHandle;
}
```

**Seat identity is opaque on purpose.** `seatRef` is a lobby-minted handle. The handler cannot look up
an account, cannot read AP, cannot see a friend list. If Milestone 2 ever finds it *needs* an account
fact, that is a signal to add it to `MatchSpec` explicitly — not to reach across.

**On the seed:** today one seed decides both the first-actor coin flip (`match.gd:181-183`) and combat
RNG. Keep one seed in the spec, but let the **handler** decide who acts first and report it, rather
than the lobby computing it with a coin flip the handler must reproduce. The lobby needs that answer
only to fill `first_turn` in the match-start frame, so `create()` can return it alongside the handle.

### 4.4 Ownership split, explicitly

| Concern | Owner | Why |
|---|---|---|
| Whose turn it is | **handler** (exposed via `actingRole()`) | it is a combat fact |
| The turn *clock*, the AFK penalty ladder (−30 s per consecutive miss, floor 30 s, forfeit at 3), pausing while the acting player is disconnected | **lobby** | it is a presence/session fact; today it is tangled into `Match` and it is the main reason `Match` reaches into session state |
| Stamping `snapshot.turn_timer` onto every outbound `apply_turn_result` | **lobby**, on the way out | already how it works (`server_connection.gd:3849`) — keep it, it is the clean version |
| Re-checking `peers[connId] === expectedUsername` before every match send (invariant 3) | **lobby** | the handler has no sockets |
| Hidden-info stripping for spectators | **handler** produces the stripped copy; lobby fans it out | only combat knows what is hidden (`_spectator_safe_events`, `_spectator_safe_snapshot`, `:5328-5340`) |
| Spectator *eligibility* (privacy setting, friends-only, ignore list, cap of 20) | **lobby** | pure social policy (contract §4.6) |
| Rating, AP, W/L, clan record, bounty progress, mastery XP, stats, match history, `receive_player_update`, `ranked_result` | **lobby**, in `onResult` | all account state |
| Replay persistence + retention + the participants-only gate | **lobby** | the blob is opaque; the *policy* is not |
| Turn-input validation | **handler** | it is entirely a combat question (contract §3.7, invariant 37) |

### 4.5 Frames the lobby owns vs the handler owns

| Frame | Produced by | Note |
|---|---|---|
| `receive_quick_match` / `receive_ranked_match` / `receive_private_match` / `receive_campaign_match` | **lobby** | opponent display package, `first_turn`, `seed`, `canonical_role`, `practice`, `vs_bot`. The channel name is the contract, not the label (contract F9). |
| `apply_turn_result` | handler (body) + lobby (`turn_timer` stamp, routing, spectator fan-out) | |
| `receive_session_reconnect` / `spectate_init` | handler snapshot, lobby envelope | |
| `ranked_result` | **lobby** — computed from a rank snapshot taken *before* mutation | invariant 20; the client derives nothing |
| `receive_player_update` | **lobby** | |
| `receive_opponent_disconnect_notification` / `…reconnect…` | **lobby** | pure presence |
| `receive_surrender` | **nobody — delete it.** The client has no handler; the surrender already arrives via `apply_turn_result` (contract F2) | |

### 4.6 Milestone-1 handlers (this is what makes the seam testable **now**)

Two handlers ship with Milestone 1, and neither contains any combat:

1. **`StubMatchHandler`** — accepts a spec, emits a minimal snapshot, accepts any input, and ends the
   match on command (or after N inputs) with a scripted winner. This lets Phase 6 exercise the entire
   post-match bookkeeping path — AP, rating, `ranked_result`, W/L, clan records, bounty progress,
   mastery XP, stats rows, `match_history`, replay write — **without a battle engine**. That path is
   ~150 lines of the most consequential logic in the server, and it becomes fully testable months
   before combat exists.
2. **`NullMatchHandler`** — refuses to create, so a misconfigured deploy fails loudly instead of
   seating players into a void.

When Milestone 2 lands, it registers a third handler. Nothing else in the server changes. That is the
test of whether this seam is right: **if the battle engine can be swapped by changing one
registration line, the boundary is real.**

---

## 5. The phased plan

**Read this first:** phases 1–6 are *independently verifiable against the real web client*, but they
are **not independently deployable to players** — no phase before Milestone 2 can serve a production
match. "Shippable" here means "a running server the real client gets measurably further into, with a
green acceptance test". Do not confuse that with "ready to flip".

Acceptance criteria are `WIRE_CONTRACT.md` §9. Message names below are exact and every one is in
`wire_contract.json`.

### Phase 0 — Tooling, exports, and the baseline capture

**Goal:** the ability to prove parity, before writing any server code.

* Stand up the repo: TypeScript, strict, lint, `node:test`, systemd unit file, health endpoint.
* Verify the native SQLite binding builds on the actual box (§1.1 mitigation).
* ~~**Export the hardcoded GDScript lists** to JSON.~~ **DONE** — all 15 trapped datasets are in
  `data/`, re-derivable without Godot and verified against the running engine (§3.3). Wire the new
  server's reference-data loader at `data/` and treat it as read-only.
* **Replace the four portable generators** (§3.5): `extract_char_index`, `extract_bounty_data`,
  `regenerate_character_colors`, `extract_ability_info` become plain scripts over `data/` + the root
  JSON. Resolve D13 (char_index policy) *before* running the first one, and pass `sort_keys = false`
  in the bounty exporter (D15). `extract_split_desc` stays Godot and gets frozen instead (§3.5).
* **Fix `.gitignore:8`** so the verifier is tracked (D17).
* **Build the protocol harness** (`tools/harness/`): a scriptable WebSocket client that speaks the
  real wire protocol, driven by a scenario file, recording every frame with timestamps to JSON. It
  must be able to run **multiple simultaneous clients** (pairing, chat, spectate all need two).
* **Capture the baseline**: run the scenario catalogue against the *live Godot server* on a staging
  copy of `ausers/` with ZZ_-prefixed accounts. Those recordings are the golden reference for every
  later phase.
* **Re-capture the RNG primitives against the deployed binary** if it was not exported from
  Godot 4.6.2-stable. Every fixture in `backend_port/bounty/` came from 4.6.2-stable; a change to
  `RandomPCG::random` upstream would silently reroll every card (risk 5).

**Done:** harness logs in, plays a scripted session, writes a recording; scenarios exist for at least
auth, cosmetics, social, clan, queue-and-pair. The four portable generators run without Godot and
reproduce their current output (modulo the deliberate D13/D15 changes).
**Verified:** replay a recording against itself → empty diff. `node --check`/`tsc` clean.
`python tools/reference_data.py` exits 0 and `tools/check_extraction_vs_godot.gd` reports 47/47 —
both already pass today, so any failure here means something regressed, not that work is outstanding.

### Phase 1 — Transport, session, auth

**Implements (inbound):** `ping`, `server_status`, `login`, `register`, `change_password`.
**Emits:** `pong`, `server_status`, `receive_login_response`, `receive_register_response`,
`receive_change_password_response`, `receive_player_update`, `error`, `global_chat_state`,
`maintenance_notice` / `maintenance_cleared` / `maintenance_locked` (state only; the admin ops that
*set* them arrive in Phase 5).

* Gateway + backpressured queue + router with declarative auth/rate + the boot conformance assertion (§2.4).
* Session registry; login Case **A/B/C** with `id` **2/0/1** semantics (contract §2.3); `boot_id`
  regenerated per process; 120 s disconnect hold → wipe (without the match branch, which is Phase 6).
* Client keepalive answered.

**Done:** the real web client, pointed at the new port with `?ws=ws://localhost:5795` (dev origins
honour the override — `app.js:40-52`), logs in with a real existing account and reaches the lobby.
**Verified:**
(a) client reaches lobby and stays connected >10 min (keepalive works);
(b) second login of the same account → `id: 0`, "Account already logged in.";
(c) kill the socket, reconnect within 120 s → `id: 2`;
(d) harness diff of the login/register frames vs the Phase-0 baseline, ignoring `boot_id` and
timestamps;
(e) **new**: `receive_login_response` must **not** contain `pass_hash` (see §7.2 decision D3) — assert
its absence.

### Phase 2 — Accounts, persistence, profile, ladder

**Implements:** `save_cosmetics`, `get_player_profile`, `reset_own_record`, `social_setting`, `ladder`.
**Emits:** `player_profile`, `record_reset`, `social_result`, `ladder`, `receive_player_update`.

* Accounts store: atomic write, traversal rejection, tolerant partial `save_cosmetics`, the exact
  client-writable/server-only split (contract §7.1 and invariant 21).
* `domain/rank`: rating → rank/tier (400 per rank, 4 divisions of 100), ladder boards by rating/wins/
  streak + clan standings + the "me" row. Constants and tier ordinals are in
  `data/ladder/rank_tables.json`; `tier_for_rating` itself is logic and must be rewritten by hand
  (§3.3). **Ignore that file's `rp_thresholds` / `ranked_streak_thresholds` — they are dormant (D12).**
* Profile whitelist (`_build_profile_body`) — never the raw save.

**Done:** cosmetics, equipped team and settings survive a relog; the profile modal and the ladder
render correctly in the real client.
**Verified:**
(a) the §3.2 round-trip proof over all 76 accounts;
(b) equip cosmetics in the new server, then log the same account into the **Godot** server on the
staging copy and confirm it reads them (this is the rollback-compatibility test, and it should be run
every phase);
(c) ladder frame diffed against the baseline for identical account state.

### Phase 3 — Social and clans

**Implements:** `social_state`, `friend_request`, `friend_accept`, `friend_decline`, `friend_cancel`,
`friend_remove`, `ignore_add`, `ignore_remove`, `chat_send`, `chat_history` (10) and all 16 `clan_*`
types (`clan_state`, `create_clan`, `clan_search`, `clan_apply`, `clan_cancel_application`,
`clan_invite`, `clan_cancel_invite`, `clan_accept_invite`, `clan_decline_invite`,
`clan_approve_application`, `clan_deny_application`, `clan_kick`, `clan_leave`, `clan_disband`,
`clan_reset_record`, `clan_set_banner`).
**Emits:** `social_state`, `social_result`, `friend_presence`, `friend_request_notice`,
`chat_message`, `chat_result`, `chat_history`, `clan_state`, `clan_result`, `clan_search_result`,
`clan_invite_notice`.

* Friend graph with caps (friends 100, pending 50, ignored 100); presence fan-out on every ONLINE /
  DISCONNECTED / OFFLINE transition.
* Chat ring buffers with the exact caps (global 100, dm 50/pair, match 50, ≤2000 DM pairs LRU,
  300 chars); global kill switch.
* Clans: two-tier, leader-gated ops re-checked server-side, `clan_state` self-heals a dangling
  membership to "Clanless".
* **Oracle-freedom as shared helpers**, not per-handler strings (invariants 30–32).

**Done:** two browsers can friend each other, DM, use global chat, ignore, and form/join/leave a clan.
**Verified:** two-client harness scenarios; explicit assertions that a friend request to someone who
ignores you produces a byte-identical success reply and an identical `requests_out` entry to one that
was delivered; rate limits observed (6/60 s friend_request, 5/10 s chat, 20/60 s ignore, 30/60 s
friend_mutate).

### Phase 4 — Economy: bounties, nexus, and the shop fix

**Implements:** `bounty_missions`, `complete_bounty`, `nexus_state`, `donate`, **plus a new `buy`**
(§7.2 decision D1).
**Emits:** `bounty_missions`, `nexus_state`, `update_buckets`, `receive_player_update`.

* **Port the bounty RNG bit-exactly** (Godot `hash()` + PCG32 + `randi_range`) — **against the spec in
  the §1.1 box, not against the naive one.** A reference TypeScript port already exists and passes
  every fixture: `backend_port/bounty/bountyGen.ts`, with `compare.ts` as its comparator. Start from
  it rather than re-deriving; re-deriving is exactly how the degenerate-range bug gets reintroduced.
  Generate from `data/bounty/bounty_tables.json` (insertion order), **never** from the client's
  alphabetised `bounty_data.json`.
* Server-side bingo re-validation on claim; rewards granted server-side (+5000 AP, +1000 mastery XP,
  or the `<path>_unlock` token).
* Nexus buckets + poll flag; donations debited server-side.
* **New:** `buy` — server validates price against `shop_catalog.json`, debits AP, appends the unlock,
  persists, echoes `receive_player_update`. And **server-owned bounty square progress**, so
  `active_bounties` stops being client-writable.

**Done:** an existing player's in-flight bounty card renders **identically** to the Godot server's.
**Verified — this is the decisive test:** for all 76 accounts × every key in their `active_bounties`,
generate the 25 missions on both servers and diff. Any difference means the RNG port is wrong and the
phase is not done. Then: buy an item and confirm AP/unlocks match; confirm a client that sends a
tampered `save_cosmetics` with inflated `ap` no longer has it accepted.

**Also run the offline fixture suite** (`backend_port/bounty/compare.ts`) in CI: 347 engine-captured
cards, the hash and RNG primitives, and a constraint check against real save data. It is much faster
than the live diff and it localises a failure to a specific square. **It does not replace the live
diff** — `ausers/*.dat` stores only the 25 per-square progress *counts*, never the mission list, so the
strongest offline check available is "stored progress ≤ my reproduced required count" (200 constraints
across 8 real cards, 0 violations, and a negative control that produced 19). That is strong evidence,
not a byte-diff. Keep the old-vs-new `bounty_missions` frame diff as the hard gate.

### Phase 5 — Campaign and admin

**Implements (campaign, 8):** `campaign_enter`, `campaign_travel`, `campaign_arrive`,
`campaign_activation_complete`, `campaign_choice`, `campaign_abandon`, `campaign_set_party`,
`campaign_set_vessel_skills`. (`campaign_start_battle` is Phase 6 — it seats a match.)
**Implements (admin, 13 — `admin_toggle_creator` is dropped):** `admin_announce`,
`admin_list_players`, `admin_modify_player`, `admin_season_reset`, `admin_maintenance`,
`admin_toggle_global_chat`, `admin_character_stats`, `admin_close_nexus_round`,
`admin_scale_nexus_ap`, `admin_training_status`, `admin_get_bot_tuning`, `admin_set_bot_tuning`,
`admin_fetch_training_replay`.
**Emits:** `campaign_state`, `campaign_error`, `announcement`, `admin_players`,
`admin_modify_result`, `admin_season_reset_result`, `admin_character_stats`, `admin_training_status`,
`admin_bot_tuning`, `admin_bot_tuning_saved`, `maintenance_*`, `nexus_round_closed`, `nexus_scaled`,
`replay_data`, `replay_result`, `global_chat_state`.

* Campaign: pure intent/echo against the *shared* `campaign_*.json` rule tables; every rejection ships
  the authoritative state so the client reverts its optimism; `pending_wins` scoped to the activation.
* Maintenance: **warn → eject → cancel**, with `_maintenance_stand_down()` running **before** the
  eject broadcast, and admins excluded from it (contract §2.7 — both details are load-bearing:
  skipping the stand-down forfeits ejected players via the AFK timer).
* Season reset: dry-run by default, requires `dry_run:false` **and** the exact phrase `"RESET SEASON"`,
  and takes an automatic `ausers/` backup that must succeed or the reset aborts.
* Chunked replay streaming (`REPLAY_CHUNK` = 24 000 chars) through the queued send path.

**Done:** every admin panel tab functions in the real client; campaign intents accepted/rejected
identically to the baseline.
**Verified:** admin ops driven by harness with a ZZ_ admin-equivalent on a staging copy —
**never against real `ausers/`**; season reset exercised **dry-run only** plus one real run against a
throwaway directory with the backup verified; campaign scenario recordings diffed against the
baseline. Note the client currently hides campaign behind `CAMPAIGN_ENABLED = false` (`app.js:24`),
so this phase is harness-verified rather than browser-verified — say so, don't claim a browser pass.

### Phase 6 — Matchmaking and the seam

**Implements:** `queue_quick`, `queue_ranked`, `queue_private`, `queue_bot`, `cancel_queue`,
`campaign_start_battle`, plus the routing shells for `submit_turn_input`, `surrender`, `spectate`,
`spectate_leave`, `replay_fetch`.
**Emits:** `receive_queue_rejected`, `receive_quick_match`, `receive_ranked_match`,
`receive_private_match`, `receive_campaign_match`, `apply_turn_result` (via the stub handler),
`ranked_result`, `spectate_init`, `spectate_result`, `receive_opponent_disconnect_notification`,
`receive_opponent_reconnect_notification`.

* Queues with the exact semantics: short teams (<3) rejected on **every** entry point; ranked enqueue
  idempotent (release first); rating-gated pairing swept at 1 Hz with the `GATE_BANDS` multipliers of
  the 20 s ranked bot delay (bands ≥400 rating deliberately exceed it, so distant players meet a bot
  first — the 5 bands and `MM_TICK` are in `data/server/matchmaking.json`, alongside
  `ADMIN_USERNAMES`); quick's per-player `bot_queue_delay` fallback clamped ≥15 s; private pairing on **mutual**
  invite only; self-invites refused with `receive_queue_rejected` (**not** `error` — only that handler
  clears the client's optimistic `queued` flag).
* The **seam** (§4) + `StubMatchHandler` + `NullMatchHandler`.
* The full result-bookkeeping path in `onResult`: the AP table, ranked-only W/L and rating (with the
  ×0.1 win cap / ×0.5 loss scale vs bots), clan W/L, bounty progress, mastery XP, stats rows,
  `match_history`, `ranked_result`, `receive_player_update`, replay write.
* Spectate eligibility + the single generic denial; the 120 s disconnect → auto-surrender branch;
  the AFK clock and its penalty ladder.

**Done:** two harness clients queue, pair, receive the correct match-start frames, exchange stub
turns, and the match ends with every account side-effect correct.
**Verified:**
(a) AP payouts match the table for all five queue/outcome combinations;
(b) rating deltas match the Godot server for the same before-state (feed both the same rating pair);
(c) ranked pairing timing: two accounts ≥400 rating apart meet **bots**, not each other;
(d) a disconnect mid-match auto-surrenders after 120 s, and a reconnect at 119 s does not;
(e) three consecutive turn timeouts forfeit, and the miss streak survives a reconnect;
(f) a spectator cannot surrender, cannot submit a turn, cannot read match chat.

### Phase 7 — Parity soak and staging

* Run the full scenario catalogue against both servers; diff normalised frames (ignore `boot_id`,
  timestamps, `seed`, and match ids). Every non-empty diff is either a bug or an *intentional*
  deviation that gets written down in a deviations list.
* Deploy to the box on a **second port** with a **copied** `ausers/`, behind a staging hostname.
* Closed beta: the owner plus 2–3 trusted players, on the copy, for a week of lobby/social/queue use
  (matches will be stubs until Milestone 2 — set expectations).
* Memory/fd soak: 24 h with the harness connecting/disconnecting, to catch leaks (the Godot server
  had real ones — leaked matches keeping live turn timers, `server_connection.gd:3650` and `:3679-3683`).

**Done:** zero unexplained frame diffs; a week of staging with no crashes; the deviations list is
short and deliberate.

### Milestone 2 (separate project, not planned here)

Battle execution + the new Creator, plugged in as a `MatchHandler` (§4). Its own acceptance criteria
are `WIRE_CONTRACT.md` §9 Milestone 2 and `MATCH_PROTOCOL.md` §2–3.

### Phase 8 — Cutover

See §6 below.

---

## 6. Cutover

### 6.1 The recommendation

**Parallel staging on a second port for the whole build, then one hard flip after Milestone 2, with a
30-second rollback.**

Concretely:

1. Throughout phases 1–7, the new server runs on the box (or locally) on **port 5795** against a
   **copied** `ausers/`. The Godot server keeps 5695 and the real data. **Never point both at the same
   account directory while both accept logins** — two servers with in-memory account copies will
   overwrite each other's writes.
2. Staging is reachable via a second nginx server block (e.g. `staging.<domain>` → 5795) so the real
   client can be pointed at it. Note the production client hardcodes
   `wss://server.animaslashanimearenaserver.org` and honours `?ws=` **only on dev origins**
   (`app.js:38-53`) — deliberately, so a crafted link cannot redirect a production login. For staging,
   either serve the client from a dev-origin host, or set `window.AA_WS` on a staging copy of the page.
3. **No production flip until the battle handler exists.** A lobby that cannot run matches is not a
   game server.
4. When Milestone 2 is done and soaked: announce maintenance through the *existing* flow
   (`admin_maintenance warn` → `eject`), stop the Godot process, **back up `ausers/` + `clans/` +
   both `.db` files**, start the new server on 5695, reload nginx. Total downtime: a couple of minutes.
5. Watch for a full evening. Keep the Godot binary on the box, untouched.

### 6.2 Why not the alternatives

| Option | Verdict |
|---|---|
| **Shadow traffic** (mirror live frames into the new server and compare) | Attractive, but this protocol is **stateful and side-effectful** — a mirrored `friend_accept` or `donate` mutates real accounts, and a mirrored `login` collides with the real session. Making it safe means a full dry-run mode, which is more machinery than the scenario harness and proves less. **Rejected.** The harness + baseline recordings give the same evidence with none of the risk. |
| **Gradual flip** (some players on the new server) | Impossible: matchmaking, friends, chat and clans are **global state**. Two servers means two disjoint player populations who cannot see or play each other. **Rejected.** |
| **Split-brain proxy** (new lobby delegates matches to Godot over a local socket via a `GodotProxyMatchHandler`) | Would let you flip before Milestone 2. But it requires building a *new match-only RPC surface inside the codebase you are deleting*, and the Godot match path is entangled with the very things the new server would own — `Match.from_players` takes live `Player` objects (`match.gd:102`) and `handle_server_match_ended` does all the account bookkeeping (`:3642`). You would be writing throwaway Godot code that duplicates the seam's hardest part. **Rejected** unless Milestone 2 slips badly — at which point revisit it as a deliberate bridge, not a shortcut. |
| **Hard flip with no staging** | No. |

### 6.3 Rollback

**The rollback plan is what makes this safe, so it is a design constraint, not an afterthought:**

* **Keep `ausers/*.dat` format-identical** (§3.1). That is what makes rollback "stop process A, start
  process B" instead of "reverse-migrate under pressure".
* Rollback procedure: stop the new server → (optionally restore the pre-flip `ausers/` backup;
  usually unnecessary because the format is compatible) → start the Godot binary → nginx reload. The
  client needs no change and no redeploy because the URL never moved. **This is the strongest argument
  for flipping at the nginx/upstream layer rather than by editing the client's hardcoded URL:** a
  client change means a Cloudflare Pages redeploy and cache propagation, and rollback would inherit
  both.
* **The point of no return is the first schema-breaking write.** Two candidates: password hashing
  (§7.2 D3) and any account-field addition. **Do neither for at least two weeks after the flip.** Write
  the date on the calendar.
* Rollback *loses* whatever happened on the new server after the last backup if you restore files.
  Take a backup at flip time and hourly for the first day.

### 6.4 Verifying parity before the flip

The protocol doc is the acceptance criteria; here is how it actually gets exercised:

1. **Boot assertion** (§2.4): the router's message set must equal `wire_contract.json`'s inbound list
   minus the documented exclusions. Runs on every start, forever.
2. **Scenario catalogue** (Phase 0 onward): every scenario recorded against the Godot baseline and
   re-run against the new server, frames normalised and diffed. Target coverage: every one of the 76
   in-scope inbound types appears in at least one scenario, and every one of the 71 outbound types is
   observed at least once. Track the coverage number — it is the honest measure of "how much of the
   contract is actually tested".
3. **Data proofs**: the account round-trip (§3.2 step 3), the bounty RNG diff (Phase 4), the rating
   delta comparison (Phase 6).
4. **Reference-data drift checks** — these exist and pass today, and should run in CI from Phase 0:
   `python tools/reference_data.py` (no Godot — re-derives `data/` from the `.gd` source, exit 1 on
   drift), `tools/check_extraction_vs_godot.gd` (read-only, proves parsing == running),
   `tools/check_split_desc_sync.gd` (read-only, guards the `ability_split.json` freeze — §3.5), and
   `backend_port/bounty/compare.ts`. The first three need Godot only until the binary is deleted;
   after that, `reference_data.py` and `compare.ts` are the survivors and the `.gd` sources become
   historical.
5. **Real-client passes**: a scripted manual checklist per phase, in a real browser, against the real
   client. The harness cannot catch a frame the client silently ignores because a field was renamed.
6. **Rollback-compat check every phase**: an account written by the new server still loads in the
   Godot server (§ Phase 2 verification b).
7. **`boot_id` behaviour**: it is the only reliable "different server" signal, regenerated per process
   (`"<unix>_<randi>"`). Ejected clients poll `server_status` every 3 s and reload on a change, and
   the client calls `noteBootId()` on any frame carrying one. Verify the new server's `boot_id` shape
   and that a restart makes idle clients reload — otherwise the flip leaves players on a stale client.

---

## 7. Security: what must be preserved, what must be fixed

### 7.1 Must preserve (from `WIRE_CONTRACT.md` §3 — all 38 invariants)

Full text is in the contract; here is the grouping and the ones most likely to be lost in a rewrite:

| Group | Invariants | Rewrite risk |
|---|---|---|
| Identity & routing | 1–4 | **High.** #3 (re-check `peers[conn] === expectedUsername` before every match send) and #4 (four separate sites re-check that a spectator is not a player) are easy to drop. Make them *structural*: a single `sendToSeat()` that performs the check, and a `requireParticipant()` guard the router applies to `submit_turn_input`, `surrender`, `chat_send{match}`, `chat_history{match}`. |
| Admin | 5–9 | **Medium.** #5 is exact-case on purpose (the filesystem is case-sensitive; a case-insensitive check would let someone register `cheshire` and inherit admin). #6 rejects case-variants at registration. Router-level `auth:"admin"` covers #7 mechanically. |
| Path traversal | 10–13 | **Low if structural.** Put the rejection in the store layer (§3.1), not in handlers. |
| Economy & progression | 14–21 | **High.** #21 (the server-only field list) is the one that silently breaks: if the new `absorb` is written by iterating the payload's keys instead of a whitelist, a modified client forges its own friend list and un-mutes itself. **Write it as an explicit allow-list, never a deny-list.** |
| Matchmaking & teams | 22–27 | **Medium.** #26 is subtle: refusals must use `receive_queue_rejected`, not `error`, because only that handler clears the client's optimistic `queued` flag. |
| Privacy / oracle-freedom | 28–36 | **High.** These are single shared strings (`SPECTATE_DENY`, `"Replay not available"`) that a rewrite naturally "improves" into helpful specific messages — turning them into existence oracles. Make them constants with a comment saying why they are vague. |
| Turn validation | 37–38 | **Deferred** to Milestone 2, but note #38: a rejected turn must answer `error {reason}` so the client re-enables its UI immediately. |

Also preserve: **rate limits keyed by a bounded action name** (never by user input), and the
**`receive_queue_rejected` vs `error`** distinction above.

### 7.2 Known holes — decision points, with recommendations

> **A factual correction to the brief.** The brief describes "legacy `@rpc("any_peer")` handlers with
> account overwrite/delete vulnerabilities" as still present. **They are not.** `actually_start_server`
> no longer binds the legacy `WebSocketMultiplayerPeer` server on port 5696
> (`server_connection.gd:712-718`) and there are **zero** `@rpc` decorators left in the file — the 3
> remaining `@rpc` occurrences (`:715`, `:872`, `:4837`) are all inside comments describing the
> removal. Verified with `grep -n '@rpc' components/server_connection.gd`. That class of hole was closed
> when the desktop client was retired. What genuinely remains from that family is the **non-atomic,
> fail-open save** — and the client-authoritative economy, which is a different bug with the same
> consequence.

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| **D1** | **The shop is fully client-authoritative.** No `buy` message exists; `buyShopItem()` does `S.player.ap -= price` locally and persists via `save_cosmetics`, and `absorb_cosmetic_update` accepts `ap`, `unlocks`, `title`, `clan`, `characters`, `bounty_rerolls`, `active_bounties` verbatim. A modified client grants itself arbitrary AP and any unlock. | contract §3.8, §7.3 | **FIX in Phase 4.** Add `buy {item_id}`; remove `ap`, `unlocks`, `active_bounties`, `bounty_rerolls` from the absorbed set. Requires a coordinated client change — the only client change this whole project needs. |
| **D2** | **Bounty square progress is client-written**; only the final claim is re-validated, and it re-validates *against the client-supplied progress array*. | contract §3.8 | **FIX in Phase 4**, with D1. The server already recomputes progress at match end (`check_all_bounties`); make that the only writer. |
| **D3** | **Passwords are plaintext** on disk, on the wire, in `localStorage`; and `pass_hash` is **echoed back to the owning client** inside `receive_login_response` / `receive_player_update`. | contract §3.8, F4 | **Two-stage.** Stage 1 (**Phase 1, free**): strip `pass_hash` from every outbound frame. Stage 2 (**≥2 weeks after cutover**): hash with argon2id/bcrypt, upgrading each account on its next successful login (compare plaintext if the stored value is not a hash). ⚠ Stage 2 **breaks rollback** — the Godot server compares plaintext. Do not do it while rollback matters. |
| **D4** | **Non-atomic, fail-open account saves.** `save_player` opens `WRITE` (truncating) with no null check and calls `store_line` on a possibly-null handle. | `server_connection.gd:1846-1853` | **FIX in Phase 2**, unconditionally. Temp-file + fsync + rename. This is pure upside with no protocol or format change. |
| **D5** | `nexus_state` and `ladder` **require no authentication**. | contract F6 | **Decide.** Note the real client only ever requests them from a post-login menu overlay (`app.js:1645-1646`), so requiring a session would break nothing today. Recommendation: **require a session** — it is the safer default and costs nothing — unless the owner wants a public leaderboard page later, in which case keep them open, rate-limit them, and write the reason in a comment. Either way, make it a decision. |
| **D6** | **The ranked draft path is entirely dead code** — `start_ranked_draft()` has zero callers, so `draft_start`/`draft_update` are never emitted and `submit_ban`/`submit_pick`/`lock_bans`/`draft_hover` can only answer "No active draft". Ranked uses blind picks. | contract F3 | **Decide.** Recommendation: **do not port it.** Delete the four inbound types and two outbound types from the new server, and note in the boot assertion's exclusion list that this was deliberate. If drafting is wanted, design it fresh with Milestone 2. |
| **D7** | `receive_register_response` success is decided **client-side by a regex** `/success/i` on a human-readable message. | contract F8 | **Add `ok: bool`** and change both sides together (bundle with the D1 client change). Keep the message field for compatibility. |
| **D8** | `admin_toggle_global_chat` is **not persisted** (restart re-enables global chat) while `admin_toggle_creator` **is**. | contract F7 | **Decide.** Recommendation: persist it in `server_flags.json` alongside whatever replaces the creator flag. Trivial, and the asymmetry is surprising. |
| **D9** | Four frames are **double-JSON-encoded** (`receive_login_response.json_string`, `receive_player_update.json_string`, `receive_session_reconnect.info`, `spectate_init.info`). | contract F5 | **Send nested objects.** The client already handles both forms defensively (`typeof x === "string" ? JSON.parse(x) : x`), so this is free and needs no client change. Verify it in Phase 1 with the real client, not just the harness. |
| **D10** | `receive_surrender` is sent but has no client handler. | contract F2 | **Drop it.** |
| **D11** | The **entire Creator surface** (12 inbound + 12 outbound + `admin_toggle_creator`) is scrapped. The client already speaks none of it. | contract §4.13, F11 | **Do not implement any of it.** Also drop the `creator_enabled` flag from `server_flags.json`. |

### 7.3 Data decisions surfaced by the extraction and the RNG proof (new)

None of these are security holes, which is why they are their own table. All of them are things a port
will get silently wrong if nobody rules on them first, and all were found *after* the first draft.

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| **D12** | **Dormant tables with zero readers**: `rp_thresholds`, `ranked_streak_thresholds` (the removed promo-series design) and `title_data` (superseded by the client's `titles.json`). They read like live spec. | inventory §6.5 | **Do not wire them up.** They are extracted and labelled dormant so a port has the spec if that layer is ever rebuilt. Deciding to *delete* them instead is also fine — what is not fine is implementing them by accident because they were in `data/`. |
| **D13** | **`char_index.json` is stale and naively regenerating it makes things worse.** 657 rows vs 639 concepts; the 18 extras are characters promoted out of the Nexus onto the roster (`denji`, `power`, `levi`, `toji`, …) plus 4 that are neither. `extract_char_index.gd` rebuilds strictly from `all_chars`, so re-running it **deletes all 18** — and the client uses this file to resolve bounty-target and Nexus names/portraits. | inventory §6.1 | **Decide before Phase 0 regenerates anything.** Recommendation: **merge-forward** — keep the 18 rows so the UI can still resolve names it asks for, and have the replacement generator union `all_chars` with the existing file rather than overwrite. Pruning is defensible only after auditing what the client actually looks up. |
| **D14** | `initialize_buckets()` seeds **52 of 54** universes — `CHIVALRY_OF_A_FAILED_KNIGHT` and `CUSTOM` are missing. Harmless today (no concept uses either), but adding one **crashes boot** on `all_buckets[concept.universe]`. | inventory §6.5 | **Seed all 54 in the new server.** Costs nothing; removes a boot-time landmine. Don't "fix" the Godot server for it — that is a behaviour change. |
| **D15** | `extract_bounty_data.gd` writes with `JSON.stringify`'s default `sort_keys = true`, so the shipped `bounty_data.json` has **alphabetised** `categories` while generation depends on **insertion** order. | §1.1 box; verified — client copy starts `air`, source starts `sword` | **Pass `sort_keys = false` in the replacement generator**, and keep generating from `data/bounty/bounty_tables.json`. Harmless today because the client only does membership/display lookups — but it is a loaded gun aimed at whoever next points a generator at that file. |
| **D16** | **Two defects in `bounty.gd`'s tables.** `archetypes` contains `"non human"`, which is not a `categories` key (unreachable today; `check_bounty_progress` would throw). `categories["lightning"]` contains the string `"lightning"`, which is not a character — **reachable**, and it yields an uncompletable bingo square. | inventory §6.3; RNG stage confirmed 0 occurrences of `"non human"` across 4 325 engine + 43 500 generated squares | **Copy both verbatim into the port. Do not clean them.** ⚠ The dangerous "fix" is promoting `"non human"` to a real `categories` key: that inserts a 36th key, shifts the archetype list of every member, and **rerolls every affected board**. Deleting the dead `archetypes` entry changes zero cards and is safe. `lightning` is a genuine content bug — fix it as *content*, deliberately, accepting that affected cards reroll. |
| **D17** | **The reference-data verifier is untracked.** `.gitignore:8` is a blanket `*.py`, which excludes `tools/reference_data.py`, `tools/gdlit.py` and the Python half of the bounty proof. | `git check-ignore -v` | **Add a negative exception** (`!tools/**/*.py`, `!backend_port/**/*.py`). The drift check is worthless if it is not in the repo the drift happens in. |
| **D18** | **`ability_split.json` cannot be generated without Godot** and is the single remaining hard dependency. | §3.5 | **Freeze it as authored content**, keep `tools/check_split_desc_sync.gd` in CI until the `.gd` abilities are gone, and have the Milestone-2 ability format emit its own segments. Confirm the owner accepts "frozen" rather than "regenerable" for the interim. |

---

## 8. Risks and open decisions, ranked

### 8.1 Risks

1. **This is a full rewrite of a live system, and the largest, most intricate part — the battle engine
   — is deliberately not covered here.** `new multiplayer/battle_manager.gd` alone is 135 KB, plus
   **1 020** ability scripts (the first draft guessed ~500) and the shared engine files, driving 1 087
   rows of `abilities_data.json`. Milestone 1 is maybe a third of the work by
   volume and much less than that by difficulty. **Nothing in this roadmap ships a playable game.**
   Plan Milestone 2 as a project of comparable or greater size, and do not let Milestone 1's
   completion create pressure to flip early.
2. **Long unshipped branch.** Phases 1–7 produce months of code that never faces real players. Drift
   and untested assumptions accumulate. Mitigation: the scenario harness and the per-phase real-client
   pass are non-negotiable, and the staging deployment should go up at Phase 3, not Phase 7.
3. **Silent behavioural divergence.** The contract documents 89+71 message types but not every
   behaviour — ordering, exact reply counts, which mutations push `receive_player_update`. A frame
   diff catches most of it; a missing frame that the client tolerates today will not be caught by
   anything except a human playing. Budget real playtesting.
4. **Account loss.** Mitigated by format preservation, atomic writes, backups, and the round-trip
   proof — but it is the failure that cannot be undone. Never run verification tooling against the
   real `ausers/`; ZZ_-prefixed accounts on copies only.
5. **The bounty RNG port — downgraded from "solved" to "solved, and here is the landmine".** If
   Godot's `hash()` or PCG32 is reproduced even slightly wrong, every in-flight bingo card silently
   scrambles and players lose progress they can see. This document originally called it a known-solved
   problem and stated the wrong spec for `randi_range`; **building to that spec produces a wrong card
   for 37 of the 174 roster characters**, with no error anywhere. It is now genuinely proven — two
   independent non-Godot ports reproduce 347/347 engine cards — but the mitigation is *use the proven
   port* (`backend_port/bounty/bountyGen.ts`) and *run both the fixture suite and the live frame diff*
   (Phase 4), not "re-derive it, it's easy". Residual exposure: every fixture came from Godot
   4.6.2-stable, so if the deployed binary is a different version the primitives must be re-captured
   against **that** version before cutover (Phase 0). Second residual: the `bounty_types.is_empty()`
   fallback branch is unreachable in production today (all 174 roster characters have ≥1 archetype)
   and is proven only via an off-roster path — it goes live the moment a character ships in no
   category.
6. **Reference-data drift after the Godot binary is deleted.** `data/` is a *mirror*: today its
   correctness is guaranteed by re-deriving it from the `.gd` sources. Once those sources stop being
   the truth, that guarantee inverts and `data/` becomes the source with nothing checking it. Two
   consequences to plan for: (a) `ability_split.json` must be frozen as authored content with
   `check_split_desc_sync.gd` in CI until the ability format changes (§3.5); (b) the extraction tooling
   is currently **gitignored** by a blanket `*.py` rule, so the check that guards all of this is not
   even in version control (D17). Fix that before it matters.
7. **The seam could be wrong.** §4 is designed against today's code, but Milestone 2 may discover it
   needs something the seam does not carry. Mitigation: `StubMatchHandler` exercises the boundary from
   day one, and the interface is small enough to extend deliberately. The failure mode to *avoid* is
   letting Milestone 2 reach around the seam "just this once".
8. **Solo bus factor.** One person plus AI, no reviewer. Mitigation: the boot conformance assertion,
   the harness, and this document plus `WIRE_CONTRACT.md` as the durable spec.
9. **Concurrency regressions if Go is chosen** (§1.2) — a real risk, called out so the choice is made
   with eyes open.

### 8.2 Open decisions, ranked by how much they block

| # | Decision | Recommendation | Blocks |
|---|---|---|---|
| 1 | **The stack** (§1) | Node.js + TypeScript; Go is the runner-up | Everything |
| 2 | **Migration approach** (§3.1) | Read `ausers/*.dat` as-is; SQLite consolidation later, as its own project | Phase 2 |
| 3 | **Cutover shape** (§6) | Parallel staging on 5795; one hard flip after Milestone 2; nginx-layer rollback | Phase 7 |
| 4 | **Fix the client-authoritative shop + bounty progress** (D1, D2) | Yes — add `buy`, shrink the absorbed field set. It requires the one client change of the project; bundle D7's `ok` flag with it | Phase 4 |
| 5 | **Password hashing** (D3) | Strip `pass_hash` from the wire immediately; hash on disk only ≥2 weeks after cutover, because it breaks rollback | Post-cutover |
| 6 | **The dead draft surface** (D6) | Delete it. Do not port dead code as if it worked | Phase 6 |
| 7 | **Auth on `ladder` / `nexus_state`** (D5) | Keep public, rate-limit, comment the decision | Phase 2/4 |
| 8 | **Persist `admin_toggle_global_chat`** (D8) | Yes | Phase 5 |
| 9 | **Nested objects vs double-encoded strings** (D9) | Nested; the client already accepts both | Phase 1 |
| 10 | **Does the match handler stay in-process?** (§4) | In-process for Milestone 2; keep the interface serialisable so it can move later without a protocol change | Milestone 2 |
| 11 | **What happens to bot training** (`training/`, `bot_tuning.json`, the policy) | Out of scope here — it is battle-side. Milestone 1 only reads/writes the files for the admin panel. Flag it so it is not forgotten at Milestone 2 planning | Milestone 2 |
| 12 | **`char_index.json` regeneration policy** (D13) | Merge-forward, not prune — the client still resolves those 18 names | Phase 0 |
| 13 | **Track the extraction tooling in git** (D17) | Yes, one `.gitignore` line. The drift check must live in the repo it guards | Phase 0 |
| 14 | **Freeze `ability_split.json`** as authored content, with the sync checker in CI (D18) | Yes — it is the only dataset that still needs Godot, and it is exact today | Phase 0 → Milestone 2 |
| 15 | **The two `bounty.gd` table defects** (D16) | Port both **verbatim**. Never promote `"non human"` to a category — that rerolls live boards. Treat `lightning` as a separate, deliberate content fix | Phase 4 |
| 16 | **Dormant tables: keep as spec or delete?** (D12) | Either — but do **not** implement them. They have no readers today | Phase 2/4 |

**A note on the shape of the last five.** They exist because the first draft asserted a two-item data
inventory that turned out to be fifteen. The general lesson worth carrying into Milestone 2: in this
codebase, *data that looks like configuration is frequently code*, and the only reliable way to tell
is to run the engine and compare. Both new checkers do exactly that, and both should outlive this
document.

---

## Appendix A — every in-scope inbound type, by phase

76 in-scope types (89 total − 12 Creator − `admin_toggle_creator`). Battle types are routed in Phase 6
but resolved in Milestone 2.

| Phase | Count | Types |
|---|---|---|
| 1 — auth/session | 5 | `ping`, `server_status`, `login`, `register`, `change_password` |
| 2 — player/ladder | 5 | `save_cosmetics`, `get_player_profile`, `reset_own_record`, `social_setting`, `ladder` |
| 3 — social | 10 | `social_state`, `friend_request`, `friend_accept`, `friend_decline`, `friend_cancel`, `friend_remove`, `ignore_add`, `ignore_remove`, `chat_send`, `chat_history` |
| 3 — clans | 16 | `clan_state`, `create_clan`, `clan_search`, `clan_apply`, `clan_cancel_application`, `clan_invite`, `clan_cancel_invite`, `clan_accept_invite`, `clan_decline_invite`, `clan_approve_application`, `clan_deny_application`, `clan_kick`, `clan_leave`, `clan_disband`, `clan_reset_record`, `clan_set_banner` |
| 4 — economy | 4 (+1 new) | `bounty_missions`, `complete_bounty`, `nexus_state`, `donate` **+ `buy` (new)** |
| 5 — campaign | 8 | `campaign_enter`, `campaign_travel`, `campaign_arrive`, `campaign_activation_complete`, `campaign_choice`, `campaign_abandon`, `campaign_set_party`, `campaign_set_vessel_skills` |
| 5 — admin | 13 | `admin_announce`, `admin_list_players`, `admin_modify_player`, `admin_season_reset`, `admin_maintenance`, `admin_toggle_global_chat`, `admin_character_stats`, `admin_close_nexus_round`, `admin_scale_nexus_ap`, `admin_training_status`, `admin_get_bot_tuning`, `admin_set_bot_tuning`, `admin_fetch_training_replay` |
| 6 — queue/seam | 6 | `queue_quick`, `queue_ranked`, `queue_private`, `queue_bot`, `cancel_queue`, `campaign_start_battle` |
| 6 — routed, M2-resolved | 5 | `submit_turn_input`, `surrender`, `spectate`, `spectate_leave`, `replay_fetch` |
| **Dropped** | 4 + 13 | draft: `submit_ban`, `submit_pick`, `lock_bans`, `draft_hover` (D6) · Creator: 12 `authored_*` + `admin_toggle_creator` (D11) |

## Appendix B — source anchors used

| Claim | Anchor |
|---|---|
| Inbound dispatch | `components/server_connection.gd:752` (`_on_json_message`), `:770` (`match t:`) |
| Session lookup = auth | `components/server_connection.gd:322` (`get_player`), `:329` (`get_session`) |
| Rate limiter | `components/server_connection.gd:470-484` (`_rate_ok`) |
| Admin gate | `components/server_connection.gd:427` (`_is_admin`), `:447` (`_admin_get_target`) |
| Account read/write | `components/server_connection.gd:1807` (`load_player`), `:1846` (`save_player`, **no null check**), `:1868` (`resave_player`, writes the global cache) |
| Login / register | `components/server_connection.gd:1609` (`_process_login`), `:1938` (`_process_register`) |
| Disconnect / wipe | `components/server_connection.gd:1495` (`handle_disconnect`), `:1562` (`wipe_session`) |
| Queue entry / gate / bot fallback | `:1446` (`_json_enqueue`), `:2593` (`_gate_tick`), `:2383` (`_start_bot_fallback`) |
| Match seating | `:2306` (`start_quick_match`), `:3379` (`start_ranked_match`), `:2125` (`start_private_match`), `:2619` (`start_bot_match`) |
| Match construction + sink guard | `components/match.gd:86` (`_holds_live_match`), `:102` (`from_players`), `:104-130` (the SINK GUARD comment + refusals) |
| Post-match bookkeeping | `components/server_connection.gd:3642` (`handle_server_match_ended`), `:1894` (`_calculate_ap_gain`), `:1906` (`_send_post_match_player_updates`), `:3620` (`_send_ranked_result`) |
| Turn broadcast + identity re-check | `components/server_connection.gd:3840` (`_broadcast_turn_result`), `:3852` |
| Spectator stripping | `:5328` (`_spectator_safe_events`), `:5336` (`_spectator_safe_snapshot`) |
| AFK timer / forfeit | `components/match.gd:711` (`_timer_seconds_for`), `:732` (`_refresh_timer_pause`), `:753` (`_forfeit_afk_player`), `:765` (`handle_turn_timeout`) |
| Transport | `webclient/json_gateway.gd` (whole file; `:70` `poll`, `:134` `send_queued`, `:39` `_OUT_HEADROOM`, `:153` headroom check) |
| Client keepalive + URL | `webclient/app/net.js:18-24`, `webclient/app/app.js:24` (`CAMPAIGN_ENABLED`), `:38-53` (`defaultServerUrl`) |
| Legacy RPC removal | `components/server_connection.gd:712-718` (`actually_start_server`), `:18` (`TARGET_PORT = 5696`, idle) |
| Bounty RNG | `scripts/bounty.gd:224-328`, categories at `:172` (a byte-identical duplicate at `:129`, `flat_bounty_categories`, has **zero callers** — safe to delete) |
| Bounty RNG **proof** | `backend_port/bounty/` — `bountyGen.ts` + `compare.ts` (reference port), `godot_primitives.py` + `bounty_gen.py` + `compare.py` (independent second port), 6 fixtures; engine probes at `training/tests/bounty_*_probe.gd` |
| `randi_range` degenerate-range short-circuit | `RandomNumberGenerator::randi_range` → `RandomPCG::random(int,int)`; captured empirically in `backend_port/bounty/primitives_fixture.json` |
| Campaign rule tables | `scripts/campaign.gd:10-12` |
| Character list (174) | `scripts/character_database.gd:3` → extracted to `data/characters/character_lists.json` |
| Reference data (all 15 trapped datasets) | `REFERENCE_DATA_INVENTORY.md`; `data/**`; `data/README.md` |
| Reference-data verifiers | `tools/reference_data.py` (no Godot), `tools/check_extraction_vs_godot.gd`, `tools/check_split_desc_sync.gd` (both read-only) |
| Generator pipeline | `extract_char_index.gd`, `extract_bounty_data.gd`, `extract_ability_info.gd`, `extract_split_desc.gd`, `regenerate_character_colors.gd` (all repo root) |
| SQLite schemas | `components/mastery_db.gd:26-38`, `components/stats_db.gd:1-40` |
| Replay format | `components/match_replay_log.gd:1-40` |
| Deploy target / host | `deploy.ps1:34-38`, `build-pages-deploy.ps1` |
| Local run | `LOCAL_TESTING.md` |
