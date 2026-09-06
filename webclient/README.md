# webclient/ — thin JS client + JSON gateway (Scope A)

Goal: replace the Godot client with a lightweight **JS web client** that talks to the **existing Godot
headless server** over plain JSON-over-WebSocket, while the server keeps running all game logic and the
896 abilities. See `../MATCH_PROTOCOL.md` for the wire contract.

## Pieces
| File | Role |
|---|---|
| `json_gateway.gd` | Reusable raw-WebSocket + JSON transport node (no game logic). Accept/poll/parse/send. |
| `gateway_runner.gd` | Standalone headless harness hosting the gateway with `ping`/`login` **stubs**. |
| `test_client.html` | Minimal browser client to exercise the transport. |

## Run the transport spike
```sh
# 1. Start the gateway (does NOT touch the real game/server):
godot --headless --path . --script res://webclient/gateway_runner.gd
#    -> "[JsonGateway] listening on ws://*:5696"

# 2. Open webclient/test_client.html in a browser, Connect to ws://localhost:5696,
#    then "Send ping" (expect a pong) and "Send login" (expect a stub login_response).
```
The gateway listens on **5696**, parallel to the legacy high-level-multiplayer server on **5695**, so the
existing Godot client is unaffected.

## Status / next steps
- [x] Transport: raw-WS JSON gateway (`json_gateway.gd`) + headless runner + browser test client.
- [x] **Outbound bridge:** `ServerConnection.send_to_peer(peer_id, method, payload)` routes a message to a
      Godot peer (`rpc_id`) or a web peer (gateway JSON). Web peers use logical ids `JSON_PEER_BASE + id`
      so sessions/`peer_map` work unchanged. Extend `_rpc_to_godot` per bridged method.
- [x] **Real login:** `_on_json_message` → `_process_login` (shared with the RPC path) → `send_to_peer`.
      Validated end-to-end against the live server (handshake → ping/pong → `receive_login_response`).
- [x] **Matchmaking + match start:** `_on_json_message` handles `queue_quick`/`queue_ranked`/`queue_private`/
      `cancel_queue` (via `_json_enqueue`, deriving the display package server-side); the three `start_*_match`
      sends + `receive_queue_rejected` + `_broadcast_turn_result` route through `send_to_peer`. Plus two
      blockers fixed: `_on_json_disconnected` now delegates to `handle_disconnect` (queue cleanup), and
      `server_ping_cycle` skips web peers (it would force-disconnect them every cycle). Validated end-to-end:
      two web clients pair into a quick match with correct `canonical_role`/`first_turn`/`seed`, receive the
      start message **before** the initial `apply_turn_result` (14 events, turn-1 snapshot); short-payload
      reject and cancel also confirmed.
      *Known gaps:* ranked has a pre-existing enqueue-vs-search rank/tier bucket mismatch (not web-specific);
      `handle_disconnect`'s opponent-disconnect notify is still `rpc_id` (bridges with the battle loop).
- [x] **Battle loop:** `_on_json_message` handles `submit_turn_input`; `_process_turn_input(sender_id,…)` is
      shared by the RPC + web paths → `Match.validate_input` → `apply_input` → shadow `BattleManager` →
      `_broadcast_turn_result` (already bridged) fans the `{events,snapshot}` to both peers. `handle_timeout`'s
      `apply_turn_result` is now bridged too. **Footgun fixed:** Godot's `JSON.parse_string` returns numbers as
      *floats*, so `match.gd:_canonical_input_to_legacy_package` gated `execution_order` on `typeof==TYPE_INT`
      which failed for web input — now coerces int|float. Validated end-to-end: a web client submits a real
      ability, both peers receive the resulting turn and the turn advances/alternates.
      *Follow-ups:* `submit_energy_exchange` + `send_surrender` (same sender-id refactor); RANDOM-cost
      `energy_allocation` float-handling when the client UI allocates random pips.
- [~] **JS client UI (v1)** in `webclient/app/` — `index.html` + `style.css` + `net.js` (WS/JSON transport)
      + `app.js` (state + login/menu/battle screens). Vanilla JS, classic scripts, mobile-first, no build step.
      Login → quick-match queue → the **battle board from the snapshot** (HP bars by %, dead-greyout, effect
      badges, energy pips, ability bars). `window.AA` is a dev console handle.
      Test: `python -m http.server --directory webclient/app 8777`, open `localhost:8777` with the Godot
      server running (`godot --headless --path .`).
  - [x] **Char-select screen:** a searchable 158-character grid (filter by name/universe), tap to pick up
        to 3 (slots show the team; tap a slot to remove), Quick Match enables only at 3. Roster served as
        `webclient/app/roster.json` (generated from `analysis/roster_profiles.json`, the 14 non-functional
        kits excluded). Validated live: picked team (Naruto/Sasuke/Itachi) flows through queue into the
        actual match. *Follow-up:* gate by the player's `unlocks`; character portraits on the cards.
  - [x] **Turn interaction:** tap a usable ability → (single-target) highlight valid `special_targets` → tap
        to stage; SELF/AoE auto-stage; multiple actions queue (one/char); **End Turn** sends `submit_turn_input`
        and the board re-renders from the returned snapshot. RANDOM-cost abilities are guarded pending an
        allocation UI. **Validated live in a real browser**: connect → login → queue → pair → play multiple
        alternating turns vs an auto-opponent against the actual Godot server.
  - [x] **Energy allocation:** the client tracks remaining energy as actions stage, refuses unaffordable
        ones, and on End Turn builds `energy_allocation` = `[[color,count],…]` covering the FULL spend
        (specific costs + RANDOM pips auto-paid from remaining colors). This unblocks RANDOM-cost abilities
        AND fixes energy actually being deducted (the old `energy_allocation:[]` under-drained). Server fix:
        `energypool.receive_generic_allocation_offer` now `int()`s the count (web sends JSON floats).
        Validated live: a RANDOM-cost ability auto-allocates a color, the server's `ENERGY_SPENT` event
        matches the client allocation exactly, and the pool decreases correctly across turns.
        *Next:* manual allocation control (currently greedy auto-pick).
  - [x] **Win/loss screen:** `apply_turn_result` detects `MATCH_ENDED` (or `snapshot.match_over`) and shows
        a Victory/Defeat banner (by comparing `winner_role` to my canonical role), makes the board read-only,
        and offers **Return to Menu** (resets to char-select).
  - [x] **Character portraits:** resolved through `portraits.json` — a manifest parsed from the character
        `.tscn` files, because folder + filename are NOT derivable from `path_name` (display-name folders like
        `Kamado Tanjiro`; ~15% of defaults aren't `<pn>prof.png` e.g. `aangnewprof.png`/`usoppprof.PNG`; and
        `portrait_alt` indexes a per-character array of arbitrarily-named files). The client mirrors Godot
        `active_portrait()`: dead→`dead.png`, banished→`banished.png`, `portrait_disguise`→the other char's
        default, `portrait_alt`→`alts[i]`, else default; `<img onerror>` falls back to text. Shown on the
        char-select grid + battle cards. Regenerate: parse `character/*.tscn` (`portrait_texture` +
        `alt_portraits` ExtResource paths) → `webclient/app/portraits.json`. Also fixed a latent roster bug:
        `uryu`→`uryuu` (the only roster `path_name` with no matching `.tscn` — would have failed to load).
  - [x] **Reconnect (mobile):** the server already holds a dropped player's match for **120s**
        (`RECONNECT_TIMEOUT`) in a DISCONNECTED session — the gap was that the resume handshake was Godot-RPC
        only. **Server:** `_process_login` **Case A** now re-links the live match (`check_in_player` +
        `get_reconnection_info`) and ships the snapshot package via `send_to_peer`
        (`receive_session_reconnect`), plus two `_rpc_to_godot` entries so the legacy Godot client is
        unaffected. **Client:** keeps credentials in memory, detects drops (`ws.onclose` + `visibilitychange`
        + `online`), auto-reconnects with backoff (capped under 120s) and silently re-logs-in;
        `receive_session_reconnect` rebuilds the board from the snapshot (or falls back to menu if the match
        ended while away). A "Reconnecting…" overlay covers the gap. Validated live: socket-close mid-match →
        reconnect+resume in <1s → played a move the server **accepted** (turn advanced), proving the resumed
        session is fully authoritative.
        *Follow-ups:* bridge opponent disconnect/reconnect/surrender notifications to web peers (UX polish);
        Case-B stale-JSON-peer eviction if a fast reconnect ever races the gateway reap; a session token
        instead of re-sending the password (no token auth exists today).
  - [x] **Turn animations:** the `apply_turn_result` event list drives visual feedback over the snapshot —
        floating damage/heal numbers (colored by `damage_class`: physical/energy/mental/affliction/heal), HP
        bars that **glide** (rendered at their previous width, then a forced-reflow + CSS width-transition to
        the new value — more reliable than rAF, which throttles on inactive tabs), and cast/hit/death flashes,
        lightly staggered (80ms/event) so a multi-action turn reads as a sequence. Pure CSS + a tiny per-event
        scheduler; the snapshot stays the source of truth (animations are an overlay, never gate state).
        Validated live: a real `Shuriken Jutsu` `DAMAGE` event spawned a red "-10" over the target.
  - [x] **Ability + effect icons:** ability buttons show the ability art — `ability_icons.json` maps the wire
        `source_basename` → `Folder/file.png` (generated from `abilities_data.json` `image_path`, 912 abilities)
        and the client builds the URL with the same `relToUrl` as portraits. Effect badges show the effect's
        icon: the wire effect already carries `icon_path` (a `res://` path baked server-side from its tooltip,
        which `set_source` defaults to the source ability's image), resolved by a generic `res://`→URL helper
        (`resToUrl`, = `assetBase()` minus `/assets/images`). Both fall back to the text label via `<img
        onerror>`. Validated live: 12/12 ability icons + the real passive effect icons loaded.
  - [x] **Manual energy allocation:** the energy logic is now turn-level — staged actions carry their ability
        `cost`; the turn's RANDOM pips pool into `randomAssign` (auto-filled greedily, then adjustable). The
        energy panel shows the remaining pool plus, when RANDOM pips exist, a per-color +/- editor so the player
        can steer which colors a RANDOM pip spends (e.g. to preserve a scarce color). End Turn is gated until
        every RANDOM pip is placed; the submitted `energy_allocation` reflects the manual choice exactly.
        Validated: auto-assign `{0:2}` → moved a pip to Blue → submitted `[[0,1],[1,1]]`; an unplaced pip blocks
        End Turn. (The server draining `energy_allocation` exactly was validated live in the energy commit.)
  - [x] **Surrender + opponent notifications:** an inbound `surrender` routes to the existing
        `process_surrender` (the match-end broadcast already drives win/loss); the battle screen has a
        two-tap-confirm **Surrender** link. `handle_disconnect`'s opponent disconnect/reconnect notifies now go
        through `send_to_peer` so a web opponent sees "Opponent disconnected — waiting…". **Also fixed a real
        latent bug:** `handle_server_match_ended` sent `send_player_update`/`receive_surrender` via `rpc_id`,
        which errors for web peers and broke the `MATCH_ENDED` broadcast — so *no* web match-end (surrender OR a
        normal KO) reached the client. Both bridged; a `receive_player_update` handler refreshes rank/AP/unlocks.
  - [x] **Unlock-gating:** char-select now greys + locks characters the player can't use. `roster.json` carries
        a `gate` field (`"always"` for the 33 starter-squad chars, else `"<path_name>_unlock"`), and the client
        mirrors `character_component.unlocked(player)`: available if `gate=="always"` or the player's `unlocks`
        contains the token or `"all_unlock"`. Locked cards are greyed with a 🔒 and can't be picked. Validated
        with a limited-unlocks player: starters + the owned token are selectable, 124 others lock.
  - [x] **Energy exchange (2-for-1):** the energy panel offers a trade — give 2 of one color, get 1 of any
        chosen color — shown when some color has ≥2 (a port of `can_exchange`). It rides inside
        `submit_turn_input` as `input.exchange = {offer:{color:2}, request:color}` (match.gd:325 already parses +
        int-coerces it — **no server change**, unlike surrender), and folds into `myPool()` immediately so the
        trade reflects at once and can fund a same-turn ability (the server applies exchange before abilities).
        Enforced client-side (2-for-1, single give color, precondition) since the turn-input path has no
        server-side validation. Validated live: gave 2 White → got 1 Green; the server echoed an
        `ENERGY_EXCHANGED {offer:{2:2},request:0}` event and accepted the turn.
  - [x] **Desktop battle layout (matches the game):** the battle screen is now a 3-zone grid mirroring the
        Godot scene — **top bar** (player card | center cluster | enemy card), **arena** (my team column on the
        left, enemy column on the right, status in the middle), **bottom bar** (Surrender + log on the left, a
        **description panel** on the right). Player/enemy cards render name / title / clan / rank+tier
        ("Bronze 1", from `RANKS[rank] + tier`) / wins-losses, sourced from `S.player` and `S.match.opponent`
        (the display blobs — not the snapshot). The center cluster holds End Turn, a cosmetic 120s turn timer,
        and the energy pool (now 5 trackers: G/B/W/R + total). Character strips are horizontal (portrait+HP |
        effects+ability row); the enemy column mirrors. **Only your characters show skill tiles** (for
        staging) — the enemy side is empty (like the game). **Description panel (two modes):** clicking a
        character's portrait (when not targeting) opens *character mode* — their portrait + a horizontal,
        scrollable strip of their skills (this is how you inspect the enemy's hidden skills); clicking any skill
        (a strip tile or one of your board tiles) opens *ability mode* — the skill's **image** + name +
        description + classes + cooldown. Your usable board tiles still stage/target; during targeting a
        portrait-click picks the target instead of inspecting. Data from `ability_info.json`
        (`{source_basename:{name,description,classes,cooldown,desc}}`). Collapses to the single-column mobile
        layout under 760px via a media query (shared markup). Validated live: cards, columns, energy, and the
        description panel all populate from real data.
        Descriptions come from `split_desc()` — the source of truth (`describe()` is stale). `split_desc()` is
        parameterless, so `extract_split_desc.gd` (run headless) builds each ability via
        `Ability.from_database()`, calls `split_desc()`, and dumps the `[{text, color?}]` segments into
        `ability_info.json` under `desc` (869 abilities; colors from the game, e.g. dim-gray passive notes). The
        panel renders the colored segment list (headline + sub-effects), falling back to the `abilities_data`
        text otherwise — **961/965 abilities now have a real description** (~4 broken/source-missing kits don't).
        *Remaining gap:* the timer is client-local/cosmetic (the snapshot carries no time; an accurate countdown
        would need a `time_left` field added to the wire snapshot).
  - [x] **No RANDOM auto-allocation:** staging a RANDOM-cost ability no longer pre-assigns the pips — the
        allocation editor opens empty and the player places each one (End Turn gated until all placed).
  - [x] **Character-select layout (matches the game):** a wide screen in three bands — **8 menu buttons** fixed
        at the top (Titles, Bounties, Cosmetics, Shop, Nexus, Mastery, Settings, Ladder — **stubs** pending
        textures/menus); an **open middle area** for panels; and a **bottom band capped at 33vh** holding the
        queue-button row (Quick Match wired; Private Match stub) above `[filter panel | character grid | player
        panel]`. **Filter panel:** Randomize Team (3 unlocked) + a **Color Filter** (G/B/W/R, from `roster.json`
        `colors`). **Grid:** small square portraits (lock badge + selected ring), an **Anime** dropdown (by
        `universe`), a Category stub, and a search box. **Player panel:** avatar, username, title, `Clan:`,
        `Rating:`, `Ratio: W - L (±streak)`, `AP`, selected team (3 slots).
  - [x] **Character info panel (middle area):** selecting a grid character also opens an info panel — the
        character's portrait + a horizontal, scrollable **skill-image strip**, with the character **bio** below
        (`roster.json` `bio` from `character/character_database.json`, 139 chars). Clicking a skill swaps the bio
        for that skill's full description (image + `split_desc` segments + classes + cooldown). A character's
        skills are derived client-side from `ability_info.json` keys (`<path_name><n>`). Validated: clicking Aang
        selects it + shows its 296-char bio + 5-skill strip; clicking a skill → "Water Whip" ability view.
        Whole thing collapses to the single-column mobile layout under 760px.
  - [ ] Wire the 8 top menus + Private Match (awaiting textures/menu specs); fuller sequential turn playback

### Serving images
`ASSET_BASE` defaults to same-origin **`/assets/images`** (production: host the app and `assets/` together).
The dev app server only serves `webclient/app/`, so for local testing run a second static server at the repo
root and point the client at it:
```sh
python -m http.server 8791 --bind 127.0.0.1     # serves <repo>/assets/images/...
# in the browser console (or before load):  window.AA_ASSET_BASE = "http://127.0.0.1:8791/assets/images"
```
Cross-origin `<img>` needs no CORS. Filenames are case-sensitive on some hosts (`usoppprof.PNG`) — the manifest
preserves exact case.

## Testing the live path
```sh
godot --headless --path .            # boots root.tscn -> headless -> server + gateway (5695 + 5696)
# then open webclient/test_client.html, Connect to ws://localhost:5696, Send login with a real account.
```

## Design note
`peer_id` here is a gateway-local counter (1,2,3…), distinct from Godot multiplayer peer ids. The routing
layer will key sessions/matches on it exactly as the RPC path keys on the multiplayer sender id — so the
authoritative `Match.validate_input` path is reused unchanged. **The JS client is never trusted.**
