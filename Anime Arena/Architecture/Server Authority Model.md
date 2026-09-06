---
tags: [area/architecture, type/reference]
---

# Server Authority Model

The browser never simulates. It renders a snapshot, animates an event list, and submits an intent.
Every state change originates in the server's **shadow `BattleManager`** and comes back down the
wire. This note covers how that is enforced, the peer-id namespaces that route it, and — importantly
— the list of things the client genuinely *is* trusted for, because that list is longer than the
architecture diagram suggests.

## The shadow simulation

`Match.begin_match()` (`components/match.gd:195`) builds one `BattleManager` per live game with
`shadow_mode = true`, parents it under the `Match`, and attaches a `MatchEventRecorder` **before**
`start_battle` so the opening turn's `TURN_STARTED` and first-turn `ENERGY_GAINED` land in the very
first flush.

Clients run the same class with `passive = true`. `start_battle` sets it:

```gdscript
passive = not shadow_mode and m_type != MatchType.BOT   # battle_manager.gd:293
```

A passive manager has **no runtime `_effects`** — only `_display_effects` rebuilt from wire
snapshots. That single fact explains most of the passive-mode special cases scattered through
`battle_manager.gd`:

| Passive path | Why |
|---|---|
| `roll()` returns `0` (`:1884`) | client-side RNG would desync everything |
| `start_round_loop()` emits and returns (`:940`) | execution is server-side; the client waits for `apply_turn_result` |
| `start_new_turn` skips triggers + energy gen (`:538`) | a local gen would poison the pool with phantom GREEN |
| `startup_passives` skipped (`:339`) | the server ships the matching `EFFECT_ADDED` events; running both duplicates every passive tooltip |
| `receive_ability_use_request` uses `ability.server_targets` (`:651`) | the client cannot evaluate invuln/isolate/marks — it reads the server's `special_targets` verbatim |
| `get_passive_ticking_display_info()` (`:850`) | the reorder preview must be built from display effects |

> [!info] The web client is even thinner than "passive"
> The retired Godot client instantiated a real `BattleManager` in passive mode. The JS client does
> not exist in GDScript at all — it consumes the same wire format directly. So passive-mode code in
> `battle_manager.gd` is now dead weight for live play, kept because the shape of the wire contract
> is defined by it.

## Peer id namespaces — get this wrong and a broadcast silently targets nobody

There are **three** id spaces in flight:

| Space | Range | Produced by | Keyed by |
|---|---|---|---|
| **Raw gateway id** | `1, 2, 3, …` | `JsonGateway._next_id` | `json_gateway._peers` |
| **Logical peer id** | `JSON_PEER_BASE + gateway_id` (≥ `1_000_000_000`) | `_on_json_message` | `sessions[*].peer_id`, `peer_map` |
| **Bot seat id** | `≤ BOT_PEER_BASE` (`-1000`, counting down) | `_bot_peer_counter` | `Match.players` |

```gdscript
const JSON_PEER_BASE := 1000000000   # server_connection.gd:109
const BOT_PEER_BASE  := -1000        # server_connection.gd:147

func _is_json_peer(peer_id: int) -> bool: return peer_id >= JSON_PEER_BASE   # :709
func _json_local(peer_id: int)    -> int: return peer_id - JSON_PEER_BASE    # :712
```

Inbound, `_on_json_message(json_pid, msg)` lifts immediately:
`var logical_peer: int = JSON_PEER_BASE + json_pid` (`:731`). Every handler below it works in the
logical space. Outbound, `send_to_peer(peer_id, method, payload)` (`:718`) converts back with
`_json_local` before handing the frame to the gateway.

The bot range is negative specifically so a synthetic bot seat can never collide with a real peer
(positive) or a web peer (1e9+). `_is_bot_peer()` is just a range test.

> [!danger] This really happened
> `_admin_peer_ids()` (`server_connection.gd:370`) collects the peers the maintenance eject must
> **skip**, so an admin isn't thrown to the login screen and stranded without the Cancel button.
> `sessions[*].peer_id` is a **logical** id; `JsonGateway.broadcast_except(exclude, …)` iterates
> `_peers`, which is keyed by **raw gateway id**. Passing the logical id matched nothing, the
> exclusion list was effectively empty, and the eject quietly threw the admin out along with
> everyone else. The fix is the `_json_local(sess.peer_id)` in that function:
> ```gdscript
> for uname in sessions:
>     if not _is_admin(uname): continue
>     var sess = sessions[uname]
>     if _is_json_peer(sess.peer_id):
>         out.append(_json_local(sess.peer_id))   # RAW id — broadcast_except keys on raw
> ```
> Rule of thumb: **anything that touches `json_gateway` directly wants a raw id; everything else
> wants a logical id.** `send_to_peer` is the only sanctioned converter — prefer it over calling
> `json_gateway.send` by hand. See [[Season Reset and Maintenance]].

## The validation gate

Client → server turn submission is one frame, `submit_turn_input`, and it passes through exactly two
functions before touching the simulation.

**`Match.validate_input(input, peer_id, exchange_unapplied)`** (`components/match.gd:478`) rejects on:

- `manager == null`, input not a Dictionary, missing `actions` / `execution_order` / `energy_allocation`
- `peer_id != acting_player` — the turn-order gate
- sender not in the match (`_peer_canonical_role` returns -1)
- any `char_idx` outside the sender's own canonical band (`team_base = sender_role * 3`, so p1 may
  only act with 0–2 and p2 only with 3–5)
- the acting character being dead or banished
- `ability_idx` out of range of that character's *active* (post-swap) bar
- `ability.cooldown_remaining > 0`
- `character.is_stunned(ability)`
- a target index outside `0 … all_characters().size()`
- total cost not affordable from the sender team's pool

> [!warning] Trap: affordability has to be checked against the POST-exchange pool
> Web clients bundle a pending energy exchange inside the input and never apply it up front, so at
> validation time the pool is still pre-exchange. Passing `exchange_unapplied = true` (which
> `_process_turn_input` does for the web path, `server_connection.gd:3891`) makes validation use
> `can_afford_after_exchange`. Without it, a legitimate "trade colours to fund this turn" play is
> rejected. Plain `can_afford` also handles RANDOM-cost substitution — a raw pool comparison rejected
> every first-turn RANDOM-cost action.

`validate_input` calls `manager.prepare_acting_energy_if_needed()` (`battle_manager.gd:1489`) first,
because when p2 is acting nothing has generated their energy yet and every action would look
unaffordable against an empty pool. That function latches (`acting_energy_prepared`) so
`process_turn_package` knows to skip its own generation step and the same energy isn't rolled twice.

**`Match.apply_input(input, peer_id)`** (`:573`) then translates the canonical wire frame into the
legacy local frame (`_canonical_input_to_legacy_package`, `:603`), clears the sender's AFK miss
streak, flips `acting_player` to the opponent, and feeds `manager.receive_turn_package(package)`.

Afterwards `_broadcast_turn_result(nmatch)` (`server_connection.gd:3578`) drains the event recorder,
takes a `serialize_wire_snapshot()`, stamps the next player's (possibly AFK-penalized) turn duration
onto it, and sends `apply_turn_result {events, snapshot}` to both seats. Spectators get a
hidden-info-stripped copy built once per broadcast; the replay log keeps the full one.

> [!tip] A rejected turn used to lock the client
> The server drops an invalid input silently. The gateway path now replies
> `{"type":"error","reason":"Turn rejected — …"}` (`server_connection.gd:805`) and the client also
> arms a watchdog (`armTurnWatchdog`, `app.js:1501`) so `S.acting` can't stay `true` forever.

## Canonical coordinates

Everything on the wire uses a **canonical index 0–5**: 0–2 are p1's slots, 3–5 are p2's.
`_canonical_index` (`battle_manager.gd:2160`) swaps the halves when the local user is p2, so all
three parties name the same chair with the same number.

In `execution_order` only, values `>= 6` are ticking-effect ids (`legacy_counter + 3`), partitioned
above the character space so the two kinds of step can share one list. `apply_input` reverses both
transforms.

## What the client is NOT trusted for

- **Battle resolution.** Damage, effects, cooldowns, deaths — all server-side.
- **Targeting legality.** `special_targets` is computed server-side per ability per snapshot.
- **Ability usability.** `usable` is `authoritative_usable()`, already accounting for stun, delay,
  banish, cooldown and affordability.
- **W/L, rating, streak.** Written only in `handle_server_match_ended`; explicitly *not* absorbed
  from a cosmetic update (see the comment at `scripts/player_component.gd:207`).
- **`campaign_state`.** Server-authoritative intents + echo; excluded from `absorb_cosmetic_update`
  while still round-tripping via `save`/`make_cosmetic_update`. See [[Campaign Mode]].
- **`muted`.** A server-only moderation field, deliberately not absorbed so a modified client can't
  unmute itself.
- **`donate` and `complete_bounty`.** Both debit and validate server-side, then echo
  `receive_player_update` so the browser's AP is refreshed from the authoritative value.
- **Campaign encounter teams.** `start_campaign_battle` derives both teams server-side; a client can
  no longer fabricate a trivial fight to bank a win.
- **Mastery XP rewards.** Granted in the server's `complete_bounty` handler because `save_cosmetics`
  deliberately omits `mastery_xp`.

## What the client IS trusted for

This is the part that surprises people.

> [!warning] `save_cosmetics` writes AP and unlocks straight from the client
> `absorb_cosmetic_update` (`scripts/player_component.gd:185`) does a bare assignment:
> ```gdscript
> unlocks = data['unlocks']
> ap      = data['ap']
> ```
> There is no server constant and no validation on this path. Consequences:
> - **Bounty square auto-complete is client-authoritative.** The AP debit for buying a square rides
>   `save_cosmetics`, so a modified client can fill squares for free. (`donate` and
>   `complete_bounty` are validated; the square buy is not.) The price was raised 1000 → 1500 purely
>   client-side.
> - Shop purchases and any other AP spend that rides the same frame have the same posture.
>
> This is a known, accepted posture — not an oversight to fix in passing. See
> [[Traps That Have Bitten Us]].

Other client-authoritative surfaces:

- **Cosmetic equipment** — frames, hats, player card, backgrounds, title, equipped team,
  `bot_turn_delay` / `bot_queue_delay` / `ranked_allow_bots` settings.
- **Turn *ordering*.** `execution_order` is player-authored and the server honours it (after
  sanitizing unknown keys). See [[The Turn Pipeline]].
- **Target ordering — and therefore the primary target.** The server walks `target_idxs` in the
  order sent and `targeter_component.add_target` makes the **first** one `main_target`; nothing
  downstream re-derives it. ~21 abilities split primary vs splash off `main_target`. See
  [[Targeting and Main Target]].
- **The Nexus raffle wheel** — an admin tool that reads live bucket AP and never writes.

The unifying principle: **anything that can be re-earned or re-equipped is client-writable; anything
that represents a competitive record or a progression gate is not.**

## Adding a server-only, unforgeable field

The recipe (from the Profile feature):

1. Round-trip the field in `Player.save()` + `load_player()` with a type-guarded default.
2. Do **not** add it to `absorb_cosmetic_update` (that is the client-writable path). It may still
   appear in `make_cosmetic_update` — that direction is server → client.
3. Write it server-side, ideally just before an existing `resave_player(...)` so it persists with no
   extra write.

Same shape as `wins`/`losses`/`friends`/`ignored`/`muted`. A field absent from
`absorb_cosmetic_update` structurally cannot be forged.

## Serving public data safely

To expose a player-by-username lookup:

- Add a case in the `_on_json_message` match block, **before** the `_:` default.
- Gate on logged-in only (`get_player(logical_peer) != null`) — no `_is_admin` for public data.
- Resolve the target with `_admin_get_target(username)` (`server_connection.gd:425`). Despite the
  name it performs no admin check; it does reject `/`, `\` and `..` so the username can't traverse
  out of `ausers/`.
- Build the reply **field-by-field off a whitelist**. Never return `load_player()`'s raw dict — it
  carries the plaintext `pass_hash`. Sanitization *is* the whitelist, not the resolver.

## The legacy holes, and why they're closed now

An adversarial audit (2026-07-20) found unauthenticated account-overwrite and cross-account-delete
paths in `@rpc("any_peer")` handlers. Every remote one was reachable only via the legacy Godot RPC
listener on port 5696. That listener and its handlers were **removed** — `actually_start_server()`
now says so explicitly (`server_connection.gd:692`) and `send_to_peer` `push_error`s on any
non-JSON peer. `update_player_avatar_data`, the worst of them, no longer exists.

What survives from that audit and is still true:

- **Saves are non-atomic.** `save_player` truncates then writes; a crash between the two empties the
  account. There is no temp-file+rename anywhere.
- **`resave_player` fails OPEN.** It re-reads the `.dat` to recover `pass_hash`; if that read returns
  null at that instant, `pass_hash` becomes `""` and it writes a full but *passwordless* account,
  which the login path's legacy-migration branch lets anyone claim.

Related: [[Admin and Live Ops]], [[Hard Rules and Guardrails]], [[System Overview]].
