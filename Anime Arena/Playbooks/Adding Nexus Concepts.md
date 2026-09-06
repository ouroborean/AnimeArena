---
tags: [area/playbook, type/howto]
---

# Adding Nexus Concepts

The **Nexus** is a community AP-donation leaderboard — a poll for *which character we build next*. It
is deliberately full of **non-playable concept characters**: a portrait, a name, a universe, and a
bucket players pour AP into. It is **not** the roster. Adding a concept needs no ability kit, no
`.tscn`, no `character_ability_counts.json` entry.

If you actually want a playable character, you are in the wrong note — go to
[[Adding a Playable Character]]. See [[The Nexus]] for how the system works end to end.

---

## The four surfaces, in this order

| # | Surface | File |
|---|---|---|
| 1 | Art | `assets/images/<Display Name>/<key>prof.png` (+ `deploy/`) |
| 2 | Concept row | `components/bucket_handler.gd` — `all_chars` |
| 3 | Universe (only if new) | `components/character_concept.gd` enum + `bucket_handler` `all_buckets` |
| 4 | Client name/portrait | `webclient/app/char_index.json` (+ `deploy/`) |

Order matters: step 2 `load()`s the texture from step 1 at parse time, so a missing PNG is a boot
failure, not a blank portrait.

---

## Phase 0 — Pre-flight the keys

A key collision is a **silent dictionary overwrite**, never an error. Check all five namespaces:

```bash
grep -n '"<key>"' components/bucket_handler.gd scripts/character_database.gd
grep -n '"<key>' abilities_data.json
python -c "import json;print('<key>' in json.load(open('webclient/app/char_index.json')))"
python -c "import json;print([r for r in json.load(open('webclient/app/roster.json')) if r['path_name']=='<key>'])"
```

When 19 concepts were added across Gachiakuta / Sailor Moon / Sword Art Online (2026-07-29), all 19
keys were pre-flighted this way and came back clean.

---

## Phase 1 — Art

```
assets/images/<Display Name>/<key>prof.png
deploy/assets/images/<Display Name>/<key>prof.png
```

The **folder is the DISPLAY name**, the **file is `<key>prof.png`**. This is not a convention you can
bend: `CharacterConcept.create` (`components/character_concept.gd:72`) auto-creates a missing
`res://assets/images/<char_name>` directory from the display name, so a mismatch produces a stray
empty folder and a failed `load()`.

```gdscript
static func create(char_name, path_name, port, desc, univ):
	var char_concept = load("res://components/character_concept.gd").new()
	char_concept.character_name = char_name
	char_concept.path_name = path_name
	if not DirAccess.dir_exists_absolute("res://assets/images/" + char_name):
		DirAccess.make_dir_absolute("res://assets/images/" + char_name)
		print("Directory created for " + char_name)
	...
```

> [!danger] Verify the PNG magic bytes
> A WebP renamed `.png` fails Godot's import — the `.import` stays `valid=false` with no
> `[remap] path=`, so the server-side `load()` throws. The browser renders it fine, which makes the
> failure look like a server-only bug. Check for `\x89PNG`, not `RIFF….WEBP`.

Then:

```bash
godot --headless --import
```

`build-pages-deploy.ps1` mirrors the whole `assets/images` tree, so a full bundle rebuild covers the
deploy copy.

---

## Phase 2 — `components/bucket_handler.gd` → `all_chars`

One row per concept:

```gdscript
"kirito": CharacterConcept.create("Kirito", "kirito", load("res://assets/images/Kirito/kiritoprof.png"), "Kirito", CharacterConcept.Universe.SWORD_ART_ONLINE),
```

The 4th argument is `desc`. It is **never sent to the client** — `nexus_state` ships only
`[path_name, ap, universe]` — so it is cosmetic/legacy. Most older rows just pass `"t"`; the 2026-07-29
batch passed the display name. Either is fine.

> [!warning] Trailing-comma trap
> Both big dictionaries in `bucket_handler.gd` end their **last** entry *without* a trailing comma.
> Appending blindly gives you
> `Expected closing "}" after dictionary elements`. Add the comma to the previous last line first.

---

## Phase 3 — A NEW universe is TWO edits, not one

### 3a. The enum — append only, after `CUSTOM`

`components/character_concept.gd`:

```gdscript
	WONDER_EGG_PRIORITY,
	# Player-authored characters (block editor).
	CUSTOM,
	# APPEND-ONLY. Saved data stores universes as ORDINALS, so a new entry goes at the very END even
	# when that puts it out of thematic order - inserting above CUSTOM would renumber it and
	# repoint every authored character's stored universe.
	SWORD_ART_ONLINE
}
```

`get_all_bucket_sets` sends `uni_names[int(concept.universe)]`
(`components/bucket_handler.gd:792`), and authored characters persist their universe as an ordinal.
Inserting mid-enum shifts every index below it. **Out of thematic order is correct here.**

### 3b. `initialize_buckets()` — the second per-universe dict

`components/bucket_handler.gd:705` builds `all_buckets` as a literal of empty per-universe dicts:

```gdscript
func initialize_buckets():
	all_buckets = {
		CharacterConcept.Universe.NARUTO: {},
		...
		CharacterConcept.Universe.WONDER_EGG_PRIORITY: {},
		CharacterConcept.Universe.SWORD_ART_ONLINE: {}
	}
```

> [!danger] Miss this and boot crashes
> `initialize_buckets` then does `all_buckets[concept.universe][concept.path_name] = …` (line 770).
> A universe with no bucket row throws
> `SCRIPT ERROR: Invalid access to key '<new_index>' on a base object of type 'Dictionary'` the moment
> your new concept is processed. This bit the Ai Ohto / Wonder Egg Priority addition.

Note the two lists are **not** in the same order and are not meant to be — `all_buckets` is keyed, and
a few enum values (`CUSTOM`, `CHIVALRY_OF_A_FAILED_KNIGHT`) have no bucket row at all. That is
harmless until a concept actually uses them.

`get_bucket_list()` skips empty universes, so an unused universe never shows an empty Nexus tab.

### 3c. Client universe buttons

`webclient/app/app.js` `NEXUS_UNIVERSE_KEYS` (~line 5731) is a hand-mirrored copy of the enum and is
the canonical source for the Nexus universe buttons. Buttons are alphabetized by
`prettyUniverse` output, so insertion order does not matter.

```js
const byKey = {};
NEXUS_UNIVERSE_KEYS.forEach((k) => { const u = prettyUniverse(k); byKey[uniKey(u)] = u; });
Object.values(S.nexusBucketUni || {}).forEach((u) => { if (u && !byKey[uniKey(u)]) byKey[uniKey(u)] = u; });
delete byKey[uniKey("Invincible")];
```

> [!info] There IS drift safety, but do not lean on it
> The second line adds any universe the server actually sent a bucket for, so a new universe with
> live buckets renders even if you forget the array (which is why `SWORD_ART_ONLINE` works today
> despite being absent from `NEXUS_UNIVERSE_KEYS`). But a universe with **zero** buckets — or before
> the first `nexus_state` arrives — silently has no button. Add the key.
>
> `INVINCIBLE` is deliberately deleted (that universe is disabled in the Nexus).

`prettyUniverse` turns `SWORD_ART_ONLINE` into "Sword Art Online" with no client change.
`uniKey` collapses punctuation/case so roster display names ("Hunter x Hunter") and enum keys
("HUNTER_X_HUNTER") do not produce duplicate buttons.

---

## Phase 4 — `webclient/app/char_index.json`

```json
{"kirito": {"default": "Kirito/kiritoprof.png", "name": "Kirito"}}
```

Single line, no indent, `ensure_ascii=False`. Mirror to `deploy/`.

> [!warning] Use `char_index.json`, NOT `roster.json`
> `roster.json` is the *playable* subset and feeds char-select — a roster entry would expose a
> non-playable concept there. `char_index` is only ever **keyed** (`charIndex[pn]` via `nameFor` /
> `portraitUrlFor` fallback), never iterated, so it cannot leak into any grid.

There is an extractor that regenerates the whole file from the server's `all_chars`:

```bash
godot --headless --path . --script res://extract_char_index.gd
```

It emits `{path: {name, default}}` for every concept the production server knows, derived from
`concept.portrait_texture.resource_path.trim_prefix("res://assets/images/")` — so a concept whose
texture failed to import comes out with an empty `default`. That is a useful post-import sanity check.

Note the extractor covers only `all_chars`, so **playable-only** characters (who are not in
`all_chars`) still need their `char_index` row written by hand.

---

## Phase 5 — Deploy + boot

```bash
cp webclient/app/char_index.json deploy/
```

Or `.\build-pages-deploy.ps1` for the full bundle. See [[Data Files and the Deploy Mirror]].

On the next server boot, `initialize_buckets()` calls `get_bucket_data(concept)`
(`components/bucket_handler.gd:880`) which **auto-creates** `bucket data/<key>.dat` seeded to `0`.
Nothing to prepare.

> [!tip] Reset a test donation
> If you donate to a new bucket while testing, zero `bucket data/<key>.dat` again — a stray balance
> would seed the new round with a head start.

---

## The wire

```
server -> client:  nexus_state { max, sets: [[path_name, ap, universe_enum_name], ...], poll_open }
```

Nothing else. Name and portrait are resolved client-side from `char_index.json`, which is why that
file is the only client surface a concept needs.

---

## Retiring a concept

Two mechanisms, both in `components/bucket_handler.gd`:

```gdscript
func _is_removed(path_name) -> bool:
	return path_name in PERMANENT_EXCLUDED or removed_set.has(path_name)
```

**`PERMANENT_EXCLUDED`** (line 19) is the greenlit list — characters confirmed for the playable
roster. Once a concept becomes playable, add its key here:

```gdscript
const PERMANENT_EXCLUDED := ["muichiro", "shirou", "muzan", "subaru", "law", "frieza", "yoruichi", "fern", "stark"]
```

> [!warning] Do NOT delete the `all_chars` row when a concept graduates
> The comment at line 15-18 is explicit: the entry is what resolves an existing donation or a
> `removed_list.dat` row, so deleting it strands that history rather than retiring the candidate.

**`removed_set`** is the dynamic list, loaded from `bucket data/removed_list.dat` at boot (so
removals survive restarts) and written by the admin close-round op.

`_is_removed` is checked in three places, and all three matter:

| Call site | Effect |
|---|---|
| `get_bucket_list` (line 779) | never appears in the leaderboard or any universe view |
| `has_character_bucket` (line 795) | **donations are rejected** |
| `initialize_buckets` (line 762) | skipped at boot, so removal survives restart |

---

## Admin operations

### Close a round — `admin_close_nexus_round { count }`

`close_nexus_round(n)` (`components/bucket_handler.gd:922`):

1. Sorts `get_bucket_list()` by AP descending and removes the top `n` — added to `removed_set`,
   persisted via `_save_removed_list()`, erased from `all_buckets`.
2. **Halves every remaining bucket** (`int(bucket.ap / 2)` — floor, so standings *order* is preserved
   but the field is catchable again), persists each, recomputes `current_max`.

Then the server broadcasts a fresh `nexus_state` and replies
`nexus_round_closed {removed, remaining, current_max}`. The admin panel's Nexus tab has a top-N
preview and a two-click-arm "Close Round". See [[Admin and Live Ops]].

### Scale all buckets — `admin_scale_nexus_ap { multiplier }`

`scale_all_buckets(multiplier)` (`components/bucket_handler.gd:949`) multiplies every active bucket,
rounding to nearest integer (a decimal below 1 divides). Mirrors the close-round rescale loop and
excludes removed buckets the same way. Authority is re-checked server-side
(`components/server_connection.gd:915`) — the UI gating is convenience only.

### The raffle wheel — client-only, read-only

The mechanism for deciding *which* concepts get built is a **weighted raffle over the top-10 by AP
(1 AP = 1 ticket)**, run 2-3× per phase. `openNexusRaffle()` (`webclient/app/app.js:4243`, opened by
the "🎡 Open Raffle Wheel" button `buildAdminNexusTab` renders at line 4233) draws a canvas
pie chart with slice angle ∝ AP and spins with ease-out-cubic so the weighted-picked winner's slice
midpoint lands exactly under the pointer. It **draws without replacement** (winner removed from
`remaining`, "Spin Again (N left)").

> [!info] The raffle touches nothing
> It reads live `S.nexusBuckets` and never mutates AP or contacts the server — the admin just
> screen-shares the tab. No server change was needed for it. It is unrelated to `close_nexus_round`,
> which is the AP-halving *removal* op: the raffle picks winners for **addition**.

> [!warning] You cannot make a throwaway admin account to test this
> Registration rejects case-variants of `ADMIN_USERNAMES` (`_collides_with_admin_name` in
> `components/server_connection.gd:415`). Test core logic in-engine, auth rejection over WS, and the
> client UI by forcing `S.isAdmin`.

---

## Checklist

- [ ] Key pre-flighted against `all_chars`, `char_name_list()`, `abilities_data.json` prefixes,
      `char_index.json`, `roster.json`
- [ ] `assets/images/<Display Name>/<key>prof.png` — real PNG, folder = display name
- [ ] `deploy/assets/images/<Display Name>/<key>prof.png`
- [ ] `all_chars` row in `components/bucket_handler.gd` (previous last row got its comma)
- [ ] New universe? enum appended **after `CUSTOM`** in `components/character_concept.gd`
- [ ] New universe? `CharacterConcept.Universe.X: {}` in `initialize_buckets()`
- [ ] New universe? key added to `NEXUS_UNIVERSE_KEYS` in `app.js` (+ `deploy/app.js`)
- [ ] `webclient/app/char_index.json` row (+ `deploy/`)
- [ ] `godot --headless --import`
- [ ] Boot check: no `Invalid access to key` error, `bucket data/<key>.dat` auto-created at `0`
- [ ] Browser: universe tab lists the concept with a portrait and a working donate button

---

## Related

[[The Nexus]] · [[Adding a Playable Character]] · [[Admin and Live Ops]] ·
[[Data Files and the Deploy Mirror]] · [[Web Client Architecture]] · [[Verification Playbook]] ·
[[Anime Arena]]
