---
tags: [area/process, type/reference]
---

# Hard Rules and Guardrails

Absolutes. Each one exists because breaking it destroyed something real. They are not preferences and
they are not weighed against convenience — if a rule below blocks an approach, the approach changes.

## 1. Never run destructive git

> [!danger] Never do this
> `git checkout -- <file>` · `git restore` · `git reset --hard` · `git clean` · `git stash`
>
> The working tree carries a **large amount of uncommitted work** — whole characters, ability edits,
> asset changes — that is not in `HEAD`. Every one of those commands silently reverts files to `HEAD`.

On 2026-07-05, `git checkout -- abilities_data.json` was run to undo a CRLF→LF formatting churn. It
reverted the file to `HEAD` and **discarded 16 uncommitted ability entries** (`adam1-5`,
`impmon1-6`, `toji1-5`) plus prior balance edits. Recovery was only possible by reconstructing from
`ability_info.json` / `ability_icons.json` and earlier dumps. The owner then asked that git be left
alone entirely for the rest of the session.

**Instead:**

- Fix a bad edit by **re-editing the file**, not by reverting it.
- Sync client changes to `deploy/` with targeted `cp`, or a full `build-pages-deploy.ps1` rebuild —
  never via git.
- Read-only git (`git status`, `git log`, `git diff`) is fine. Anything that writes the working tree
  is not.
- If a git write genuinely seems necessary, **ask first**.

## 2. Test accounts are `ZZ_`-prefixed throwaways

> [!danger] Never do this
> Write a real username — and above all an **admin** username — into the live `ausers/` directory
> from a test harness.

`Cheshire` is a hardcoded admin (`ADMIN_USERNAMES = ["Cheshire", "IsaacTheEmperor"]`,
`components/server_connection.gd:336`). On 2026-07-20 a verification harness did `mk("Cheshire")` →
`save_player`, clobbering the real account, and then "cleaned up" with `rm ausers/Cheshire.dat`. The
account was destroyed by a *test*, not by deployed code. It was recoverable only from a stale
`.dat.bak` from three weeks earlier.

**The account-safety protocol:**

| Step | What |
| --- | --- |
| Before | Fingerprint the live `ausers/` (sha256 per file). Move real accounts aside and stage a **synthetic** accounts dir if the op touches accounts at all. |
| During | Every account the harness creates is `ZZ_`-prefixed. A test needing admin rights stubs `_is_admin` or adds a `ZZ_` name to a local admin list — it never borrows a real admin name. |
| After | Restore, re-verify byte equality against the fingerprint, and **delete every account this session created**. |

Two corollaries, both learned the hard way:

- **A registration cannot be made for an admin name anyway** — `_collides_with_admin_name` rejects
  it. So "just register a test admin" is not an option; stub the check.
- **`ausers/` already holds ~54 `zz*` / `ZZ_*` throwaways** from past harnesses. They are expected.
  Do not "clean" them and do not count them as damage — only remove what this session made.

> [!warning] Trap — swapping `ausers/` under a running server is unsafe in *both* directions
> The `players` cache reverts your file edits, and a `resave_player` from a longer-lived in-memory
> `Player` can also write progress the file on disk never had. Observed 2026-07-29: two accounts came
> back with ~12 more matches and different rating than a snapshot taken earlier the same session.
> Stop the server and **confirm no `godot` process survives** before touching `ausers/`. A mid-session
> snapshot is not ground truth — when disk and snapshot disagree, compare wins/losses/AP and mtimes
> and keep the fuller state.

Related: [[Season Reset and Maintenance]], [[Admin and Live Ops]].

## 3. Organic data files are edited raw, never re-dumped

`abilities_data.json` is **CRLF with mixed tab and 2-space indentation**. A `json.load` /
`json.dump` round-trip rewrites the entire file (LF endings, uniform Python indent) and produces a
diff the size of the file — which is exactly how the 2026-07-05 formatting churn began, and therefore
indirectly how 16 abilities were lost.

**The rule:** insert and replace **raw text**, preserving the surrounding style exactly.

```python
# preserve CRLF — do NOT let Python normalize line endings
raw = open("abilities_data.json", newline="").read()
```

- For a **unique** value (a `description` string), a global text replace is safe.
- For a **non-unique** value (`"cooldown": 2`, a cost entry `"4": 1`), scope the replace to the
  ability's own block: find `"<key>": {` and brace-match to its close.

The same applies to every hand-maintained data file, each with its own committed style:

| File | Style |
| --- | --- |
| `abilities_data.json` | CRLF, mixed tab + 2-space indent — raw edits only |
| `roster.json` | `json.dumps(indent=0)` |
| `titles.json` | `json.dumps(indent=2, ensure_ascii=False)`, **no trailing newline** |
| `char_index.json` | single line, no indent, `ensure_ascii=False` |
| `ability_info.json` | minified — `separators=(',',':')`, `ensure_ascii=False`, single line |
| `character_colors.json` | match the existing style exactly |

`ability_info.json` is the one file that *is* safe to load/dump, provided it is written back
minified. Full pipeline in [[Changing Ability Text]] and [[Data Files and the Deploy Mirror]].

> [!warning] Trap — trailing commas in `bucket_handler.gd`
> Both dictionaries in `components/bucket_handler.gd` end their last entry **without** a trailing
> comma. Appending blindly yields `Expected closing "}" after dictionary elements`. Add the comma to
> the old last line.

## 4. New characters default LOCKED

Unless the owner says otherwise, a new playable character starts **locked**:

- `webclient/app/roster.json` (and the `deploy/` copy) gets `"gate": "<path_name>_unlock"` — **not**
  `"always"`. The client's `charUnlocked` returns false unless the player owns `<path>_unlock` or
  `all_unlock`.
- The character is **not** added to `CharacterDatabase.starter_squads()` and **not** added to
  `bounty_data.json` starters — `Character.unlocked(player)` treats a starter as always-unlocked, so
  either would defeat the gate.
- The character script's own `is_unlocked(player)` can stay `return true`; the authoritative gate is
  `unlocked()`, which is not overridden.

This was an explicit correction (Levi, 2026-07-05, shipped freely-available and had to be walked
back) and applies to every character built since. See [[Adding a Playable Character]].

## 5. Playable characters do NOT go in the Nexus bucket handler

The `all_chars` dict in `components/bucket_handler.gd` is the **Nexus** — a community AP-donation
board for characters that are *not yet in the game*, so players can campaign for their addition.
Once a character is playable they do not belong there.

- Correct: `levi`, `toji`, `adam`, `saitama` are absent from `all_chars`.
- Leftovers: `gasai`, `blackwargreymon`, `astolfo` linger only because they were Nexus concepts
  *before* they became playable and were never cleaned up.

> [!warning] Trap — path-name collisions
> `all_chars` still *occupies* path names. `"ai"` was already Ai Mikami (a Nexus-only concept), so Ai
> Ohto had to ship as `aiohto`. **Grep the intended path against `all_chars`, `char_name_list()`,
> `char_index.json`, `roster.json` and the `abilities_data.json` key prefixes before using it** — a
> silent dict overwrite is the failure mode.

The `CharacterConcept.Universe` enum is **append-only, and a new value goes after `CUSTOM`**.
Ordinals are persisted into `bucket data/<path>.dat`, so inserting mid-enum renumbers every existing
bucket. Out of thematic order is correct. See [[Adding Nexus Concepts]], [[The Nexus]].

## 6. Anything client-side is mirrored to `deploy/`

`deploy/` is the Cloudflare Pages upload root. A change that only lands in `webclient/app/` is
invisible to players.

Mirrored: `app.js`, `net.js`, `style.css`, `index.html`, and every JSON manifest the client fetches
(`roster.json`, `ability_info.json`, `ability_split.json`, `ability_icons.json`, `char_index.json`,
`portraits.json`, `titles.json`, `bounty_data.json`, `campaign_*.json`, `shop_catalog.json`), plus
`assets/` under `deploy/assets/`.

**Not** mirrored: `abilities_data.json` (server-side only), and the test artefacts
`tests.html` / `aa-tests.js` / `aa-test-harness.js`, which `build-pages-deploy.ps1` explicitly skips.

The most common miss is `app.js` itself — hardcoded arrays such as `CHAR_SELECT_ORDER` live in
**both trees** and a character added to only one is invisible in char-select on the deployed client.
See [[Data Files and the Deploy Mirror]], [[Web Client Architecture]].

## 7. Do not fix what the owner has chosen to leave

An adversarial audit on 2026-07-20 found pre-existing account-corruption and deletion holes in legacy
`@rpc("any_peer")` handlers, plus non-atomic and fail-open saves. The owner was asked and **chose to
leave them** as out of scope. They are documented in the `legacy-account-safety-holes` memory note as
a reference if revisited — not as a backlog. Unprompted "while I was in here" fixes to known-deferred
items are out of bounds.

The same applies to the four abilities that hard-set another ability's `cooldown_remaining` with the
`+1` baked in (`soul5.gd`, `tsubaki5.gd`, `lizandpatty1.gd`, `lizandpatty2.gd`) — deliberately not
touched, because two of them have a bespoke `waiting_for_turn`-dependent branch that needs
understanding first. See [[Cooldowns and Energy]].

## Related

- [[How I Work in This Repo]] — the loop these rules constrain
- [[Verification Playbook]] — how a change earns the word "done"
- [[Traps That Have Bitten Us]] — the failures, symptom-first
