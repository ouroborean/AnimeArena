---
tags: [area/playbook, type/howto]
---

# Changing Ability Text

> [!danger] Editing `describe()` or `split_desc()` does NOT change what the client shows
> The `.gd` is the *source*, but the web client never reads it. It fetches a static JSON file that
> was generated at some point in the past. Change only the script and the player sees the old text
> forever — and it will look correct to you in code review.

The player-facing description lives in **three** places, none of which is auto-synced:

```
abilities/<key>.gd            describe() prose + split_desc() segments   <- source of truth
        │
        ├── abilities_data.json          "description"  (a STALE cached copy of describe())
        │
        ├── webclient/app/ability_split.json   {key: [{text,color?}]}    <- build intermediate
        │
        └── webclient/app/ability_info.json    the ONLY file the client fetches
                    └── mirrored to deploy/ability_info.json
```

---

## What the client actually reads

`webclient/app/app.js:1240`:

```js
fetch("ability_info.json" + DATA_BUST).then((r) => r.json()).then((m) => set({ abilityInfo: m }));
```

`ability_split.json` and `abilities_data.json` are **never fetched by the browser** — the former is a
build intermediate, the latter is server-side only and is not even copied into `deploy/`.

An `ability_info.json` entry:

```json
"stark1": {
  "name": "...",
  "description": "prose fallback + char-select search text",
  "classes": ["Physical","Instant","Helpful","Strategic"],
  "cooldown": 1,
  "cost": {"0":0,"1":0,"2":0,"3":0,"4":1},
  "desc": [
    {"color":"#5f9ea0","text":"For 1 turn, Harmful skills used on target ally are redirected onto Stark"},
    {"color":"#90ee90","text":"Stark is Immortal for that turn"},
    {"color":"#7fffd4","text":"Each skill redirected this way resets Tumble's cooldown"}
  ]
}
```

> [!info] `desc` is what players see; `description` almost never is
> The client renders the `desc` segments and only falls back to the `description` prose when `desc`
> is empty. Every real ability has a `desc`, so `description` effectively only feeds the char-select
> **search-text blob**. A pure wording rebuild therefore only strictly needs `desc` — but keep the two
> consistent so search still finds the skill by its new wording.

---

## The procedure

### 1. Edit the `.gd`

Change **both** `describe()` and `split_desc()`. `split_desc()` returns a list of either bare strings
(default colour) or `[text, Color]` pairs:

```gdscript
func describe(user):
	return "Deals 45 Piercing damage to target enemy."

func split_desc():
	return [
		"Deals 45 Piercing damage to target enemy",
		["If Mana Control is active, instead deals 20 per energy left in Fern's pool", Color.CADET_BLUE],
		["That energy is all consumed", Color.DIM_GRAY],
	]
```

### 2. Update `description` in `abilities_data.json`

This is the server-side cache that `extract_ability_info.gd` copies forward. **Skip this and the new
prose never reaches the client's search blob.**

> [!danger] Never `json.load` / `json.dump` this file
> `abilities_data.json` is ~600 KB of hand-maintained JSON with **organic mixed indentation** (mostly
> tabs, some two-space lines). A round-trip through any JSON writer reformats all ~26,000 lines. Edit
> the **raw text**:
> - For a `description`, the string is unique — a straight global replace is safe.
> - For a non-unique value (`"cooldown": 2`, a cost entry `"4": 1`) you must scope the replace to the
>   ability's own block: find `"<key>": {` and brace-match forward to its close.
> - Open with `newline=''` so whatever line endings the file has are preserved verbatim.

### 3. Regenerate `ability_split.json`

```bash
godot --headless --path . --script res://extract_split_desc.gd
```

`extract_split_desc.gd` walks every key in `abilities_data.json`, builds the ability via
`Ability.from_database(key)` and calls `split_desc()` — so it picks up your live `.gd`. It writes
`{key: [{text, color?}]}` with colours as `"#" + Color.to_html(false)`.

It deliberately **skips** two classes of row rather than dying on them:

- incomplete/template entries missing `script_path`/`name`/`cooldown`/`target_type`/`image_path`/`classes`;
- keys whose `script_path` no longer resolves (`ResourceLoader.exists` is false) — about 42 entries
  (`ash*`, `atomeve*`, `invincible*`, …). `load(path).new()` on a dangling path returns null and would
  hard-abort the whole extract.

So a run that prints `skipped N` is normal. It still writes the file.

> [!warning] A full regen can surface PRE-EXISTING drift
> Other abilities whose `split_desc()` was edited without re-extracting will also change. Diff the
> regenerated split against the `desc` already embedded in `ability_info.json` and **revert unrelated
> entries** to keep your change scoped.

### 4. Rebuild `ability_info.json`

```bash
godot --headless --path . --script res://extract_ability_info.gd
```

This is the merge step. Per `extract_ability_info.gd`:

| Field | Source |
|---|---|
| `name`, `classes`, `cooldown`, `cost`, `important` | `abilities_data.json` |
| `desc` | `ability_split.json` |
| `description` | `abilities_data.json` when non-empty, else the **current** `ability_info.json` value |

Two deliberate behaviours worth knowing:

- **description precedence protects good client text.** Some entries (e.g. `death1`) carry a usable
  description in the client file while the server DB has none; a naive rebuild would blank them.
- **The export is additive, not pruning.** Any entry the completeness gate rejected but that the
  previous file had (~45 unimplemented design-doc abilities: `gaia_*`, `hymn_*`, `saya_*`, …) is
  carried forward. The run prints `rebuilt N, carried M, skipped K`.

Cost keys are stringified on the way out (`cost[str(k)]`), matching the shape the client expects.
Cost-less skills (passives, free skills) have no `cost` row in the DB and the key is omitted entirely
rather than emitted as `{}`.

If you hand-patch `ability_info.json` instead of running the extractor, write it **minified** to match
the existing file: `separators=(',',':')`, `ensure_ascii=False`, `newline=''`. Unlike
`abilities_data.json`, this file **is** safe to `json.load`/`dump`.

### 5. Mirror to `deploy/`

```bash
cp webclient/app/ability_info.json webclient/app/ability_split.json deploy/
```

`ability_split.json` is not fetched by the browser, but it lives in `webclient/app/` so
`build-pages-deploy.ps1` copies it anyway — keep them in parity so a full bundle rebuild does not
produce a surprise diff. `abilities_data.json` is **not** deployed. See
[[Data Files and the Deploy Mirror]].

---

## The one-command version

```bash
# after editing the .gd and abilities_data.json's description
godot --headless --path . --script res://extract_split_desc.gd
godot --headless --path . --script res://extract_ability_info.gd
cp webclient/app/ability_info.json webclient/app/ability_split.json deploy/
```

Then hard-refresh the client and confirm the tooltip. `DATA_BUST` on the fetch URL handles cache, but
the deploy itself has to land first.

---

## Balance changes: cost and cooldown are the SAME pipeline

Abilities have **no per-ability `.tscn`**. `Ability.from_database`
(`abilities/scripts/ability_component.gd:120`) reads cost and cooldown out of `abilities_data.json`
at runtime, every time a moveset is built:

```gdscript
ability._cost = cost
ability.cooldown = ability_info.get('cooldown', 0)
```

So a balance change is:

1. `abilities_data.json` — the server value (raw-text edit, brace-scoped).
2. `ability_info.json` — the same `cooldown` / `cost` fields, or just re-run
   `extract_ability_info.gd`.
3. `cp` to `deploy/`.

Cost dict keys are `Energy.Type` ordinals (`scripts/types/energy.gd`): **0=GREEN, 1=BLUE, 2=WHITE,
3=RED, 4=RANDOM**.

> [!info] A `.gd` `cost()` override wins at runtime
> Some abilities compute cost dynamically (e.g. `abilities/mine1.gd`'s HP-scaled cost). The static
> `abilities_data.json` cost is still the base and the displayed value, so both must be maintained.

See [[Cooldowns and Energy]] for what those numbers do once loaded.

---

## Effect tooltips are a DIFFERENT, live path

> [!tip] Changing an effect's tooltip needs no JSON at all
> An `Effect`'s `description` (a String, or a `func(eff) -> String`) is baked **server-side per
> snapshot** in `new multiplayer/battle_manager.gd:2412` `_serialize_wire_effect`
> (`description_text = effect.description.call(effect)`) and sent on the wire. So rewording an effect
> tooltip means editing **only** the `.gd` — no extract, no `cp`, no cache. It goes live on the next
> host redeploy.

That asymmetry is the single most confusing thing about ability text: *ability* descriptions are
baked into a client JSON; *effect* descriptions are computed live per turn. See
[[Effects and Durations]].

### The clustering contract (why two effects share one tooltip panel)

`effectClusters` (`webclient/app/app.js:3153`) groups a character's wire effects into panels keyed by
`e.name + "@" + e.unique_render_id` (line 3177) — *not* by the wire `id`. Two effects with the same
`effect_name` therefore collapse into a single panel unless you give one a non-zero
`unique_render_id` (default 0).

| Field | Effect on rendering |
|---|---|
| `unique_render_id` | non-zero splits a same-named effect into its own panel |
| `display_mag = true` | panel renders `effect.mag` as a number |
| `display_stacks = true` | panel renders `stack_count` instead |
| `system = true` | effect is dropped from the wire entirely (invisible to both players) |

`unique_render_id` does **not** affect `effect_storage.add_effect` dedup (which keys on
name + type + user), so splitting the render never disturbs same-name coexistence invariants. This is
how Tsubasa's permanent damage-reduction and its per-use variant became two visible panels instead of
one hiding the other.

---

## Checklist

- [ ] `describe()` **and** `split_desc()` updated in the `.gd`
- [ ] `abilities_data.json` `description` replaced — **raw text**, no JSON round-trip
- [ ] `extract_split_desc.gd` run; unrelated drift in the diff reverted
- [ ] `extract_ability_info.gd` run (or `desc` + `description` hand-patched, minified)
- [ ] `cp ability_info.json ability_split.json deploy/`
- [ ] Browser hard-refresh: the new segments render, colours intact, char-select search finds the
      skill by its new wording
- [ ] For a cost/cooldown change: both `abilities_data.json` and `ability_info.json` updated

---

## Related

[[Adding a Playable Character]] · [[Data Files and the Deploy Mirror]] · [[Web Client Architecture]] ·
[[Cooldowns and Energy]] · [[Effects and Durations]] · [[Verification Playbook]] ·
[[Traps That Have Bitten Us]] · [[Anime Arena]]
