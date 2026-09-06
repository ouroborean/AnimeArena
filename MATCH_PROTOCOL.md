# Anime Arena — Match / Client-Server Wire Protocol

> Reconstructed from the live serializers and RPC handlers (`components/server_connection.gd`,
> `new multiplayer/battle_manager.gd`, `components/match_event_recorder.gd`, `components/match.gd`).
> This is the contract a **thin JS web client** must speak to replace the Godot client while keeping
> the Godot headless server authoritative. The original `MATCH_PROTOCOL.md` referenced in code comments
> was never committed; this regenerates it from ground truth.

---

## 0. Architecture in one paragraph
The headless Godot binary is the authoritative server (peer id 1). It runs a **shadow `BattleManager`**
per match (`shadow_mode=true`) that resolves all logic and the 896 abilities. After each validated turn it
broadcasts an **event stream + full snapshot**. The current Godot client is a *passive* renderer: it has no
runtime `_effects`, so it reads server-resolved `cost`/`usable`/`special_targets`/`target_type` **verbatim**
and replays events for animation. **A JS client takes exactly that passive role** — render snapshots, animate
events, present abilities, send turn input. It never simulates and is never trusted (the server re-validates
everything in `Match.validate_input`).

## 1. Transport
| | Current (Godot client) | Target (JS client) |
|---|---|---|
| Socket | `WebSocketMultiplayerPeer` | raw `WebSocketPeer` (server) ↔ browser `WebSocket` |
| Framing | Godot **high-level multiplayer RPC** (proprietary binary; 96 `rpc_id`, 80 `@rpc`) | **JSON text frames** |
| Message id | the RPC method name | `"type"` field = the same method name |
| Args | positional RPC args | named JSON fields (or `"args": [...]` positional) |

**The one server-side job:** replace the RPC layer with a JSON router. Every `rpc_id(peer, "name", a, b)`
becomes `send_json(peer, {"type":"name", ...})`; every `@rpc func name(...)` becomes a `match msg.type`
dispatch. **The payloads below are already plain dicts/arrays of primitives** (the devs already bake
description Callables to text and `_safe_int()` overloaded fields), so they JSON-serialize as-is.

Recommended envelope: `{ "type": "<message>", ...fields }` both directions. Server→peer-1 sends become
`send_json(peer_id, {...})`; client→server sends become one outbound `{type, ...}` frame.

## 2. The canonical character frame (load-bearing)
All character references on the wire use a **canonical index 0–5**:
- `0,1,2` → **p1**'s team slots · `3,4,5` → **p2**'s team slots (`battle_manager.gd:_canonical_index`).
- In `execution_order` only, values **`>= 6`** are ticking-effect counter ids (`legacy_id + 3`), partitioned
  above the 0–5 character space.
- `canonical_role` (`"p1"`/`"p2"` or 0/1) in the match-start message tells the client which side it is.
- `role`/`side`/`acting_role` fields are the strings `"p1"` / `"p2"` (role 0 = p1, 1 = p2).

## 3. Schemas

### 3.1 Snapshot (`serialize_wire_snapshot`)
Shipped with every `apply_turn_result` and as the whole payload of `apply_match_state` (reconnect/spectate).
```jsonc
{
  "match_over": false,
  "current_turn": 7,
  "acting_role": "p1",                 // whose turn the snapshot reflects
  "sides": [ /* side(p1) */, /* side(p2) */ ]
}
```
**side** (`_serialize_wire_side`):
```jsonc
{
  "username": "alice",
  "role": "p1",
  "energy": {
    "pool":          { "0": 2, "1": 0, "2": 1, "3": 3 },   // 0=Green 1=Blue 2=White 3=Red (RANDOM=4 never stored)
    "promised_pool": { "0": 0, "1": 0, "2": 0, "3": 1 }    // reserved by selected-but-unsubmitted actions
  },
  "team": [ /* up to 3 characters */ ]
}
```
**character** (`_serialize_wire_team`):
```jsonc
{
  "path_name": "tanjiro",
  "hp": 80, "max_hp": 100,
  "dead": false, "banished": false, "acted": false,
  "portrait_alt": -1,        // alt-portrait index from PORTRAIT_CHANGE; -1 = base
  "portrait_disguise": "",   // DISGUISE target path_name; "" = none
  "abilities": [ /* the active (post-swap) ability bar, see 3.2 */ ],
  "effects":   [ /* non-system effects, see 3.3 */ ]
}
```
**ability** (server-resolved — client uses verbatim, does NOT recompute):
```jsonc
{
  "ability_name": "Fourth Form: Striking Tide",
  "source_basename": "tanjiro1",     // abilities_data.json key; lets client resolve SKILL_COPY'd slots
  "cooldown_remaining": 0,
  "cost":   { "0":0, "1":1, "2":0, "3":0, "4":1 },   // includes RANDOM(4); COST_MOD/COLOR_CHANGE already applied
  "usable": true,                     // authoritative_usable() — stun/delay/banish/cooldown/affordability resolved
  "special_targets": [3, 4],          // canonical indices this ability may target THIS turn (invuln/isolate/marks resolved)
  "target_type": 0                    // TargetType: 0 SINGLE 1 ALL_FACTION 2 ALL 3 COUNT 4 SELF
}
```
**effect** (`_serialize_wire_effect` — also the EFFECT_ADDED payload; identical shape):
```jsonc
{
  "id": "Demon-Slayer Sword@asta@asta1@11",   // name@userPath@sourceBasename@effectType — stable dedupe key
  "name": "Demon-Slayer Sword", "display_name": "Demon-Slayer Sword",
  "user": 0,                          // canonical idx of the owner (-1 if none)
  "source": "asta1", "source_ability_name": "Demon-Slayer Sword",
  "effect_type": 11,                  // EffectType.Type ordinal
  "duration": -1,                     // -1 = permanent; else turns remaining
  "mag": 5,                           // _safe_int (0 when an ability overloads mag with array/string state)
  "stack_count": 1,
  "display_mag": true, "display_stacks": false,
  "unique_render_id": 0,
  "description": "Asta will give 10 Nullify to enemies he damages.",   // Callable baked to text server-side
  "is_physical": false, "system": false, "invisible": false,
  "visibility": "all",                // "all" | "enemy_hidden" (hide from foe) | "user_only"
  "icon_path": "res://assets/images/..."   // map to a web asset URL (see §6)
}
```
> System effects (`system:true`, e.g. PORTRAIT_CHANGE/DISGUISE) are filtered OUT of `effects[]`; their result
> is surfaced via `portrait_alt`/`portrait_disguise`. Honor `visibility` so hidden enemy effects aren't leaked.

### 3.2 Turn input (`build_turn_input`) — client → server
The client builds this from the user's selections, then sends via `submit_turn_input`.
```jsonc
{
  "match_id": 0,                       // TODO: not yet threaded end-to-end (server resolves match via session)
  "turn_number": 7,
  "actions": [
    { "char_idx": 0, "ability_idx": 2, "target_idxs": [3] }   // ability_idx = index into that char's active ability bar
  ],
  "execution_order": [0, 2, 6],        // player-chosen resolution order; 0–5 char steps, >=6 ticking ids
  "energy_allocation": [ /* random_history: which colors paid each RANDOM pip */ ],
  "exchange": { "offer": { "1": 2 }, "request": 3 } | null,   // optional energy exchange (trade colors → 1 chosen)
  "timeout": false
}
```

### 3.3 Events (`MatchEventRecorder`) — server → client, the `events` array of `apply_turn_result`
Ordered list the client replays for animation/sequencing. The trailing snapshot is the authoritative state to
reconcile to afterward. All `*_idx`/`target`/`char_idx`/`from` are canonical 0–5 (`from` may be `null`).

| `type` | Fields |
|---|---|
| `TURN_STARTED` | `turn_number`, `acting_role` |
| `TURN_ENDED` | `turn_number` |
| `ENERGY_GAINED` | `side`, `energy_list`: `[int,…]` (color enums generated) |
| `ENERGY_SPENT` | `side`, `spent`: `{color:int}` |
| `ENERGY_EXCHANGED` | `side`, `offer`: `{color:int}`, `request`: `int` |
| `ABILITY_USED` | `char_idx`, `ability_idx`, `targets`: `[idx,…]` |
| `DAMAGE` | `target`, `amount`, `damage_class`: `Physical\|Energy\|Mental\|Affliction`, `source`: name, `from` |
| `HEALING` | `target`, `amount`, `source`: name, `from` |
| `EFFECT_ADDED` | `target`, `effect`: `{…effect payload §3.1…}` |
| `EFFECT_REMOVED` | `target`, `effect_id`: the `id` string |
| `COOLDOWN_SET` | `char_idx`, `ability_idx`, `value` |
| `DIED` | `char_idx` |
| `BANISHED` | `char_idx` |
| `MATCH_ENDED` | `winner_role`: `"p1"\|"p2"` |
| `MESSAGE` | `text`, `demand`: bool (toast vs modal) |

## 4. Message catalog (by phase)
Direction key: **C→S** = client sends (server handler takes a leading `peer_id`); **S→C** = server sends.

### 4.1 Auth & session
| Msg | Dir | Fields |
|---|---|---|
| `receive_login_attempt` | C→S | `username`, `password` (⚠ plaintext today) |
| `receive_login_response` | S→C | `json_string` — full **player blob** (AP, unlocks, rank, mastery, clan, bounties…) |
| `receive_register_attempt` / `receive_register_response` | C→S / S→C | `username,password` / `message` |
| `receive_player_update` | S→C | `player_string` (refreshed player blob) |
| `receive_back_to_login_command` | S→C | — (force to login) |
| `receive_heartbeat` (C→S, 10 s) / `receive_heartbeat_response` (S→C) | — | liveness |
| `receive_server_ping` (S→C, 15 s) / `receive_server_pong` (C→S) | — | server-driven liveness (covers frozen tabs) |
| `request_session_validation` / `receive_session_validated` | C→S / S→C | tab-away reconnect without re-login |
| `receive_update_notification` | S→C | `version_list`, `reroute` |

### 4.2 Matchmaking & draft
| Msg | Dir | Fields |
|---|---|---|
| `receive_quick_match_queue` / `receive_ranked_match_queue` | C→S | `player`, `character_names` |
| `receive_private_match_queue` | C→S | `player`, `character_names`, `target_username` |
| `cancel_queue` | C→S | — |
| `receive_queue_rejected` | S→C | — |
| `receive_quick_match` / `receive_ranked_match` / `receive_private_match` | S→C | **`opponent`, `opponent_team`, `first_turn`, `seed`, `canonical_role`** ← match start |
| `receive_hero_ban_communication` / `receive_hero_pick_communication` | both | `character` (relayed draft picks; UI exists, not wired into live flow) |

### 4.3 The match loop (the MVP core)
| Msg | Dir | Fields |
|---|---|---|
| `submit_turn_input` | C→S | `_match_id`, `input` (§3.2). Server validates via `Match.validate_input`, runs the shadow. |
| `submit_energy_exchange` | C→S | `offer_dict`, `request_type` |
| `apply_turn_result` | S→C | **`events` (§3.3), `snapshot` (§3.1)** ← broadcast after every processed turn |
| `apply_match_state` | S→C | `snapshot` only — full resync (reconnect / spectate init) |
| `send_surrender` / `receive_surrender` | C→S / S→C | — |
| `receive_match_reconnect_request` / `receive_reconnection_response` | C→S / S→C | `json_package` (resume mid-match) |
| `receive_opponent_disconnect_notification` / `_reconnect_notification` | S→C | opponent grace state |

### 4.4 Secondary (incremental — stub for MVP)
Spectate (`submit_spectate_request`, `receive_spectate_init/denied` — server-complete, no live client entry),
replays (`submit_replay_request`, `receive_replay_data`), leaderboard/ladder/mastery
(`receive_leaderboard_*`, `request_ladder_details`, `request_character_mastery_ladder`), character buckets
(`receive_character_bucket_request`, `receive_player_contribution`), and the full **clan** suite
(`receive_clan_*`, `receive_player_*` — ~20 messages). None are needed to play a match.

## 5. Flows

**Login →** connect WS → `receive_login_attempt` → `receive_login_response{json_string}` (render menus from the
blob) → start 10 s heartbeat, answer `receive_server_ping` with pong.

**Match →** `receive_*_match_queue` → (wait) → `receive_quick_match{opponent,opponent_team,first_turn,seed,canonical_role}`
→ build battle UI from the team lists; if `first_turn`, you act first. Each turn: collect actions + chosen
`execution_order` + RANDOM `energy_allocation` → `submit_turn_input` → server validates+resolves →
`apply_turn_result{events,snapshot}` to **both** clients → animate events, reconcile to snapshot. Repeat until a
`MATCH_ENDED` event / `match_over:true`.

**Reconnect →** on resume (`visibilitychange`/`online`) reconnect WS, `request_session_validation` or
`receive_match_reconnect_request` → `apply_match_state{snapshot}` rebuilds the board from scratch. (Server holds a
120 s grace before auto-surrender — much friendlier than Godot's tab-suspend behavior.)

## 6. Assets & enums the client needs
- **Images** are `res://assets/images/<Character>/...png`. Ship `assets/images/` to the web host and map
  `icon_path` / portraits / `path_name` → URLs (e.g. `path_name` "tanjiro" → `/assets/images/Tanjiro/...`).
- **Energy** 0 Green · 1 Blue · 2 White · 3 Red · 4 Random(cost-only). **Role** p1=0, p2=1.
- **TargetType** 0 SINGLE · 1 ALL_FACTION · 2 ALL · 3 COUNT · 4 SELF.
- **EffectType** ordinals (0–121) and **DamageType** (0–6) per `CODEBASE_CHEATSHEET.md §5`; the client mostly
  just keys icons/labels off `effect_type` + `description` (all display data is pre-resolved server-side).

## 7. Security & trust
The server re-validates every input (`Match.validate_input`: acting player, indices in range, not
dead/cooldown/stunned, targets legal, total cost affordable incl. RANDOM substitution). **The JS client is
untrusted** — it computes targeting/order only for UX; never grant it authority. Keep plaintext-password login
in mind (out of scope here, but a good time to add hashing/TLS at the gateway).

## 8. Known protocol TODOs (in current code)
- `match_id` is **not threaded** end-to-end (`build_turn_input` ships `0`; server resolves via
  `session.current_match`). Phase 7.3 intends real ids to reject stale inputs.
- Desync hashing (`report_state_hash` / `_advance_shadow`) is dormant (`_advance_shadow` has zero callers).
- Draft ban/pick messages exist but no live flow drives them.

## 9. What the JS client must implement (MVP)
1. **WS + JSON router** + reconnect (`visibilitychange`/`online`).
2. **Auth**: login → render menus from the player blob (or a thin menu for MVP).
3. **Queue → match start** (the 5-field match message).
4. **Battle view**: render the snapshot (HP/energy/effects/ability bar); the ability bar reads
   `usable`/`cost`/`special_targets`/`target_type` verbatim; tap-ability → highlight `special_targets` → tap-target;
   collect `execution_order` + RANDOM `energy_allocation`; `submit_turn_input`.
5. **Event replay** (optional polish): animate the `events[]`; snapshot-only re-render is a valid first cut.
6. Stub everything in §4.4.
