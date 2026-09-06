---
tags: [area/architecture, type/reference]
---

# Web Client Architecture

The client is **three files, no build step, no framework, no modules**:

| File | Lines | Job |
|---|---|---|
| `webclient/app/index.html` | 24 | load the other two |
| `webclient/app/net.js` | 64 | one WebSocket, JSON frames, type-keyed handlers |
| `webclient/app/app.js` | ~6.5k | everything else, in one IIFE |
| `webclient/app/style.css` | ~1.8k | all styling |

Plus a set of static JSON manifests fetched at boot — see
[[Data Files and the Deploy Mirror]].

Classic scripts, not ES modules, so the whole thing loads over `file://` and any static host. There
is nothing to `npm install` and nothing to compile. Editing `app.js` and reloading is the entire
dev loop.

## Boot

`index.html` does one clever thing and it is a dev affordance, not architecture:

```html
<script>
  document.write('<link rel="stylesheet" href="style.css?v=' + Date.now() + '">');
</script>
…
<script>
  var _v = Date.now();
  document.write('<script src="net.js?v=' + _v + '"><\/script>');
  document.write('<script src="app.js?v=' + _v + '"><\/script>');
</script>
```

Python's `http.server` sends no `Cache-Control`, so without a per-load version the browser serves
stale JS after every edit. `document.write` (rather than injecting `<script async>`) keeps both files
in the parse flow so `app.js`'s `DOMContentLoaded` boot still fires — an async injection would run
after `DOMContentLoaded` and the app would never start.

`fetch()` isn't covered by that trick, so the JSON manifests carry their own bust:
`const DATA_BUST = "?v=" + Date.now();` (`app.js:23`).

## Transport — `net.js`

```js
class AANet {
  on(type, fn) { (this.handlers[type] = this.handlers[type] || []).push(fn); }
  send(type, payload) { this.ws.send(JSON.stringify(Object.assign({ type }, payload || {}))); }
}
```

Every frame in both directions is `{type, ...fields}`. Inbound frames fan out to
`handlers[m.type]` and then to `handlers["*"]` — `app.js:243` registers a `"*"` handler that logs
every message into the in-battle log panel, which is the fastest way to debug a wire problem.

> [!info] The keepalive is load-bearing
> A 25-second `ping` (`net.js:18`) runs while the socket is open. Without it an idle lobby socket
> goes silent, nginx (or any proxy, ~60 s idle timeout) closes it, the client reconnects, and you get
> a churn loop that also floods the server log. The server answers `pong`; nothing consumes it.

Where to connect (`app.js:38`):

- `window.AA_WS` if set, else
- on a **dev origin only** (`localhost`, `127.0.0.1`, `192.168.*`, `10.*`, `172.16–31.*`, `*.local`):
  a `?ws=<url>` query param (persisted to `localStorage`, `?ws=reset` clears it), then a saved
  `aa_ws`, then `ws://<same host>:5695`
- otherwise the hosted `wss://server.animaslashanimearenaserver.org`

The dev-origin gate exists so a crafted `?ws=` link can never redirect a real production login to a
hostile gateway.

## State and rendering

Everything lives in one object literal, `S` (`app.js:117`) — roughly 90 fields spanning connection
status, the player blob, every menu overlay's working state, the campaign runtime, the battle
snapshot, staged actions, the chat ring buffers, and maintenance state.

```js
function set(patch) { Object.assign(S, patch); render(); }
```

That's the whole framework. `render()` (`app.js:4743`) does a **full teardown and rebuild** of
`#app`:

```js
root.innerHTML = "";
const scr = S.screen === "login"    ? loginScreen()
          : S.screen === "menu"     ? menuScreen()
          : S.screen === "draft"    ? draftScreen()
          : S.screen === "campaign" ? campaignScreen()
          :                           battleScreen();
root.appendChild(scr);
```

Then modals are appended on top (`menuModal`, `avatarModal`, `randomAllocModal`, …), and finally
`fitBattleViewport()`, `syncAdminUI()`, `syncSocialUI()` run.

Blowing away the DOM every render is fine for a board of six characters, but it destroys three things
the browser owns. `render()` restores all three:

1. **Scroll positions** — captured into `savedScroll` before teardown, reapplied after the new tree
   (including modals) is attached and laid out. The battle log opts out; it pins itself to the
   bottom.
2. **Focus and caret** — any `<input data-focus-id="…">` that had focus is re-found after the
   rebuild and its `selectionStart/End` restored. Without this, a `clan_state` push arriving while
   you type an invite name drops the cursor and the in-flight keystroke.
3. **HP-bar animation** — bars are rendered at their *previous* width with a `data-target-w`
   attribute; after attach, `void b.offsetWidth` forces a reflow to register the start value and then
   the target width is set, so the CSS transition animates instead of snapping. A forced reflow is
   used rather than `requestAnimationFrame` because rAF is throttled when the tab isn't actively
   rendering.

> [!tip] The off-render input buffer
> Text inputs whose value feeds a search or a form (`clanSearchQuery`, `charSearch`, `btySearch`,
> `chatInput`, …) write to `S` directly in `oninput` and **never call `set()`**. Re-rendering on every
> keystroke would be both wasteful and caret-hostile. `data-focus-id` covers the case where an
> *unrelated* state change re-renders mid-typing.

### Reconciled, not re-rendered: the chat dock

The body-level social dock is the one part built **once and mutated in place**
(`syncSocialUI` region). The original `replaceWith(chatDockTree())` on every update was visible as
"the chat flickers / appears and disappears" — the whole dock DOM was torn out and re-animated on
each message. Now `_socialDock` / `_chatPill` / `_chatPanel` are module-cached singletons with
persistent child refs, and only the pill↔panel transition remounts.

> [!danger] The log append fast-path needs two independent guards
> `syncSocialUI()` runs at the end of *every* `render()`, so an expanded dock updates constantly with
> no chat change at all. The log has three branches:
> ```js
> const headIntact = count > 0 && panel._firstMsg === msgs[0];
> if      (!viewChanged && headIntact && count === panel._count) { /* nothing */ }
> else if (!viewChanged && headIntact && count >   panel._count) { /* append the tail */ }
> else                                                           { logEl.replaceChildren(...); }
> ```
> The no-op branch is essential or the steady state rebuilds the log on every unrelated render and
> wipes any in-progress text selection. `headIntact` — first-message **object identity** — is
> essential because channels are ring buffers capped at 100 via a front `shift()`. At the cap, a new
> message does push+shift, so `count` stays 100 == `_count`; a naive `>=` append loop runs zero
> iterations and **the log silently freezes** until you switch tabs. Strict `>` is a second,
> independent guard on the same case.

## Screens

`S.screen` is one of `login | menu | draft | campaign | battle`. `document.body` also gets a matching
class (`battle-mode`, `menu-mode`, `draft-mode`, `campaign-mode`) so CSS can do wide-desktop layouts
per screen.

### The battle screen

`battleScreen()` (`app.js:2751`) is the only place the canonical wire frame is translated to
"mine/theirs":

```js
const myRole  = S.match.canonical_role === 0 ? "p1" : "p2";
const mySide  = snap.sides.find((s) => s.role === myRole)  || snap.sides[0];
const oppSide = snap.sides.find((s) => s.role !== myRole) || snap.sides[1];
const myBase  = myRole === "p1" ? 0 : 3;
const oppBase = myRole === "p1" ? 3 : 0;
const myTurn  = snap.acting_role === myRole;
const interactive = myTurn && !over && !isViewer();
```

`snap.sides[0]` is **always** p1 and `sides[1]` always p2 — the snapshot is index-stable, so the
client does the seat swap, not the server. `myBase`/`oppBase` convert a team-local slot index into
the canonical 0–5 index used by every outbound field.

`isMyTurn()` (`app.js:1312`) is just `snap.acting_role === myRoleStr()`. Note that the client never
sees, and must never reason about, the server's `waiting_for_turn` — that flag is a side flag with a
famous inversion trap on the server side (see [[The Turn Pipeline]]).

The ability bar is rendered **verbatim** from the snapshot: `usable`, `cost`, `special_targets`,
`target_type`, `cooldown_remaining` are all server-resolved. The client recomputes none of it; see
[[Server Authority Model]].

### Building a turn

```
tap ability  → S.targeting = {char_idx, ability_idx, ability_name, special_targets, target_type, cost}
tap target   → pickTarget(canonTarget) → stage(...)  → S.staged.push({...})
End Turn     → defaultExecOrder() → S.execOrder → randomAllocModal (if RANDOM pips or >1 step)
             → submitTurn() → net.send("submit_turn_input", {input})
```

> [!danger] The clicked target MUST lead `target_idxs`
> ```js
> if (tt === 2)      targets = [canonTarget].concat(t.special_targets.filter((i) => i !== canonTarget));
> else if (tt === 1) targets = [canonTarget].concat(t.special_targets.filter((i) => i !== canonTarget && (i < 3) === (canonTarget < 3)));
> else               targets = [canonTarget];
> ```
> `webclient/app/app.js:1446`. The server walks `target_idxs` in order and
> `targeter_component.add_target` makes the **first** one `main_target`; nothing downstream
> re-derives it. ~21 abilities split primary from splash off `main_target` (X-Burner 25/10, gojo3
> 45/15, korra7 40/20, boruto6 20/10, ace3, ganta3, lizandpatty1/2, byakuya5, gallantmon1, …).
> The original code did `t.special_targets.slice()`, and `special_targets` arrives in the server's
> ascending canonical order — so the **top character on the clicked side was always the primary**,
> whatever you actually clicked, with no error anywhere. Regression-locked by
> `battle: an AoE sends the CLICKED target first` in `webclient/app/aa-tests.js`. Full story in
> [[Targeting and Main Target]].

`energy_allocation` must cover the turn's entire spend — specific costs plus the assigned RANDOM
pips, as `[[color, count], …]`. The server drains the pool *solely* from this list
(`app.js:1520-1525`), which is also why it never contains the `RANDOM` key (4): the passive replay
path would crash on `pool[4]`, which doesn't exist.

`execution_order` is the player-chosen resolution sequence: skill steps as canonical `char_idx`
(0–5), ticking steps as the server's wire ids (`>= 6`, from `snapshot.execution_preview`).

> [!warning] A rejected turn used to lock the UI forever
> `S.acting = true` gates End-Turn and ability taps. The server drops an invalid input, so without a
> recovery path the client stayed stuck. Two fixes: the gateway now replies with an `error` frame on
> rejection, and `armTurnWatchdog()` (`app.js:1501`) re-enables the UI after 20 s (quick/bot) or
> 130 s (PvP, which can legitimately run a full turn timer).

### Consuming a turn result

`S.net.on("apply_turn_result", …)` (`app.js:658`):

1. Clear the watchdog.
2. **Drop the frame if `!S.match`** — every legitimate frame is preceded by a context-setter
   (`onMatch` / reconnect / `spectate_init`). Without this, a spectator broadcast still in flight
   when the user hits Leave repopulates the snapshot on the *menu* screen.
3. Fire one-shot VFX that need the **pre-turn** snapshot (Misaka's Ultra Railgun, Mine's Blast
   Blade) — ordering requirement, they must run before the `set()` below.
4. Derive `matchResult` from a `MATCH_ENDED` event (or `snapshot.match_over`), plus the AP gain.
5. `set({ snapshot: ingestSnapshot(m.snapshot), staged: [], execOrder: null, … })`, then
   `playEventAnimations(m.events)`.

`ingestSnapshot` (`app.js:1180`) is the single normalization point — it resolves ability aliases into
canonical keys and remembers authored-character display names. It is **not idempotent**, which
matters for the replay viewer: each frame's snapshot is ingested exactly once and stepping just swaps
pre-normalized objects in.

> [!warning] Ranked-ness is a flag, never a label substring
> The ranked match's display label is **"Ladder Match"**, so every `/ranked/i.test(S.match.kind)`
> gate in the client was permanently false and silently disabled three features (the post-game Rating
> row, the ladder AP figure, the rating delta). It is now `S.match.ranked`, read through
> `isRankedMatch()` (`app.js:641`). Never gate behaviour on a display string.

## Menu overlays — the five registration points

Adding a top-menu panel (Profile, Ladder, Clan, Social, …) touches exactly five places. Clone the
Ladder overlay:

1. `TOP_MENUS` + `TOP_OVERLAYS` (`app.js:1744-1745`) — the label and its key.
2. `MENU_TITLES` + `MENU_RENDERERS` (`app.js:4808-4809`) — the title and `key: () => keyMenu()`.
3. `openMenuOverlay` (`app.js:1746`) — an `if (o === "key") { … }` branch that fires the server
   request on open.
4. An `S` state slot plus `S.net.on("<resp>", (m) => set({…}))` beside the `ladder` handler.
5. Write `keyMenu()`. The scrim/title/close chrome comes free from `menuModal()`, which `render()`
   appends at `if (S.screen === "menu" && S.menuOverlay)`.

Reusable pieces: `infoCard(blob, name, mine)` builds an identity card from *any* player blob;
`xpToLevel(xp)` (not `masteryLevel()`, which is hardwired to the logged-in player);
`portraitUrlFor` / `nameFor`; `.ld-list`/`.ld-row` rows; `.mg-cell`/`.mastery-badge` tiles;
`.clan-input` for a search box.

> [!danger] A two-tap "arm" guard must reset on overlay OPEN
> The pattern is a module-scope `let _xArm = false`; the button either arms or fires. Resetting the
> flag only in the response handlers is a real bug that shipped review: arm → leave the overlay →
> re-open re-renders **synchronously** from cached state with the flag still true, so the button
> reads "Confirm?" pre-armed and one click fires the destructive action before any network
> round-trip can disarm it. Every such guard needs a reset in `openMenuOverlay`'s open branch — the
> clan one does it at `app.js:1752`:
> ```js
> if (o === "clan") { S.net.send("clan_state", {}); S.clanSearchResults = null;
>                     _clanDisbandArm = false; _clanResetRecordArm = false; }
> ```

## CSS discipline

> [!danger] Check brace balance after every `style.css` edit
> An edit that inserted mobile rules just before a `@media (max-width:760px)` block's closing `}`
> **dropped that brace**. Every rule after the media block — the chat dock, the admin FAB, the viewer
> bar, the VFX overlay — got nested inside the query, so they only applied at ≤760px. On desktop
> those body-level elements lost all styling and fell back to the global `button { width:100%;
> background:accent }` rule: the admin FAB became a giant blue rectangle and the chat panel became
> unstyled stacked text. **It slipped through because it was only verified at 375px, where the
> trapped rules still applied.**
>
> - After any `style.css` edit, verify `{` count == `}` count.
> - If an Edit's `old_string` ends at a block's closing `}`, make sure `new_string` re-emits it.
> - Verify responsive edits at both a width inside the query *and* one outside it.
> - Body-level elements losing style while `#app` buttons stay styled ⇒ suspect a mid-file syntax
>   error, since those rules sit late in the file.
>
> The notification-glow rules at the end of `style.css` carry a comment explaining why they are
> deliberately kept top-level and outside every `@media` block.

## Testing

`webclient/app/tests.html` loads `net.js → app.js → aa-test-harness.js → aa-tests.js` in parse order
and runs ~320 assertions against the **real** app code, with `#app` positioned off-screen at
1280×880 so geometry-based assertions still work.

The bridge is `window.AA` (`app.js:6488`), a dev/test handle exposing `state`, `render`, `set`, and
an explicit `fns` / `consts` allowlist of non-battle internals. The harness snapshots a clean
baseline of `S` (skipping `net` and the big immutable reference-data fields), resets to it between
tests, and installs a capturing `net.send` mock so outbound frames can be asserted.

Results mirror to `window.__AATEST`, which is how the suite is checked headlessly.

> [!warning] You cannot run a live match from the in-app Browser pane
> It cannot open `ws://127.0.0.1:5695`. Use `tests.html` for client logic and a Node WebSocket
> harness for the wire. And when asserting damage from a live bot match, assert the *shape* of a
> split (main > splash, splash values equal), never raw numbers — bot teams are random and a flat
> damage reduction or a guardian redirect shifts every value. See [[Verification Playbook]].

Related: [[System Overview]], [[Server Authority Model]], [[The Turn Pipeline]],
[[Data Files and the Deploy Mirror]], [[Social Clans and Chat]], [[Campaign Mode]],
[[Admin and Live Ops]].
