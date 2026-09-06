---
tags: [area/systems, type/reference]
---

# Matchmaking and the Ladder

Four queues exist, and they are deliberately *not* the same game economically. Everything below is
server-authoritative and lives in `components/server_connection.gd`, `components/Rating.gd` and
`components/rank_component.gd`. See [[Server Authority Model]] for why none of it is client-derived.

## The reward table

`_calculate_ap_gain` (`components/server_connection.gd:1854`) is the whole AP economy. AP is **flat
per queue** — all streak scaling was deleted when Quick stopped recording wins.

| queue | AP win / loss | W/L record | rating |
|---|---|---|---|
| Bot Match (explicit queue, `practice_match == true`) | 50 / 0 | none | none |
| Quick (including its bot fallback) | 100 / 50 | **none** | none |
| Ladder vs human | 500 / 50 | yes | full |
| Ladder vs bot | 250 / 50 | **yes** | capped / scaled |
| Private | 0 / 0 | none | none |

> [!warning] Trap
> The W/L block in `handle_server_match_ended` is gated on `if nmatch.match_type ==
> BattleManager.MatchType.RANKED` (`server_connection.gd:3429`). That single line makes
> `rank.wins`, `rank.losses`, `rank.streak`, `rank._ranked_streak` and `rating` **ladder-only
> counters**. Everything downstream silently inherits it: the ladder's by-wins and by-streak
> boards, clan wins/losses (clans now level off ladder play only), and
> `Rating.calc_performance_multiplier`, which is seeded from the global streak.

Quick and Bot still feed **bounty** progress — that gate is `match_type != PRIVATE and not
winner_is_bot` (`server_connection.gd:3484`) and never reads W/L.

The client duplicates this table in `matchApGain()` (`webclient/app/app.js:642`) to render the
game-over modal. **Change both together.** Note the ordering there: a `/bot/i` label test fires
before the ladder branch, so the explicit practice bot pays 50/0 while a quick-queue fallback bot —
which is labelled "Quick Match" — falls through to the Quick rate. See
[[Web Client Architecture]].

## Rank tiers are a pure function of rating

`Rank.tier_for_rating(rating) -> [Type, division]` (`components/rank_component.gd:40`).

```gdscript
const TIER_SPAN := 400        # rating points per rank
const DIVISION_SPAN := 100    # rating points per division within a rank
const DIVISIONS := 4          # Iron 1 (lowest) .. Iron 4 (highest)
```

Iron at 0, Bronze 400, Silver 800, Gold 1200, Platinum 1600, Diamond 2000, Master 2400,
**Grandmaster 2800+ and open-ended** — its divisions are `mini(..., DIVISIONS)` so an absurd rating
saturates at GM 4 rather than overflowing into a bogus enum index.

`rank` and `rank_tier` are **read-only getters** derived on every read (`rank_component.gd:34-37`).
There is no stored tier, no promotion series, no demotion buffer. Consequences worth internalising:

- A badge can never disagree with the rating behind it. There is nothing to migrate or resync.
- `player_component.load_player` deliberately does **not** load `data['rank']` / `data['tier']` —
  they stay in the save as a readable record and are ignored, because loading them could only
  introduce drift.
- Resetting a record just zeroes the rating; that *is* the demotion to Iron 1
  (`_reset_player_record`, `server_connection.gd:516`).
- `_build_ladder_info` (`server_connection.gd:4380`) ships `rank`/`tier` per row so the ladder badge
  is derived server-side too — no duplicate table in JS to drift.

`check_rank_change` / `derank` / `rank_up` were removed as superseded — an RP-and-promo-series design
that never actually ran. `_rp`, `rp_thresholds` and `ranked_streak_thresholds` are kept: `_rp` is
still loaded/saved so no save breaks, and the tables are the reference if a promo layer is ever
wanted *on top of* the derived tier.

> [!info] The prerequisite that made tiers real
> `Rating.add_loss` used to clamp at 1000 (`minimum = rating; if rating >= 1000: minimum = 1000`),
> so **a loss below 1000 cost nothing**. Every player ratcheted to 1000 in ~12 wins and could never
> fall back — Iron and Bronze would have been a one-time on-ramp and the population would compress
> into 1000-2500. The floor is now 0 (`components/Rating.gd:46-51`). The comment block above that
> function exists precisely so nobody reintroduces the clamp.

## Rating movement

Two pieces, both in `components/Rating.gd`:

```gdscript
func calc_base_award():        return max((100 - (rating * .045)), 10.0)
func calc_max_rating_diff():   return max((500 - (rating * .225)), 50.0)

const DISTANCE_SWING := 0.5
func distance_multiplier(opponent_rating, won: bool) -> float:
	var max_diff: float = calc_max_rating_diff()
	if max_diff <= 0.0: return 1.0
	var norm: float = clampf((float(opponent_rating) - float(rating)) / max_diff, -1.0, 1.0)
	return 1.0 + DISTANCE_SWING * (norm if won else -norm)
```

`calc_base_award` is the **magnitude** (100 at rating 0, decaying to a floor of 10 at rating 2000).
`distance_multiplier` is a **single symmetric multiplier** on it, normalised by
`calc_max_rating_diff()` (which itself narrows as rating climbs, so "far apart" means the same thing
at every level) and clamped to ±1 for a range of `1 ± DISTANCE_SWING`.

Measured at rating 1200 (base award 46.0, max diff 230, no streak/performance bonus):

| gap | win | loss |
|---|---|---|
| +400 (opponent above you) | **+69.0** | **−23.0** |
| even | **+46.0** | **−46.0** |
| −400 (opponent below you) | **+23.0** | **−69.0** |

A perfect mirror. Regression-locked by `training/tests/ladder_rating_probe.gd`.

> [!danger] What this replaced, and why
> `calc_scaling_award` / `calc_scaling_penalty` were wrong two ways. They only ever looked *upward*
> (beating or losing to someone below you moved exactly as much as an even match), and the penalty
> carried the wrong sign — **losing to a stronger player cost MORE than losing to an equal one**
> (63.2 vs 46.0 at rating 1200). Both also returned `null` when the two ratings were exactly 1
> apart: no branch covered `rating_diff == 1`, and ratings are integers, so it was a reachable
> "Invalid operands" crash on the very next line.

Wins additionally get `calc_performance_multiplier()` — up to +30%, driven mostly by streak at
`+3%` per win. Losses get none.

### Ladder vs bot

A bot ladder game is a real win/loss on the record but must barely move the ladder — otherwise a
fixed 20s wait is the cheapest way to climb.

```gdscript
if vs_bot:
	# Score it as an even match — pass the winner's OWN rating so distance_multiplier is
	# exactly 1.0 — then cap. min(even-match award, cap) falls straight out.
	winner.rank.add_win(nmatch.match_type, winner.rank.get_rating(), 1.0, RANKED_BOT_WIN_RATING_CAP)
```
(`server_connection.gd:3440-3448`)

- **Win**: scored as an even match, then capped by `RANKED_BOT_WIN_RATING_CAP := 25.0`
  (`server_connection.gd:31`). Not a flat ×0.10 — that made a bot win worth ~5 points, which read as
  not worth playing. The cap is *the lesser of* the even-match award or 25, which is strictly more
  generous for anyone whose even-match award is already under the cap.
- **Loss**: a plain multiplier, `RANKED_BOT_LOSS_RATING_SCALE := 0.5`.

`add_win(opponent_rating, scale, cap)` applies `cap` **after** everything else including the
performance multiplier, so a capped win means "whatever this result was worth, but no more than
cap" (`Rating.gd:30-36`).

## The rating gate

Ladder pairing used to seat the instant two people were queued, widening outward from the queuer's
tier and taking the first body it found — a Grandmaster and an Iron who queued together were matched
immediately. `GATE_BANDS` (`server_connection.gd:56`) makes a pair wait longer the further apart
they are:

```gdscript
const GATE_BANDS := [
	[100, 0.0],   # same division        ->  0s, pairs instantly
	[200, 0.25],  # 1 division apart     ->  5s, under the bot delay
	[400, 0.75],  # 2-3 divisions        -> 15s, still under it: they meet as humans
	[800, 1.5],   # a full rank apart    -> 30s, EXCEEDS the 20s bot delay
	[-1,  3.0],   # 2+ ranks apart       -> 60s, both long gone to bots
]
```

> [!tip] Why the second column is a multiplier, not seconds
> `ranked_required_wait()` returns `float(band[1]) * RANKED_BOT_DELAY`. The waits are stored as
> **multiples of `RANKED_BOT_DELAY`**, never as literal seconds, so the "far-apart pairs meet bots
> first" property survives someone retuning that constant. Retune `RANKED_BOT_DELAY` from 20 to 40
> and every band still lands on the correct side of it.

**The crossover is at 400 rating — a full rank.** Below 400 the required wait stays under the bot
delay and those players still meet each other; at 400 and beyond it exceeds the delay and both are
seated against bots first. 400 was widened up from an initial 200 at the owner's request: 400 is a
gap players reach easily, so a lower crossover would push ordinary ladder neighbours into bot games.

Gate on rating **points**, never badge distance. `tier_for_rating` saturates at Grandmaster 4, so
2800 and 6000 both read "GM 4" — a badge gap of zero for a real gap of 3200.

### The predicate

```gdscript
if ranked_required_wait(d) > minf(wa, wb):
	continue
```
(`_best_gated_ranked_pair`, `server_connection.gd:2451`)

**`minf`, never `maxf`.** "The veteran waited 60s so anyone will do" throws the player who just
clicked Queue at a Grandmaster — the exact stomping this feature exists to prevent. *Both* clocks
must clear the bar. Best pair = closest delta; ties break toward the longest **total** wait so a
newcomer with a marginally better delta cannot repeatedly jump a starving veteran.

Note `/ 1000.0`, not `/ 1000`, when converting the wait from ms — integer division would truncate
every wait to whole seconds and quietly turn a 10s band into an 11s band.

### The architectural gap the gate required fixing

Pairing previously ran **only** inside the enqueue handlers. Nothing re-evaluated the queue
afterwards. With a time gate that means two players who are not yet eligible when the second one
joins would never be looked at again. So a 1s `Timer` (`MM_TICK := 1.0`, built in `_ready` at
`server_connection.gd:314`) drives `_gate_tick()`, and `receive_ranked_match_queue` also calls it
synchronously so close pairs still feel instant.

> [!danger] Never do this
> Do not put an `await` anywhere in `_gate_tick` or anything it calls. That is the *entire* safety
> argument for why a pair cannot be seated twice. `training/tests/match_gate_probe.tscn` asserts it
> against the source (stripping comment lines first — a naive substring check false-positives on
> the comments that discuss `await` by name).

### Sweep guard order is load-bearing

`_ranked_entry_verdict` (`server_connection.gd:2383`) returns `OK` or `REAP`, and **REAP means
delete the entry, never merely skip it**:

1. `get_player(peer) == null` **first**. On a dead peer `get_session` returns null, which makes
   `_in_live_match` report *false* ("free") — checking liveness first would wave a corpse through.
2. session null / `peer_id` mismatch / not `ONLINE`. A reconnect rebinds the held session to a
   **brand-new peer id** while the entry still holds the old one; a DISCONNECTED session also
   lingers for the whole reconnect window and keeps its `current_match`.
3. `_in_live_match`, **never** `_already_in_match` — the latter sends an error frame, and a 1Hz
   sweep calling it is a red-toast spam cannon at everyone currently in a game. Reaping rather than
   skipping is what closes the `match_ended` window, where `current_match` is nulled and a leftover
   entry would yank a lobby-standing player into a ladder game they never queued for.
4. First-seen-wins dedupe per pass (`_collect_ranked_candidates`), or one sweep pairs a peer with
   two opponents and the second seat wipes the live board via `team.clear_characters()`.

`_collect_ranked_candidates` also reads the **live** rating from `get_player(peer).rank`, not the
display-package snapshot taken at enqueue — a record reset can move a rating out from under a
queued entry.

## Bot fallbacks

Two different fallbacks, and they are not symmetric.

| | quick fallback | ladder fallback |
|---|---|---|
| function | `_start_bot_fallback` (`:2269`) | `_start_ranked_bot_fallback` (`:2296`) |
| wait | the player's own `bot_queue_delay`, `clampf(delay, 15.0, 9999.0)` | fixed `RANKED_BOT_DELAY := 20.0` |
| resulting match | `MatchType.BOT`, `practice=false` | `MatchType.RANKED`, `practice=false` |
| opt-out | none | `Player.ranked_allow_bots` |

The ladder wait is deliberately **not** the player's `bot_queue_delay`: that setting is a
convenience for the casual queue, and letting it shorten the path to a ladder opponent would be a
tuning knob on rating gain.

The fallback is armed on **every** ladder enqueue, not just an `else` ("nobody waiting") branch.
Pairing is gated on distance, so "someone is here but we are not eligible yet" is a normal state —
under the old if/else that player got neither a pair nor a fallback, i.e. stranded forever. The
coroutine is generation- and `_in_live_match`-guarded, so an extra arm is a no-op.

> [!warning] Trap
> An awaited `SceneTreeTimer` **cannot be cancelled**. Cancel-then-requeue left the first coroutine
> alive and it would seat a bot early, silently shortening the "fixed 20s" promise. Fixed with a
> per-peer generation counter `_ranked_fallback_gen`, bumped on arm and inside `_release_queues`;
> the coroutine compares its stamp after waking (`:2303-2307`).

### `ranked_allow_bots`

`Player.ranked_allow_bots` (`scripts/player_component.gd:54`, default `true`, persisted, absent on
old saves → `true`) is a settings toggle, "Allow bots in Ladder queue". When false the fallback
**returns and leaves the player queued** rather than seating a bot:

```gdscript
if not rp.ranked_allow_bots:
	print("[QUEUE] ", rp.username, " — ranked bots opted out, staying in queue")
	return
```

`GATE_BANDS` still govern who they may be paired with, and every band resolves eventually (the
widest is 3× `RANKED_BOT_DELAY` = 60s), so opting out is exactly the trade the setting describes: a
longer wait in exchange for a human opponent who may be far above or far below them.

## Dequeue is one primitive

`_release_queues(peer_id)` (`:2362`) is the **single** dequeue path — enqueue, cancel, disconnect,
seat, and the maintenance stand-down all call it. It clears `queued_players`, drains
`ranked_queue` (`_erase_from_ranked_queue` returns after the first hit, so one call cannot clear
duplicates — hence the `while` loop), erases `private_queue` **by key** (erase-by-value on a
username-keyed dict was a permanent no-op, so invites never cancelled), drops `_ranked_wait_start`,
and bumps the fallback generation.

`_erase_from_ranked_queue` scans **every** rank/tier bucket rather than trusting the player's
current rank — a rating change between queueing and dequeuing would otherwise strand the entry
forever. `_find_ranked_entry` returns the **actual** array, not a copy: `start_ranked_match` cleans
up with `Array.erase()`, which is value equality, so handing it a copy would silently no-op and
leave the just-seated player pairable on the next sweep.

> [!info] Quick is deliberately ungated
> It no longer touches rating at all, it is the casual mode where a long wait is worse than an
> imperfect match, and its bot fallback uses each player's own `bot_queue_delay` — so "gate longer
> than the bot timer" is not even well-defined there.

Dead space worth recognising: the ranked buckets are pre-initialised for tiers 1..5 at boot
(`:308-310`) but tier 5 is permanently empty now that divisions are 1..4. It is unused width in
`get_new_rank_search`'s widening, not a bug. `find_nearest_ranked_player` is likewise still defined
but no longer on the enqueue path — the sweep replaced it.

## Post-game: the `ranked_result` frame

`Rating.add_win/add_loss` mutate the rating **in place**, and `rank`/`rank_tier` are derived getters
over it, so the "before" half is gone the instant `handle_server_match_ended` calls them.
`_rank_snapshot(p)` (`:3346`) is therefore taken *between* the RANKED gate and the mutation, and
`_send_ranked_result` (`:3358`) emits one frame per human player carrying **both** rating endpoints,
**both** division endpoints, and `promoted` / `demoted` / `rank_changed`.

The client derives nothing from it. The old approach cached `S.ratingBefore` at queue time, which
was lost on any reconnect or page reload; carrying both endpoints on the wire survives both.

Promotion is one comparison because `rank * Rank.DIVISIONS + tier` is monotonic up the ladder.
**Division 1 is the worst inside a rank, 4 the best** — Iron 1 is the bottom of the ladder.

> [!danger] Never gate behaviour on a display label
> The ladder match kind string shown to players is **"Ladder Match"**, not "Ranked". Every
> `/ranked/i.test(S.match.kind)` gate in the client was therefore permanently false, and three
> features were dead because of it: the post-game Rating row never rendered, `matchApGain` returned
> null for ladder games (the AP row sat on "…"), and the client-side rating delta was never
> computed. Ranked-ness is now a **flag**, `S.match.ranked`, behind `isRankedMatch()`. The wire
> identifiers (`MatchType.RANKED` ordinal 3, the `queue_ranked` / `receive_ranked_match` message
> types, save keys `ranked_streak` / `rp`) were deliberately **not** renamed — they are the
> protocol and the save format.

`ranked_result` can arrive **before** the MATCH_ENDED event that creates `S.matchResult`, so the
client stashes it in its own `S.rankedResult` (cleared on match start and on `returnToMenu`) rather
than merging it into `matchResult`.

## The AFK clock

Not matchmaking, but it decides real ladder losses, so it belongs in the same mental model.
`components/match.gd`, keyed by peer id, per-**match**, server-authoritative.

- Normal turn timer `Match.default_match_timer = 120.0`.
- Each turn a player lets time out subtracts `AFK_PENALTY_STEP = 30.0`:
  `maxf(AFK_MIN_TIMER = 30, default - 30 * misses)`. So a repeat AFKer gets 120 → 90 → 60 → 30.
  Finishing a turn manually resets it (`apply_input` erases `afk_misses[peer]`).
- Missing `AFK_FORFEIT_MISSES = 3` turns **in a row** auto-forfeits: that player *loses* — W/L and
  AP are recorded, it is not an abort.
- The streak carries across old→new peer id in `check_in_player`, so it cannot be shed by
  reconnecting.
- Bots never time out. Humans in bot matches do.

The client bar is cosmetic; the server `$Timer` is authoritative. The current turn's duration ships
as `snapshot.turn_timer` and `app.js` adds a `.timer-bar.penalty` class when it is under 120000ms.

Related: [[The Turn Pipeline]], [[Bots and Training]], [[Admin and Live Ops]],
[[Season Reset and Maintenance]], [[Traps That Have Bitten Us]], [[Anime Arena]].
