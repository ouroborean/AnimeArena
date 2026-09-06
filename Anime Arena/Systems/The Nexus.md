---
tags: [area/systems, type/reference]
---

# The Nexus

A community poll: every candidate character has a shared **bucket**, players pour their AP into the
buckets they want built next, and the standings decide what gets made. Rounds close periodically —
the winners are removed from the running and everyone else's AP is halved.

> [!danger] The Nexus is NOT the playable roster
> This is the single most important thing to understand before touching it. The Nexus deliberately
> contains hundreds of **non-playable concept characters** who have no ability kit, no
> `character/*.gd`, and no `abilities_data.json` entry. Adding a Nexus concept must never touch
> `roster.json` — a roster entry would expose an unimplemented character in char-select. See
> [[Adding Nexus Concepts]] for the checklist.

## Where the pieces live

| Piece | File | Role |
|---|---|---|
| Concept registry | `components/bucket_handler.gd` `all_chars` | ~650 `CharacterConcept.create(...)` rows |
| Universe enum | `components/character_concept.gd` | `Universe` — **append-only** |
| Live buckets | `bucket_handler.all_buckets[universe][path_name]` | `CharacterBucket` per concept |
| Persistence | `bucket data/<path_name>.dat` | one integer, the bucket's AP |
| Removals | `bucket data/removed_list.dat` | one path_name per line |
| Poll switch | `bucket data/poll.dat` | single int `0`/`1` |
| Wire handlers | `components/server_connection.gd` (`nexus_state`, `donate`, `admin_*`) | |
| Client UI | `webclient/app/app.js` `nexusMenu()` etc. (≈ L5708–5830) | |
| Names / portraits | `webclient/app/char_index.json` | keyed lookup, never iterated |

## The wire

Three messages carry the whole feature.

```json
// S->C, on request and broadcast after any admin mutation
{"type":"nexus_state","max":123456,"sets":[["kirito",4200,"SWORD_ART_ONLINE"], ...],"poll_open":true}

// C->S
{"type":"donate","path_name":"kirito","amount":500}

// S->C, the donation ack
{"type":"update_buckets","path_name":"kirito","amount":4700,"current_max":123456}
```

`get_all_bucket_sets()` (`bucket_handler.gd`) builds the triples:

```gdscript
var uni_names = CharacterConcept.Universe.keys()
for bucket in get_bucket_list():
    sets.append([bucket.character_concept.path_name, bucket.ap, uni_names[int(bucket.character_concept.universe)]])
```

That `uni_names[int(...)]` is why the enum is append-only — see the warning below.

The `sets` payload carries **only** `[path_name, ap, universe]`. The 4th argument to
`CharacterConcept.create` (`desc`) is never sent anywhere; it is cosmetic/legacy and most rows just
pass `"t"`.

## Donations are server-validated

Unlike the retired Godot-RPC path (which never debited AP at all), the JSON handler
(`server_connection.gd:824`) validates and debits server-side:

```gdscript
if dp == null or damount <= 0 or not bucket_handler.has_character_bucket(dpath):
    ... "bad donate"
elif not _poll_open():
    ... "nexus closed"
elif dp.ap < damount:
    ... "insufficient AP"
else:
    dp.contribute_ap(damount)   # ap -= amount
    resave_player(dp)
    var upd = bucket_handler.process_bucket_update(dpath, damount)
    send_player_update(logical_peer)      # authoritative AP back to the browser
```

`int(msg.get("amount", 0))` coerces the JSON float. The client is optimistic (`doDonate`,
`app.js:5816` decrements `S.player.ap` and bumps the bucket immediately) and then gets reconciled by
`receive_player_update` + `update_buckets`.

`_poll_open()` (`server_connection.gd:3698`) reads `bucket data/poll.dat` and **defaults to open**
when the file is absent or unreadable.

## Exclusion: two separate mechanisms

```gdscript
const PERMANENT_EXCLUDED := ["muichiro", "shirou", "muzan", "subaru", "law",
                             "frieza", "yoruichi", "fern", "stark"]

func _is_removed(path_name) -> bool:
    return path_name in PERMANENT_EXCLUDED or removed_set.has(path_name)
```

- **`PERMANENT_EXCLUDED`** — characters *confirmed for the playable roster*. The Nexus is a poll for
  what to build next, so once someone is greenlit there is nothing left to vote on. Every name on
  that list is now a real playable character.
- **`removed_set`** — loaded at boot from `bucket data/removed_list.dat`, populated by the admin
  round-close.

> [!warning] Excluded concepts stay in `all_chars` on purpose
> Deleting the row would strand any existing donation record or `removed_list` line rather than
> retiring the candidate — `all_chars[path]` is what resolves those back into a concept.
> `_is_removed` is checked in **three** places and they must all agree: `get_bucket_list`,
> `has_character_bucket` (which is what rejects a donation) and `initialize_buckets` (skip, so
> removals survive a restart).

When you promote a Nexus concept to a playable character, add their `path_name` to
`PERMANENT_EXCLUDED` — otherwise players keep pouring AP into a character that already exists. This
is a step in [[Adding a Playable Character]].

## The Universe enum is append-only

```gdscript
enum Universe {
    NARUTO, BLEACH, ONE_PIECE, ...,
    # Player-authored characters (block editor).
    CUSTOM,
    # APPEND-ONLY. Saved data stores universes as ORDINALS, so a new entry goes at the very END even
    # when that puts it out of thematic order - inserting above CUSTOM would renumber it and
    # repoint every authored character's stored universe.
    SWORD_ART_ONLINE
}
```

`SWORD_ART_ONLINE` sitting after `CUSTOM` looks like a mistake and is not. Persisted data (and the
authored-character store) holds universes as **integers**. Inserting `SWORD_ART_ONLINE` in a tidy
alphabetical slot would shift `CUSTOM` and every value after it, silently repointing stored records
at the wrong universe.

> [!warning] Trap: `initialize_buckets` has its own universe list
> `all_buckets` is seeded from a hand-written dict in `initialize_buckets()` that enumerates
> universes one by one. It is currently **missing `CHIVALRY_OF_A_FAILED_KNIGHT` and `CUSTOM`**. No
> `all_chars` row uses either, so nothing breaks today — but add a concept in a universe that is in
> the enum and not in that dict and boot dies on
> `all_buckets[concept.universe][concept.path_name] = …` (invalid key access on a missing
> dictionary). Adding a universe means editing the enum **and** the `initialize_buckets` dict.

> [!warning] Trap: no trailing comma on the last row
> Both `all_chars` and the `all_buckets` init dict end their final entry **without** a trailing
> comma. Appending blindly produces `Expected closing "}" after dictionary elements`. Add the comma
> to the previous last line first.

## Client-side universe grouping

The Nexus sidebar is built from `NEXUS_UNIVERSE_KEYS` (`app.js:5731`), a hand-maintained mirror of
the Godot enum — deliberately **not** from `roster.json`, whose display names drift from the enum
keys and used to produce dead buttons like "Fate/stay night".

Drift safety is built in, and it is doing real work today:

```js
const byKey = {};
NEXUS_UNIVERSE_KEYS.forEach((k) => { const u = prettyUniverse(k); byKey[uniKey(u)] = u; });
Object.values(S.nexusBucketUni || {}).forEach((u) => { if (u && !byKey[uniKey(u)]) byKey[uniKey(u)] = u; });
delete byKey[uniKey("Invincible")];
```

`NEXUS_UNIVERSE_KEYS` does not currently contain `SWORD_ART_ONLINE`, `WONDER_EGG_PRIORITY` or
`CUSTOM`. Those universes still get buttons because line 2 above adds any universe the *server* sent
that the client list doesn't know. `prettyUniverse("SWORD_ART_ONLINE")` → `"Sword Art Online"` with
no client change at all. `INVINCIBLE` is explicitly deleted — intentionally disabled in the Nexus.

Two normalisers make this survivable:

- `prettyUniverse(u)` handles every format seen in the wild: `"Clean Name"`, `"RAW_ENUM"`,
  `"Name (CharacterConcept.Universe.X)"`, `"RAW_ENUM (Clean Name)"`, `"Clean Name (RAW_ENUM)"` —
  it picks the non-enum part and title-cases a bare enum.
- `uniKey(u)` = `u.toLowerCase().replace(/[^a-z0-9]/g, "")`. Comparison is always on this key,
  because the wire universe (`"Hunter X Hunter"`) and the roster display name (`"Hunter x Hunter"`)
  differ by case and punctuation and would otherwise split into two buttons.

`nexusUniverseView(u)` iterates the **buckets** grouped by their wire universe, not `roster.json` —
roster only covers the playable subset and would miss almost every concept. `nameFor`/
`portraitUrlFor` then fall back to `char_index.json`, which is keyed-only (`charIndex[pn]`) and never
iterated, so it structurally cannot leak a concept into any character grid.

## Admin operations

All three are `_is_admin`-gated on the server; the client's admin panel gating is convenience only.

### Close a round — `admin_close_nexus_round {count}`

`close_nexus_round(n)` (`bucket_handler.gd`):

1. Sort `get_bucket_list()` by AP descending, take the top `n`.
2. For each: append to `removed_set`, erase from `all_buckets`, then `_save_removed_list()`.
3. **Halve every remaining bucket** — `bucket.ap = int(bucket.ap / 2)` (integer floor, so relative
   order is preserved) — persisting each and recomputing `current_max`.

Returns `{removed, remaining, current_max}`. The server then broadcasts a fresh `nexus_state` to
everyone and replies `nexus_round_closed` to the admin. Halving is the anti-runaway mechanism: the
field stays catchable without discarding the ordering the community produced.

The client tab (`buildAdminNexusTab`, `app.js:4160`) shows a live top-N preview and uses a
**two-click arm** with a 4s auto-disarm rather than `confirm()` (a native dialog blocks the preview
harness and can be suppressed by the browser).

### Rescale — `admin_scale_nexus_ap {multiplier}`

`scale_all_buckets(mult)` multiplies every active bucket by a float, `round`ed and floored at 0,
persists each, recomputes `current_max`, and broadcasts. A multiplier below 1 divides.

### The raffle wheel — client-only

`openNexusRaffle()` (`app.js:4243`) is the *addition* mechanism, and is the counterpart to
close-round's removal. It draws a canvas pie chart over the **top 10 by AP with slice angle ∝ AP**
(1 AP = 1 ticket), spins with ease-out-cubic, and lands the weighted-picked winner's slice midpoint
exactly under the pointer. It draws **without replacement** ("Spin Again (N left)") so two or three
winners can be pulled in a row.

> [!info] It touches nothing
> The raffle reads live `S.nexusBuckets` and is purely client-side and read-only — no server
> round-trip, no AP mutation, no server change was needed to ship it. The admin just screen-shares
> the tab while players watch. It is unrelated to `close_nexus_round`, which removes rather than
> selects.

## Data files

`bucket data/<path_name>.dat` is a single line containing the integer AP. `get_bucket_data` creates
it at `0` on first boot if absent, so a newly added concept auto-seeds.

> [!tip] Reset a test balance
> If you donate while testing a new concept, zero its `.dat` afterwards — a stray balance would seed
> the next round with a bogus head start.

## Related

- [[Adding Nexus Concepts]] — the four-surface checklist and the failure modes
- [[Adding a Playable Character]] — including the `PERMANENT_EXCLUDED` step when a concept graduates
- [[Admin and Live Ops]] — the admin panel, authority checks, and broadcast patterns
- [[Data Files and the Deploy Mirror]] — why `char_index.json` and the art must be mirrored to `deploy/`
- [[Web Client Architecture]] — `S` state, `set()`/`render()`, and the overlay registration points
