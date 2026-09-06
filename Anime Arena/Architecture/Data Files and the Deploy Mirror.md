---
tags: [area/architecture, type/howto]
---

# Data Files and the Deploy Mirror

Most of the game's content is not in code — it is in JSON, and it exists **twice**: once as the
server's source of truth and once as a static client manifest. Nothing syncs the two automatically.
This is the number one source of "I changed it and nothing happened".

> [!danger] Editing an ability's `.gd` does NOT change what players see
> `describe()` and `split_desc()` are read by *extractor scripts*, not by the client. The client
> fetches pre-baked JSON. A wording change needs a regen + a copy. Recipe below and in
> [[Changing Ability Text]].

## The three trees

```
<repo root>/                 server source of truth  — abilities_data.json, assets/, scripts/, character/
webclient/app/               client source of truth  — the files you EDIT
deploy/                      the built bundle        — what Cloudflare Pages serves
```

`deploy/` is assembled by `build-pages-deploy.ps1`, which **wipes and rebuilds** the directory:

```powershell
if (Test-Path $out) { Remove-Item -Recurse -Force $out }        # clean rebuild
$skip = @("tests.html", "aa-tests.js", "aa-test-harness.js", "roster.json.bak")
Get-ChildItem -File $app | Where-Object { $skip -notcontains $_.Name } |
    ForEach-Object { Copy-Item $_.FullName -Destination $out }   # app files at the ROOT
foreach ($d in @("images", "avatars", "backgrounds", "bounty", "cosmetics", "videos", "sounds")) {
    Copy-Item (Join-Path $root "assets\$d") -Destination (Join-Path $assetsOut $d) -Recurse
}
```

Two consequences worth internalising:

1. **Never hand-edit `deploy/`** as the primary edit. The next build erases it. Edit
   `webclient/app/` and rebuild — or, for a one-file iteration, edit the app tree and `cp` across so
   the two stay identical (verify with a `diff`).
2. **The asset directory list is hardcoded.** Only `images, avatars, backgrounds, bounty, cosmetics,
   videos, sounds` are mirrored. `assets/ui/` — which holds the rank badge art at
   `assets/ui/badges/<rank> small.png`, resolved by the client through `resToUrl("res://assets/ui/…")`
   — is **not** in that list. A new asset directory needs an explicit entry, or the client's URLs
   404 in production while working perfectly in local dev (where the static server is rooted at the
   repo).

`deploy.ps1` is the one-shot: build the bundle → `wrangler pages deploy deploy` → `scp` the exported
`web_anime_server.x86_64` to the GCP box → `chmod +x`. It does **not** build the server binary; you
export that from Godot yourself, and the script prints the binary's age so you can catch a stale one.
`-SkipServer` / `-SkipFrontend` split the two halves.

## What the client actually fetches

Ten manifests, all from `app.js` (search `fetch(`):

| File | Shape | Feeds |
|---|---|---|
| `roster.json` | `[{path_name, name, universe, gate, colors, bio}]` | char-select grid, names, unlock gates |
| `char_index.json` | `{path: {default, name}}` | name + portrait fallback for **non-playable** concepts |
| `portraits.json` | `{path: {default, alts[]}}` | battle portraits + alt forms |
| `ability_info.json` | `{basename: {name, description, classes, cooldown, cost, desc}}` | **the only ability file the client reads** |
| `ability_split.json` | `{basename: [{text, color?}]}` | build intermediate — merged into `ability_info` |
| `ability_icons.json` | `{basename: "Folder/file.png"}` | ability icons |
| `ability_aliases.json` | `{script_basename: json_key}` | abilities whose script name ≠ manifest key |
| `titles.json` | `{lesser: {path:[words]}, greater: {path:[words]}}` | the Titles composer |
| `bounty_data.json` | `{categories, winning_patterns, archetypes, starters}` | the Bounties panel |
| `shop_catalog.json` | `{items, display_names, order}` | the Shop |
| `campaign_chapters/dialogue/encounters.json` | — | campaign map + VN (lazily, on entering campaign) |

> [!warning] `ability_split.json` and `abilities_data.json` are NOT read by the client
> `ability_split.json` is a build intermediate that gets merged into `ability_info.json` (it *is*
> mirrored to `deploy/`, but only for parity). `abilities_data.json` is server-side and is never
> deployed at all. If you patched a description in `abilities_data.json` and the client didn't
> change, that's why.

Inside `ability_info.json`, the client shows the **`desc`** field (the coloured segment array) and
only falls back to the prose `description` when `desc` is empty. Every real ability has a `desc`, so
`description` is effectively never displayed — it only feeds the char-select search-text blob. A
pure wording rebuild therefore only needs to touch `desc`.

## The generators

| Script | Run | Writes |
|---|---|---|
| `extract_split_desc.gd` | `godot --headless --path . --script res://extract_split_desc.gd` | `webclient/app/ability_split.json` |
| `extract_ability_info.gd` | same pattern | `webclient/app/ability_info.json` (merge of `abilities_data.json` + `ability_split.json`) |
| `extract_bounty_data.gd` | same pattern | `webclient/app/bounty_data.json` |
| `extract_char_index.gd` | same pattern | `webclient/app/char_index.json` |

`extract_split_desc.gd` calls `Ability.from_database(b).split_desc()` for every ability, so it picks
up the current `.gd`. It prints benign `SCRIPT ERROR`s for incomplete data entries (missing `ash*.gd`
etc.) and still completes.

> [!tip] Use `split_desc()`, not `describe()`, for batch regeneration
> `describe(user)` no-ops (returns empty) for the ~227 abilities that dereference `user`.
> `split_desc()` is parameterless and regenerates 100%.

> [!warning] A full regen surfaces pre-existing drift
> Some abilities' `split_desc()` was edited without re-extracting, so a fresh regen changes entries
> you never touched. Diff the regenerated split against the `desc` already embedded in
> `ability_info.json` and **revert the unrelated entries** to keep the change scoped.

## Changing one ability's description

1. Edit the `.gd`'s `describe()` + `split_desc()`.
2. Text-replace that ability's `description` in `abilities_data.json` (server-side; feeds
   `ability_info`, and is a *stale cache* of `describe()` that nothing auto-updates).
3. Regenerate `ability_split.json`.
4. Patch the changed entries in `ability_info.json`: set `description` and `desc`. Write minified.
5. `cp` `ability_info.json` + `ability_split.json` to `deploy/`.

Full walkthrough: [[Changing Ability Text]].

## Cost and cooldown are data, not code

There is no per-ability `.tscn`. `Ability.from_database` reads cost and cooldown out of
`abilities_data.json` at runtime. So a balance change is: edit `abilities_data.json` (server) + the
same fields in `ability_info.json` (client display) + copy to `deploy/`.

A `.gd` `cost()` override (e.g. Mine's HP-scaled cost) takes precedence at runtime, but the static
value is still what the client displays.

Cost dict keys are `Energy.Type` ordinals: **0 GREEN · 1 BLUE · 2 WHITE · 3 RED · 4 RANDOM**
(`scripts/types/energy.gd`). Target types: **0 SINGLE · 1 ALL_FACTION · 2 ALL · 3 COUNT · 4 SELF**.

## Formatting traps

> [!danger] `abilities_data.json` will not survive a `json.load` → `json.dump` round-trip
> It uses **mixed indentation** — 2 spaces at the top level, a hard tab inside each ability object:
> ```json
> {
>   "astolfo1": {
> 	"script_path": "res://abilities/astolfo1.gd",
> 	"target_type": 0,
> ```
> A load/dump round-trip normalizes indentation (and line endings) across the whole 26k-line file and
> produces an unreviewable diff. Edit the **raw text** instead: global-replace each unique
> `description` string, and for non-unique values (`"cooldown": 2`, a cost `"4": 1`) scope the replace
> to that ability's `{ … }` block by finding `"<key>": {` and brace-matching to its close. Check the
> file's current line endings before writing (`open(..., newline='')` preserves whatever is there).

`ability_info.json` by contrast **is** safe to load/dump — write it minified:
`separators=(',',':')`, `ensure_ascii=False`, `newline=''`, single line.

Other per-file conventions:

| File | Format |
|---|---|
| `roster.json` | `indent=0` — one key per line, 1818 lines |
| `titles.json` | `indent=2`, `ensure_ascii=False`, **no trailing newline** |
| `char_index.json` | single line, no indent, `ensure_ascii=False` |
| `ability_info.json`, `ability_split.json` | single line, minified |

Getting these wrong doesn't break anything functionally — it makes the diff useless, which is worse
in a repo full of uncommitted work.

## Effect tooltips are a DIFFERENT, live path

An `Effect`'s `description` (a String, or a `func(eff) -> String`) is baked **per snapshot** on the
server in `_serialize_wire_effect` (`new multiplayer/battle_manager.gd:2412`) —
`description_text = effect.description.call(effect)` — and shipped on the wire.

So changing an effect's tooltip wording means editing **only the `.gd`**. It goes live on the next
server redeploy: no JSON regen, no `cp`. This is the opposite of ability descriptions, and mixing the
two models up wastes a lot of time.

Related client-side detail: `effectClusters` in `app.js` groups a character's wire effects into
tooltip panels keyed by **`effect_name + "@" + unique_render_id`** — *not* by the wire `id`. Two
effects sharing an `effect_name` collapse into one panel unless you give one a non-zero
`unique_render_id`. `display_mag: true` renders `effect.mag` as a number; `display_stacks: true`
renders `stack_count`. `system: true` effects are dropped from the wire entirely. See
[[Effects and Durations]].

## Registration files a new character touches

Server side:

- `abilities_data.json` — one row per ability
- `character_ability_counts.json` — `"<path>": N`, where N includes the passive slot **and** any
  hidden swap-in
- `scripts/character_database.gd` `char_name_list()` — server-side team validation

Client side, in **both** `webclient/app/` and `deploy/`:

- `roster.json`, `portraits.json`, `char_index.json`, `ability_info.json`, `ability_split.json`,
  `ability_icons.json`, `titles.json`

> [!warning] `CHAR_SELECT_ORDER` is a hardcoded array in `app.js` — easy to miss
> `gridArea()` filters `S.roster` by `CHAR_SELECT_SET` and sorts by `CHAR_SELECT_RANK`
> (`app.js:83-104`). A character present in `roster.json` but absent from this array shows up in the
> Mastery panel and is **invisible in char-select**. Both this array and `char_name_list()` are
> grouped by universe (starter-squad leaders first, then contiguous per-universe blocks) — append a
> new character at the end of *their own universe's block*, not the end of the list. Reordering
> `char_name_list` is safe: its consumers are membership pools only, nothing persists an index.

Full checklist with the engine gotchas: [[Adding a Playable Character]].

> [!info] `roster.json` vs `char_index.json`
> `roster.json` is the **playable** subset and feeds char-select — a non-playable Nexus concept must
> never appear there. `char_index.json` is only ever keyed (`charIndex[path]`), never iterated, so it
> can't leak into any grid; that's where concept name + portrait go. See
> [[Adding Nexus Concepts]] and [[The Nexus]].

## Art

`assets/images/<Display Name>/<path>prof.png` for portraits and `<path><N>.png` for ability icons —
the folder is the **display** name, the file uses the **path** name. Mirror to
`deploy/assets/images/<Display Name>/`, then run `godot --headless --import` so the server can
`load()` the texture.

> [!danger] The art must be a real PNG, not a renamed WebP
> Godot's importer decodes `.png` as PNG, chokes on WebP bytes, and leaves the `.import` at
> `valid=false` with no `[remap] path=`. The server's `load(image_path)` then throws
> `No loader found for resource:`. The symptom is deceptive: the **browser renders WebP-as-`.png`
> fine**, so ability icons look correct, while every *effect tooltip* (which pulls the ability's
> server-side image) shows a blank dark-grey square. Check the magic bytes (`\x89PNG`), re-encode if
> needed, delete the bad `.png.import` and `.godot/imported/<name>.ctex`, then `--import` again.

Related: [[System Overview]], [[Web Client Architecture]], [[Changing Ability Text]],
[[Adding a Playable Character]], [[Adding Nexus Concepts]], [[Verification Playbook]],
[[Season Reset and Maintenance]].
