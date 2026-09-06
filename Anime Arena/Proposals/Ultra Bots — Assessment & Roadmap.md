---
tags: [area/architecture, type/proposal, area/matchmaking, area/bots]
---
# Ultra Bots — Assessment & Implementation Roadmap

> Short-term player-retention system: static, persistent, player-like bot entities that log in, queue,
> and play real games against humans and each other, so a low-population queue still feels alive.

## Verdict

**Sound and worth building. The hard part is smaller than it looks.** The scariest requirement —
"actively register, log in, queue, match, and play" — is ~70% already implemented, because the server
*already* runs bots as **peer-less, server-driven virtual players**. No headless client, no fake sockets,
no second process is required.

The real work is turning today's *ephemeral, opponent-only, always-player-2* bot into a *persistent,
self-queuing, either-seat* one, plus four smaller behavior layers (enhanced energy, variable think-time,
surrender-if-behind, a daily rotation scheduler). None of it fights the architecture; most of it hangs off
seams that already exist.

**Overall effort: medium.** Roughly six focused server-side seams + four independent behavior layers, all
localized to `components/server_connection.gd`, `scripts/player_component.gd`, and the battle engine. No new
subsystems, no schema rewrites, no transport changes.

The one correctness-heavy area is **turn-driving generalization** (making a bot's turn advance when it's
seated through the *normal* queue, and when *two* bots face each other) — get that wrong and a bot silently
freezes and AFK-forfeits. Everything else is additive and testable in isolation.

---

## The key architectural insight

A live bot today is **not** a networked client. It is (all in `components/server_connection.gd`):

- A **synthetic negative peer id** (`_bot_peer_counter`, `BOT_PEER_BASE := -1000`, tested by `_is_bot_peer`
  at :3310). Real web peers are `>= 1e9` (`_is_json_peer`); the ranges can never collide.
- A **Player object with no socket, no `ServerSession`, no `peer_map` entry** (`_make_server_bot` :2908).
- Whose **turns are driven internally** by `_drive_bot_if_acting` (:3314) → `_run_shadow_bot_turn` (:3350),
  which calls `enemy.perform_turn_v3()` / `perform_turn_contextual()` **directly on the authoritative
  shadow** `BattleManager`. No input frame is ever received.
- Whose **outbound packets are already no-ops** — `_broadcast_turn_result` only sends to participants that
  exist in `peer_map` (:3877), and `json_gateway.send` drops anything without a live socket.

So the server can already advance a full game where one seat is a machine with no client. **Ultra Bots
generalize this from "a throwaway opponent conjured for one human" to "a durable account that lives in the
queue."** That reframing is the whole project.

---

## How the touched systems work today (grounding)

| System | Reality today | Key refs |
|---|---|---|
| **Bot brain** | v3 linear policy (`perform_turn_v3`) over `BotObservation`; legacy contextual fallback. Difficulty = softmax temperature from `bot_tuning.json` (hot-reloaded). ~250 abilities give `custom_behavior` hints. | `player_component.gd:1195`, `training/bot_policy.gd`, `bot_observation.gd`, `battle_manager.gd:29-78` |
| **Turn timing** | Already a **variable** `randf_range(4.0, 9.0)`s "think" pause — but state-*independent*, and it runs *before* the board is evaluated. The persisted `bot_turn_delay` setting is a **decoy**: the live driver ignores it. | `server_connection.gd:3333`; `bot_turn_delay` at `player_component.gd:52` |
| **Bot surrender** | **Does not exist.** Not active, not dormant, not commented out. Only humans/AFK surrender. The "older handling" the proposal remembers is gone — this is net-new. | `send/process/finalize_surrender` (:4015+); AFK template `match.gd:_forfeit_afk_player:753` |
| **Seating** | Bot is a fallback opponent only: quick after the queuer's `bot_queue_delay`, ranked after fixed `RANKED_BOT_DELAY := 30`, or the Bot button. Always seated as **p2 / the "waiting" seat**. | `start_bot_match:2639`, `_start_ranked_bot_fallback:2411` |
| **Queue** | Quick = flat `queued_players{peer→[player,chars]}`. Ranked = `ranked_queue{rank→tier→[[peer,player,chars]]}` swept at 1 Hz (`_gate_tick`). Pairing (`_best_gated_ranked_pair`) is pure and only needs `get_player(peer)` to resolve. | `:127`, `:102`, `_collect_ranked_candidates:2543` |
| **Auth / identity** | One transport (JSON gateway, port 5695). Accounts = one JSON line at `ausers/<name>.dat`, **plaintext** `pass_hash`. Sessions keyed by `username`+`peer_id`, **decoupled from the socket**. Register/login are the only session-mint paths, and only off a live gateway peer. | `_process_login:1601`, `_process_register:1930`, `ServerSession:74` |
| **Cosmetics / avatar** | Full `equipped_*` block + `avatar_url` already on Player; **client-authoritative, no ownership validation**. Bots already draw a random avatar + player-card (`_apply_bot_cosmetics:2881`, with a deterministic `stable_key` mode). `display_package()` ships identity to opponents. | `player_component.gd:4-78, 168`, `AVATAR_DIR:2834` |
| **Energy** | `generate_team_energy` (`battle_manager.gd:1361`) → per-char `generate_energy()` rolls **uniform over the 4 real colors** via the **seeded** `battle.roll()`, ignoring the character's own `character_colors`. Server-authoritative; clients replay results via `energy_gained_event`. | `character_component.gd:467`, `character_colors:28` |
| **Persistence / scheduling** | `players` cache is authoritative over disk (editing `.dat` under a running server is silently reverted). **No time-of-day scheduler exists** — only elapsed-seconds Timers (1 Hz sweep, 15s ping, 30s ladder, daily replay sweep). | cache caveat `:547-551`; timers `:289-306` |

---

## Feature-by-feature assessment

### (core) Persistent, self-queuing, player-like entity
**Feasibility: high. Effort: medium.** This is the backbone the other features hang off.

What's reusable: the whole session/queue/match layer is socket-decoupled and only ever calls
`get_player(peer)`; `_make_server_bot` already builds a valid bot Player; the negative-peer + internal
turn-driver already prove a client-less seat works.

What must be built (the ~6 seams):
1. **A durable `is_ultra_bot` marker on Player** — added to `save()`/`load_player`, and **deliberately
   omitted from `absorb_cosmetic_update`** so a modified client can't flip its own account into a bot.
2. **A socket-less "virtual login"** that mints a `ServerSession` + `peer_map` entry from a persisted
   account with no inbound frame (today only `_process_login` does this).
3. **A reserved peer-id namespace** for logged-in bots, distinct from web peers (`≥1e9`) and the negative
   fallback-bot seats.
4. **Generalize the turn-driver gate** from `_is_bot_peer` (negative only) to also fire on `session.is_bot`,
   **and wire `_drive_bot_if_acting` into the normal seat paths** `start_ranked_match` / `start_quick_match`
   (today only `start_bot_match`/campaign call it). *This is the single highest-risk item.*
5. **`is_bot` skips at the 3–4 outbound sites** (`send_to_peer`, `_broadcast_turn_result:3877`,
   `_send_post_match_player_updates:1898`) so a bot in `peer_map` doesn't cause a `push_error` storm or
   spurious re-saves.
6. **A self-queue entry point** — push `[bot_peer, bot_player, chars]` into the queue and stamp
   `_ranked_wait_start`, driven by the scheduler (not the web-frame funnel `_json_enqueue`).

### (a) Variable think-time
**Already ~done. Effort: trivial.** The bot already pauses `randf_range(4,9)`s per turn
(`server_connection.gd:3333`). Making it state-dependent is a one-site change; the only wrinkle is the pause
currently runs *before* the decision is computed, so "think longer on complex boards" needs a cheap pre-pass
or reordering the pause to after decision / before broadcast. Per-bot bands can hang off `bot_tuning.json`.

### (a) Surrender-if-behind
**Net-new. Effort: moderate.** No code to revive. Build: a board-eval heuristic (HP totals, dead count,
energy) off `BotObservation`; a probabilistic gate at the top of the drive loop; and — critically — end the
match via the **session-less** path modeled on `match.gd:_forfeit_afk_player` / `handle_server_match_ended`,
**not** `finalize_surrender` (which needs a `ServerSession`). **Hard lesson to respect:** an earlier fixed-0
"STOP" pass in the policy caused a losing-streak death-spiral (20.7% winrate). Gate surrender on **real board
state**, never on policy-score sign.

### (b) Enhanced energy (75% own-color / 25% random)
**Feasibility: high. Effort: small.** Single choke point: `generate_team_energy`. Each character already
carries `character_colors`; each generated point rolls a 75/25 via the **seeded** `battle.roll()` (never
`randi_range`/`pick_random`, which would desync the shadow/replay). Decisions: what "own color" means when
`character_colors` is empty (→ fully random), and whether to allow `RANDOM (4)` to be picked (some chars list
it, e.g. `blackwargreymon = [3,4]`, and normal generation never emits RANDOM — clamp if undesired). Mirror
the second energy path `handle_opponent_timeout:1739` or accept it won't apply there.

### (c) Static name / avatar / cosmetics / preference
**Feasibility: high. Effort: small.** Every field already exists on Player (`avatar_url`, `equipped_*`,
`title`, `clan`, `equipped_characters` = preferred team). `_apply_bot_cosmetics` already does deterministic
faces via `stable_key`. Extend it to also set hats/frames/title, and pick cosmetic ids **from the same asset
pools** it already lists (unowned/unknown ids silently render as defaults — there's no ownership validation).

### (d) Time-of-day online rotation
**Greenfield, but small shape. Effort: medium (drags in session plumbing).** No scheduler exists. Add one
periodic tick (a `_ready` Timer, ~60s) that reads wall-clock and, per bot, brings it **online** (virtual
session + enqueue) inside its window and **offline** (dequeue + drop session) outside it. Design it
**stateless** — "who's online now" is a pure function of the current hour — so a restart can't lose it.

---

## Cross-cutting risks & required guardrails

1. **Frozen-bot / turn-driver gap (highest risk).** `start_ranked_match`/`start_quick_match` don't call the
   bot driver. A bot paired through the normal queue would sit on its turn until the AFK penalty forfeits it —
   looking like it "threw." *Must* wire the driver into those paths and gate on `session.is_bot`.
2. **Reap-on-sweep.** `_ranked_entry_verdict:2519` deletes any queued peer that doesn't resolve to a
   `get_player` **and** an ONLINE session whose `peer_id` exactly matches, within 1 second. All four
   conditions must hold or the bot vanishes from queue every tick.
3. **Null-deref on seating.** `start_ranked_match:3438` assigns `get_session(peer).current_match` for *both*
   seats — a session-less bot crashes the seating for the innocent human too. The virtual session fixes this.
4. **Server ping will kill a bot session.** `server_ping_cycle` (15s) rpc-pings every ONLINE non-JSON session
   and force-disconnects non-responders. A bot session must be **excluded** from that loop (and from
   `handle_disconnect`, maintenance eject, and the disconnect wipe timer).
5. **Bot-vs-bot alternation.** The current single-seat `_drive_bot_if_acting` loop advances *one* bot seat.
   Two bots facing each other need the driver to alternate across *both* bot sessions, or the game stalls.
6. **Ladder & records semantics — a real product decision.** Today bot games are suppressed/scaled via
   `winner.bot_player`/`loser.bot_player` (`:3684`), `RANKED_BOT_RATING_CAP`, and `clan_record_counts`. A
   *persistent* bot with `bot_player=true` still trips these. Decide: do Ultra-bot ranked games move **real**
   rating for the human (proposal implies yes)? Interacts directly with the just-reworked rating curve, and
   an easy-to-trigger surrender changes bot-farming economics.
7. **Leaderboard / stats / friends / admin pollution.** Bot accounts load into the `players` cache at boot and
   will appear on ladders, in `StatsDB`, clan records, friend search, and admin panels unless excluded.
   `StatsDB.is_excluded_user` is the existing precedent to extend.
8. **RNG determinism.** Enhanced energy (and any bot randomness that affects the board) must use the seeded
   `battle.roll()`. There is **no per-turn state hash** to catch a divergence — a subtle mismatch silently
   desyncs the pool rather than erroring.
9. **Persistence discipline.** Create/mutate bot accounts through live objects + `resave_player`, never by
   hand-editing `.dat` (the cache reverts it — the same trap [[Season reset]] hit). Reserve bot usernames so
   humans can't register them, and give each a stored (unguessable) `pass_hash`.
10. **Ephemerality inversion.** Today bot Players are freed in `Match.release_player_objects`. A persistent bot
    must **survive match teardown** (its team is rebuilt per match anyway).

### Non-technical decision: how invisible should they be?
The design intentionally makes bots indistinguishable from players — that's the point (a queue that *feels*
alive). That's a legitimate retention tactic, but worth a conscious call on two axes:
- **Trust risk if discovered.** If players later realize "half the ladder was bots," it can sour trust.
  Mitigation options range from full opacity, to a light soft-disclosure (ToS / a subtle in-client tell), to
  an internal-only marker.
- **Always keep an internal tell.** Regardless of what players see, keep `is_ultra_bot` visible in
  admin/stats tooling so *you* can always audit the ladder. (This is free once the marker exists.)

---

## Recommended architecture

A **persistent virtual player**, not a headless client:

```
ausers/<botname>.dat  (is_ultra_bot=true, static identity, reserved name)
        │  boot: initialize_players() loads it into `players` like any account
        ▼
Scheduler tick (~60s, wall-clock)  ── in window? ──▶  virtual login:
        │                                               mint ServerSession + peer_map[bot_peer]
        │                                               (reserved bot-session peer-id range)
        │                                               enqueue into ranked/quick
        │  ── out of window? ──▶ dequeue + drop session
        ▼
Normal sweep (_gate_tick / quick pair) treats it as any candidate (get_player resolves)
        ▼
start_ranked_match / start_quick_match  ── now also calls ──▶ _drive_bot_if_acting
        │   (gate generalized: _is_bot_peer(seat) OR session_is_bot(seat))
        ▼
_run_shadow_bot_turn: existing v3 policy  + enhanced energy (75/25 seeded)
                                          + variable think-time (state-derived)
                                          + surrender-if-behind (board-eval → _forfeit-style end)
Outbound: is_bot skips at send_to_peer / _broadcast_turn_result / post-match saves
Excluded from: server_ping_cycle, handle_disconnect, maintenance eject, leaderboard/StatsDB
```

---

## Phased roadmap

Each phase is independently shippable and testable (headless probes like the existing
`match_gate_probe` / `ladder_rating_probe` are the natural verification harness).

**Phase 0 — Decisions & roster design** *(no code)*
Lock the answers to the product decisions: ladder-rating policy for bot games, leaderboard visibility,
surrender aggressiveness, how many bots + the daily schedule grid, name/avatar/cosmetic/preferred-char per
bot, and the invisibility stance. Everything below assumes these.

**Phase 1 — Durable bot identity** *(low risk)*
Add the unforgeable `is_ultra_bot` marker (`save`/`load`, excluded from `absorb_cosmetic_update`). Build an
in-process **bot-account seeder** (model on `_process_register`: `new_gen` → set identity/cosmetics/preferred
team → `resave_player`), with reserved names. Extend `_apply_bot_cosmetics` for the full static look.
*Deliverable:* bot accounts exist, load at boot, render correctly in `display_package`/public profile.
*Verify:* profile-endpoint probe; boot loads N bots.

**Phase 2 — Exclusions & safety** *(low risk, do before anything queues)*
Exclude `is_ultra_bot` accounts from `server_ping_cycle`, `handle_disconnect`/wipe timer, maintenance eject,
`StatsDB`, leaderboard, and friend search. *Deliverable:* a bot account can hold a session without being
disconnected or polluting surfaces. *Verify:* ping-cycle probe leaves the bot session intact.

**Phase 3 — Virtual session + generalized turn-driver** *(highest risk — the core)*
Socket-less session-mint (reserved bot-session peer range). Generalize the drive gate to `session_is_bot`
and call `_drive_bot_if_acting` from `start_ranked_match`/`start_quick_match`. Add `is_bot` outbound skips.
*Deliverable:* manually seat a bot vs a human through the normal path → a full game plays out, no freeze, no
`push_error` storm. *Verify:* a scripted bot-vs-human match probe drives to completion.

**Phase 4 — Self-queuing + bot-vs-bot** *(medium risk)*
Enqueue a bot; confirm the sweep pairs it and reaping doesn't evict it. Make the driver alternate across two
bot sessions for bot-vs-bot. *Deliverable:* a bot in the queue pairs with a human *or* another bot and the
game completes. *Verify:* queue-insertion probe (extends `match_gate_probe`); bot-vs-bot completion probe.

**Phase 5 — Daily rotation scheduler** *(medium risk)*
Stateless wall-clock tick that brings bots online/offline per window and queues them. *Deliverable:* the
right set of bots is online at a given hour and sitting in queue. *Verify:* inject a fake hour → correct
online set.

**Phase 6 — Behavior layers** *(independent, layer in any order)*
- Enhanced energy (75/25 seeded) at `generate_team_energy` + edge cases + timeout-path mirror.
- State-dependent variable think-time.
- Surrender-if-behind (board-eval heuristic + session-less end + anti-death-spiral tuning).
*Verify:* energy-distribution probe (seeded, reproducible); surrender-threshold probe on canned boards.

**Phase 7 — Ladder/record reconciliation & polish** *(depends on Phase 0 decisions)*
Implement the chosen rating/record policy for persistent-bot games (may mean *not* keying suppression on
`bot_player`). Admin controls to force a bot on/offline, and safeguards (cap how much of the live queue can be
bots). *Deliverable:* ladder economics behave as decided.

---

## Bottom line

The proposal is **architecturally sound and largely additive**. It leans on machinery that already exists
(peer-less server-driven bots, socket-decoupled sessions/queues, cosmetics, the v3 policy, seeded energy) and
its genuinely new pieces (virtual session-mint, driver generalization, scheduler, three behavior layers) are
each small and localizable. The dominant risk is the **turn-driver generalization** (Phase 3) — everything
else is low-to-medium risk and independently verifiable. Recommend building Phases 1→4 first to prove a
persistent bot can queue and play a real game end-to-end, then layering personality (5–6) and settling the
ladder-economy questions (7).

## Related
[[The Turn Pipeline]] · [[Server Authority Model]] · [[Bot training v3|bot-training-v3]] · [[Queue reward rules|queue-reward-rules]] · [[Maintenance update flow|maintenance-update-flow]] · [[Season reset|season-reset]]
