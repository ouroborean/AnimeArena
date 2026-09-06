---
tags: [area/systems, type/concept]
---

# Social Clans and Chat

Four features that share one architectural shape: **clans**, **friends/ignore**, **chat**
(global / match / DM), and the **replay + spectate** viewer. All four are server-authoritative,
all four live inline in `components/server_connection.gd`, and all four were built by cloning the
clan handler pattern rather than inventing a new one each time.

## The canonical endpoint shape

Every social endpoint follows the same five-part recipe. If you are adding a new one, copy this.

| Part | Clan | Social | Chat |
|---|---|---|---|
| ack helpers | `_clan_ok` / `_clan_err` → `clan_result` | `_social_ok` / `_social_err` → `social_result` | `_chat_err` → `chat_result` |
| snapshot builder | `_clan_state_body(username)` | `_social_state_body(username)` | — (ring buffers) |
| push-if-online | `_send_clan_state_to` | `_send_social_state_to` | direct `send_to_peer` fan-out |
| handlers | `_json_clan_*` (16 of them) | `_json_social_*` / `_json_friend_*` / `_json_ignore_*` | `_json_chat_send` / `_json_chat_history` |
| dispatch | a `match` case in `_on_json_message` | ditto | ditto |

The client half of the recipe (a menu overlay with five registration points, an off-render search
input, a two-tap destructive guard) is documented in [[Web Client Architecture]].

Both panels are **snapshot-driven**: an action never optimistically mutates `S.clan` or `S.social`.
The client sends, the server validates and pushes back a *full* state body, and the panel repaints
from that. The single exception is `friend_presence`, which patches one status field the server just
told us so a dot change doesn't need a refetch.

## Clans

The model (`components/clan.gd`) predates the web client: members keyed by
`Rank {LEADER=0, OFFICER=1, MEMBER=2}`, wins/losses, `applied_players`, `invited_players`,
`banner_url`, persisted to `clans/<name>.dat`. What was rebuilt for the web client is the transport
— the old `receive_clan_*` `@rpc` handlers are dead (see [[System Overview]] on the retired Godot
transport); everything goes through `_json_clan_*`.

### Deliberate design decisions

These are the owner's calls. Do not "fix" them without asking.

- **Two tiers only.** Leader + Member. `OFFICER` exists in the enum and is always empty. There is no
  promote/demote.
- **Join = invite OR request.** A leader invites by username (target accepts/declines), or a player
  finds a clan via search and applies (leader approves/denies). No instant open-join.
- **A leader cannot leave** — they must disband. Leaving would orphan the clan. Disband deletes
  `clans/<name>.dat` and sets every member Clanless.
- **One clan per player**, sentinel `"Clanless"` on `player.clan`.

### Security the original code lacked

```gdscript
# A clan name becomes the filename clans/<name>.dat, so it must be sanitized:
# reject path separators / traversal and restrict to a safe charset + length.
func _clan_name_valid(raw) -> bool:
```

3–24 chars; letters, digits, space, `_`, `-`, `'` only. `_clan_name_taken` is case-insensitive
*and* checks the filesystem, so `"Foo"`/`"foo"` cannot coexist.

Every mutating handler resolves the actor from `get_player(logical_peer)` and re-checks
leader/membership **server-side** — the old code trusted the client UI. `banner_url` is restricted
to empty or an `http(s)://` URL, because it is rendered as an `<img src>` on every member's client.

Pending offers live authoritatively on the **clan** side (`invited_players` / `applied_players`).
The player-side `clan_invitations` / `clan_applications` arrays are not persisted, so a Clanless
player's pending offers are derived by scanning `clans{}` in `_clan_state_body`.

> [!warning] Trap: the `clans/` directory is not guaranteed to exist
> It is untracked runtime state. `save_clan` used to open `clans/<name>.dat` without ensuring the
> directory — when it was absent the write silently no-opped, clans existed only in memory, and
> every restart wiped them. `save_clan` (`server_connection.gd:1815`) now `make_dir`s and
> null-guards the open. A player whose `player.clan` points at a clan not in `clans{}` is
> self-healed to `"Clanless"` on the next `clan_state` (`_clan_state_body`, ~L4582).

> [!warning] Trap: `get_level_from_wins` used to eat the win count
> Clan level is derived from wins (10 wins for L2, ×1.8 each level). The old implementation
> subtracted from `self.wins` while looping, corrupting the record every time the level was read.
> `get_level_progress()` (`clan.gd:114`) is now the single source of truth and uses a local copy; it
> returns `{level, into, needed}` so the client can draw a progress bar.

### Clan W/L scoring

```gdscript
static func clan_record_counts(winner_clan: String, loser_clan: String,
                               winner_is_bot: bool, loser_is_bot: bool) -> bool:
    if winner_is_bot or loser_is_bot:
        return false          # a bot seat has no clan and never moves a record
    return winner_clan != loser_clan
```

`server_connection.gd:71`. Any match between two humans in *different* clans counts — including
clan-vs-Clanless, which moves the one record that exists. Two Clanless players compare equal and
move nothing, as do two members of the same clan. The function is `static` and pure so a probe can
call it on a bare instance.

Only Quick and Ranked reach the call site (`:3462`) — Private and practice are excluded upstream,
Campaign returns early, and bot seats fail the non-bot gate. Both sides are persisted with
`save_clan` (the old path only bumped memory).

A leader-only `clan_reset_record` route zeroes `wins`/`losses` — which resets the level to 1, since
level is win-derived — and pushes a fresh `clan_state` to every member.

## Friends and Ignore

Four arrays on the Player, all **unforgeable**: `friends` (cap 100), `friend_requests_in` /
`friend_requests_out` (cap 50), `ignored` (cap 100). They round-trip through `save()` /
`load_player()` and are deliberately absent from `absorb_cosmetic_update`, the client-writable path
— the same recipe as `wins`/`losses`/`campaign_state`. See [[Server Authority Model]].

Messages: `social_state`, `friend_request`, `friend_accept`, `friend_decline`, `friend_cancel`,
`friend_remove`, `ignore_add`, `ignore_remove` (C→S); `social_state`, `social_result{ok,note}`,
`friend_request_notice{from}`, `friend_presence{username,status}` (S→C).

Presence is pushed at three lifecycle sites — login (`online`), `handle_disconnect` while in a match
(`disconnected`), `wipe_session` (`offline`) — via `_push_presence_to_friends`, which notifies only
the target's own friends who are currently online. `_player_status(uname)`
(`server_connection.gd:489`) is shared with the admin panel and the public profile:

| Condition | Status |
|---|---|
| not in `sessions` | `offline` |
| `sess.current_match` valid | `in match` |
| `sess.status == DISCONNECTED` | `disconnected` (rendered "Away") |
| otherwise | `online` |

### The oracle-free ignore

This is the subtle part and it is easy to break.

A "silent drop" is only silent if it equalises the **actor's entire observable state**, not just the
ack string. `_json_friend_request` therefore performs the whole actor-side commit *before* it knows
whether delivery will happen:

```gdscript
# ACTOR-side commit. Everything the actor can observe (the note, the extra social_state frame,
# and the persisted requests_out entry) happens here, IDENTICALLY whether or not the target ends
# up receiving the request.
actor.friend_requests_out.append(t_name)
resave_player(actor)
_social_ok(json_pid, "Friend request sent to " + t_name)
_send_social_state_to(actor.username)
if actor.username in target.ignored:
    return
if target.friend_requests_in.size() >= FRIEND_REQ_CAP:
    return
```

A block and a full inbox are byte-identical to a real send from the sender's side: same note, same
two frames, same persisted ghost entry in `requests_out`. Compare with *actor-ignores-target*, which
is a plain visible error — that is the actor's own state, not an oracle.

Ordering matters: the **mutual auto-accept** branch (the target already requested me → instant
friendship) sits *ahead* of the silent drop. That is safe only because ignoring someone severs their
pending request to you, so the branch is unreachable under target-ignore.

`ignore_add` **severs** in both directions: the friendship and every pending request either way.
The target gets a refreshed `social_state` push — a plain snapshot that never says "you were
blocked".

`ignore_remove` erases both the resolved canonical username and the raw typed value, so a stale
entry whose account has since been removed can still be cleared.

### Guards worth keeping

- Existence guards on decline/cancel/remove: bail **before any write** if there is nothing to
  do, so a client can't force repeated `resave_player` + push cycles against an arbitrary account
  (a disk-write amplifier).
- Self-target guards on accept/decline/cancel/remove.
- `friends ∩ ignored` is kept empty — both `friend_request` and `friend_accept` refuse a target you
  ignore.

### Rate limiting

```gdscript
func _rate_ok(session, key: String, max_n: int, window_ms: int) -> bool
```

A sliding window over `Time.get_ticks_msec()` (monotonic — immune to wall-clock changes) stored per
session in `ServerSession.rate_buckets`.

| Bucket key | Limit |
|---|---|
| `friend_request` | 6 / 60s |
| `friend_mutate` (accept/decline/cancel/remove) | 30 / 60s |
| `ignore_mutate` | 20 / 60s |
| `chat` | 5 / 10s |

> [!danger] Key by a bounded set, never by user input
> A bucket entry persists for the life of the session. Keying by something unbounded — say, every DM
> recipient — grows `session.rate_buckets` without limit. Keys must be action/channel **types**.
> The contract is spelled out in the comment above `_rate_ok` (`server_connection.gd:446`).

## Chat

Three channels, all backed by RAM ring buffers on the server (no persistence — a deliberate v1 call):

| Channel | Buffer | Cap |
|---|---|---|
| global | `chat_global: Array` | `CHAT_GLOBAL_CAP = 100` |
| dm | `chat_dm["<a>\|<b>"]` (usernames sorted, joined by a pipe) | `CHAT_DM_CAP = 50` each, `MAX_DM_BUFFERS = 2000` keys |
| match | `chat_match[match_uid]` | `CHAT_MATCH_CAP = 50`, freed at match end |

Text is sanitised by `_clean_text(s, CHAT_MAX_LEN=300)`: control chars (including newlines and tabs)
become spaces, runs of spaces collapse, trim, cap. It pre-caps at `maxlen * 4` before the O(n) loop
runs, which is safe because collapsing can only shrink the string.

`admin_toggle_global_chat` flips `global_chat_enabled` (a kill switch, not persisted) and pushes
`global_chat_state` to everyone. `player.muted` blocks **all** sends and is server-only — it was
briefly forgeable through `absorb_cosmetic_update` and that line was removed.

### Membership and ignore, unified

- **Fanout** — skip any recipient who has the *sender* in their `ignored`. The sender never ignores
  themselves, so they always get their own echo.
- **History** — hide any message whose `.from` is in the *viewer's* `ignored`.
- **DM** — sender ignores target → visible error. Target ignores sender → recorded + echoed to the
  sender, silently dropped for the target. Same oracle-free property as friend requests: the
  sender's echo is byte-identical whether or not it was delivered.

The match channel is **derived server-side** from `session.current_match`, so the client cannot spoof
a match id, and membership is checked against `m.get_player_usernames()`:

```gdscript
# Membership (D6): only the two match participants chat here — spectators also carry a
# current_match pointer, so exclude anyone who isn't an actual player.
if not (actor.username in m.get_player_usernames()):
    return _chat_err(json_pid, "You're not in a match")
```

Spectators can neither send to nor read the match channel.

> [!warning] Trap: `chat_dm` key growth
> Each DM pair creates a permanent buffer that is never freed on logout or match end. Without a
> bound that is an unbounded RAM leak. `chat_dm_lru` is a least-recently-used key list; on every DM
> the key is moved to the back and keys past `MAX_DM_BUFFERS` are evicted from the front.

## The chat dock — built once, reconciled in place

The dock is a **body-level** DOM node (`document.body.appendChild`), not part of `#app`. That is what
lets it survive `render()`'s teardown of the app tree and the battle screen's zoom transform. The
input uses the off-render buffer + `data-focus-id` pattern so a message flood never eats the caret.

The original implementation did `_socialDock.replaceWith(chatDockTree())` on every update. That is
exactly what users reported as *"the chat flickers / appears and disappears"* — the whole dock was
being torn out and re-animated on every message and every tab change.

The current design (`app.js` ≈ L4623–4741):

- Module-cached singletons `_socialDock`, `_chatPill`, `_chatPanel`.
- `buildChatPill` / `buildChatPanel` construct **once**; `updateChatPill` / `updateChatPanel`
  **mutate**.
- `syncSocialUI` picks pill-vs-panel by `C.expanded` and only remounts on the pill↔panel transition,
  which is user-initiated and fine to animate.
- The panel keeps persistent child refs (`_tabsEl`, `_dmTabsEl`, `_logEl`, `_inputEl`, `_sendBtn`)
  plus reconcile state (`_view`, `_count`, `_firstMsg`).
- Tab buttons and DM tabs are `replaceChildren`'d — cheap, few nodes. The **input element persists**;
  only `disabled` / `placeholder` toggle, and `.value` is written only when not focused or when the
  desired value is `""` (so a send-clear works mid-focus but live typing is never clobbered).

### The log append fast-path

`syncSocialUI()` runs at the end of **every** `render()`, and `render()` fires on any state change —
friend presence pings, every battle snapshot, menu navigation, toasts. So an expanded dock's
`updateChatPanel` runs constantly with no chat change at all. The log update has exactly three
branches:

```js
const headIntact = count > 0 && panel._firstMsg === msgs[0];
if (!viewChanged && headIntact && count === panel._count) {
  /* NOTHING — leave the log DOM untouched */
} else if (!viewChanged && headIntact && count > panel._count && panel._count >= 0) {
  for (let i = panel._count; i < count; i++) logEl.appendChild(chatMsgRow(msgs[i]));  // tail grew
} else {
  logEl.replaceChildren(...);   // head changed / view switch / trim
}
```

> [!danger] Both guards are load-bearing — this bug shipped once
> **`count === panel._count` no-op branch.** Without it the steady state rebuilds the entire log
> O(n) on every unrelated render *and* wipes any in-progress text selection, since a Selection
> anchors by node reference.
>
> **`headIntact` — first-message OBJECT identity.** The client channels are ring buffers capped at
> 100 via a front `shift()` (`app.js:373`). *At the cap*, a new message does push + shift, so
> `count` stays 100 and equals `panel._count` — a naive `count >= _count` append loop would run
> `for (i = 100; i < 100)`, zero iterations, and **the log silently freezes and never shows another
> message until you switch tabs**. Because every message is a fresh object literal (and
> `chat_history` reassigns the array to freshly-mapped objects), a shift or a history replace
> changes `msgs[0]`'s identity → `headIntact` false → full `replaceChildren` re-sync. The strict
> `>` rather than `>=` is a second, independent guard against the same equal-count case.

Message text always goes through `document.createTextNode` (`chatMsgRow`), never `innerHTML`.

Scroll behaviour: the log pins to the bottom via `data-scrollkey="chat-log"` and a `wasAtBottom`
check (within 48px), so a live stream doesn't yank someone reading history. On a fresh open,
`syncSocialUI` forces `scrollTop = scrollHeight` because re-appending the panel resets `scrollTop`
to 0, which makes the `wasAtBottom` read stale.

### Notification styling

Unread badges originally used `var(--accent)` — the same blue as every panel border, button hover
and selected state — so they read as decoration and got ignored. A dedicated `--notify: #ff3b47` was
added, deliberately separate from `--bad` (the error red) so error styling stays independently
tunable, and `.aa-badge` / `.chat-dock-badge` / `.chat-tab-badge` point at it. A `.has-notify` class
adds a 1.8s breathing halo — motion is what actually catches peripheral vision — honouring
`prefers-reduced-motion` by keeping the colour and dropping the animation.

The Social menu badge counts **pending friend requests plus unread DMs** (`chatDmUnread()`), because
a DM is the thing a player most wants surfaced and Social is where they answer it.

> [!tip] `classList.toggle`, not a className rewrite
> `updateChatPill` uses `pill.classList.toggle("has-notify", total > 0)`. The pill is reconciled in
> place and never rebuilt, so clobbering the class list would drop `.chat-dock` itself and the pill
> would lose all its styling.

> [!warning] Headless preview freezes CSS animations
> Measuring the dock in the Browser pane shows the panel stuck at `transform: translateY(10px)`
> because `visibilityState === "hidden"` freezes the animation clock at frame 0. It is not a layout
> bug — force `panel.getAnimations().forEach(a => a.finish())` and it settles at the real
> `bottom: 14px`. See [[Verification Playbook]].

## Replays and spectating

The same suite, one layer up. Both were ~70–90% server-complete on the retired RPC path before being
wired to the gateway.

- **Replays** — `MatchReplayLog` records every match (initial snapshot + per-turn
  `{events, snapshot}`). `_persist_replay` writes `replays/<match_uid>.replay` for QUICK / RANKED /
  PRIVATE (skipping BOT and CAMPAIGN); `_sweep_replays` prunes 30d / 5000 at boot and daily, using
  the filename's `YYYYMMDD` prefix as the date. Access is participants-only. The client can also save
  a `.replay` to disk and reload it — `enterReplay` deep-clones the payload **before** the ingest
  loop, because `ingestSnapshot` mutates snapshots in place.
- **Spectating** — `spectate {username}` (rate 5/min). Every *target-side* denial (offline,
  no match, match type, privacy setting, ignore, 20-viewer cap) returns the **one** generic deny
  note, so it can't be used to probe. `Player.allow_spectators` is `"all" | "friends" | "off"`,
  written only through `social_setting`, and tightening it evicts current watchers.
- **Hidden info** — spectator copies are stripped: `_spectator_safe_events` drops events the
  recorder tagged `"invisible"`, and `_spectator_safe_snapshot` drops every effect whose
  `visibility != "all"` and blanks `execution_preview` outright. Players and participant replays keep
  the full payloads.

> [!danger] `send_queued`, not `send_text`, for large bursts
> `replay_fetch` ships the replay in 24000-char chunks. Plain `send_text` silently **drops frames**
> once a peer's 64KB outbound WS buffer backs up on a real network — loopback never reproduces it,
> and both the harness and the browser passed while the feature was broken for real users. The
> gateway now has a per-peer outbound queue drained in `poll()` with headroom checks. Use
> `json_gateway.send_queued` for any burst of large frames.

Two lifecycle guards worth remembering: `process_surrender` needs a participant guard (a spectator
could otherwise force-end a match they were watching), and `handle_disconnect` detaches spectators
immediately rather than putting them through the 120s reconnect hold.

## Related

- [[Server Authority Model]] — unforgeable Player fields and the validate-then-echo pattern
- [[Web Client Architecture]] — overlay registration, `set()`/`render()`, off-render input buffers
- [[Matchmaking and the Ladder]] — where clan W/L is actually scored
- [[Admin and Live Ops]] — mute/unmute, the global-chat kill switch
- [[Traps That Have Bitten Us]] — the CSS `@media` brace gap that broke this dock's styling once
- [[Verification Playbook]] — the WS harness `waitFor` stale-push gotcha that bit the clan tests
