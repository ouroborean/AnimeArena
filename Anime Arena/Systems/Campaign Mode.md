---
tags: [area/systems, type/concept]
---

# Campaign Mode

Single-player PvE story mode: a node map you travel, visual-novel dialogue beats, and scripted
battles fought on the ordinary battle engine. It is the only part of the game where the client owns
a screen the server has never seen — and precisely for that reason it is the most aggressively
**server-authoritative** subsystem in the codebase.

> [!info] Currently gated off
> `webclient/app/app.js:24` holds `const CAMPAIGN_ENABLED = false;` — "campaign mode is locked/hidden
> until it's finished". The only consumer is the `⚔ Campaign` button in `menuQueueRow()`
> (`app.js:2155`). Everything below is live, tested code; it is simply not reachable from the menu
> until that flag flips. All server handlers stay dispatchable, so a WS harness can drive campaign
> intents today.

## The shape of the system

| Piece | Where | Role |
|---|---|---|
| Rule tables | `webclient/app/campaign_chapters.json`, `campaign_dialogue.json`, `campaign_encounters.json` | Chapters, nodes, activations, VN scenes, encounter rosters |
| Shared resolver | `scripts/campaign.gd` (`class_name Campaign`) | Server-side reader of the SAME JSON the client fetches |
| Intent handlers | `components/server_connection.gd` `_campaign_*` (≈ L2805–3063) | Validate → mutate → persist → echo |
| Battle handoff | `start_campaign_battle` (`server_connection.gd:2699`) | Builds the Match; teams derived server-side |
| Progress blob | `Player.campaign_state` (`scripts/player_component.gd:66`) | The one authoritative record |
| Client engine | `app.js` `campaign*` family (≈ L1776–2147) | Map view, VN sequencer, optimistic UI |
| Avatar character | `character/vessel.gd` | The player's own fighter — see [[Adding a Playable Character]] for what it does *not* do |

Note the file location: the resolver lives at **`scripts/campaign.gd`**, not `components/`. It is a
plain `RefCounted` with static methods and static caches, so any code path can call
`Campaign.chapter(id)` without instantiating anything.

## Server authority: intents in, echo out

The client never writes `campaign_state`. It sends *intents*; the server is the only thing that
mutates progress.

| Intent (C→S) | Handler | Effect |
|---|---|---|
| `campaign_enter` | `_campaign_enter` | Init a fresh chapter if none; **clears `active`**; echoes `arrive:false` |
| `campaign_travel {to}` | `_campaign_travel` | Validates the edge + `open_when`; moves node; arms `active`; `arrive:true` |
| `campaign_arrive {node}` | `_campaign_arrive` | Re-select the CURRENT node to (re)start its beat; `arrive` iff a beat resolved |
| `campaign_activation_complete {node, activation}` | `_campaign_complete` | Gate on banked wins → consume → apply `on_complete` → clear `active` |
| `campaign_choice {scene, line, choice}` | `_campaign_choice` | Applies a dialogue choice's `set_flags` / `unlocks` |
| `campaign_abandon {node, activation}` | `_campaign_abandon` | Drop the beat after a battle loss; discard its banked wins |
| `campaign_set_party {party[3]}` | `_campaign_set_party` | Validate against the chapter pool + PvP unlocks |
| `campaign_set_vessel_skills {skills[1..4]}` | `_campaign_set_vessel_skills` | Validate against the Vessel's key pool |
| `campaign_start_battle {encounter}` | `start_campaign_battle` | Both teams derived server-side |

Every successful handler ends the same way:

```gdscript
resave_player(p)
_send_campaign_state(json_pid, p, "<note>", <arrive>)
# -> {"type":"campaign_state", "state": p.campaign_state, "unlocks": p.unlocks, "note":…, "arrive":…}
```

An **illegal** intent goes through `_campaign_reject` instead, which ships
`{"type":"campaign_error", reason, state, unlocks}` — i.e. a rejection still carries the
authoritative state, so the client can revert whatever it optimistically drew. On the client,
`campaignApplyServerState(m, note)` (`app.js:1836`) is the *only* place `S.campaign` is reassigned
from data, and `campaign_error` routes through it too before showing the reason.

> [!warning] Trap: campaign_state must never be client-writable
> `campaign_state` round-trips through `save()` / `load_player()` / `make_cosmetic_update()` — but it
> is deliberately **absent** from `absorb_cosmetic_update` (`player_component.gd:214`, comment only,
> no assignment). That absence is the entire security model, exactly like `wins`/`losses`/`friends`.
> Adding one innocent-looking line there would let any modified client hand itself every reward in
> the chapter. Same recipe as [[Server Authority Model]] describes for unforgeable Player fields.

## The `active` beat pointer — and why it isn't a re-resolve

`campaign_state.active = {node, activation}` records which beat the player is *currently inside*.
`_campaign_complete` and `_campaign_choice` validate against **that stored pointer**, not against a
fresh call to `Campaign.resolve_activation`.

This looks like redundant state until you see why: a dialogue choice's `set_flags` can change which
activation would resolve *mid-sequence*. Placeholder chapter X has exactly this shape — the `market`
node offers `market_quest` while `not_flags:[helped_merchant, declined_merchant]`, and `market_after`
once `flags:[helped_merchant]`. Choose "help the merchant" during `market_quest` and a re-resolve at
completion time would return `market_after`, so the beat the player actually played could never be
completed.

The pointer buys a second guarantee for free: you cannot complete a beat out of order (win
`enc_defense` early, then claim `hub_return`) because `active` never pointed at it.

## Battle gating, save-resume, and anti-cheat

`start_campaign_battle` (`server_connection.gd:2699`) refuses to trust the client for anything that
matters:

1. The player must have an `active` beat.
2. The requested `encounter` must be a `{"battle": <enc>}` step **of that beat's `sequence`**.
3. The **enemy team and name** come from `Campaign.encounter(enc_id)`, never from client params.
4. The **player party** comes from `campaign_state.party`, never from client params.

Without (2)–(4) a client could start a trivial fight for any encounter id, win it, and bank a
pending win that later satisfies a real story battle.

A won encounter is recorded in the **persisted** `campaign_state.pending_wins` as a beat-scoped
record, written in the CAMPAIGN branch of `handle_server_match_ended` (`server_connection.gd:3410`):

```gdscript
var win_rec = {"activation": nmatch.campaign_activation, "encounter": nmatch.campaign_encounter}
if not _has_pending_win(winner.campaign_state["pending_wins"], nmatch.campaign_activation, nmatch.campaign_encounter):
    winner.campaign_state["pending_wins"].append(win_rec)
```

`_has_pending_win` / `_erase_pending_win` match on **both** fields. Beat-scoping is the point: a win
banked for one beat must not satisfy a *different* beat that happens to reuse the same encounter id.

Because `pending_wins` lives on the persisted player rather than in a session, a won-but-unclaimed
battle **survives a disconnect**. On the client, `campaignRunStep()` (`app.js:1881`) skips a battle
step already banked for this beat:

```js
const won = ((S.campaign && S.campaign.pending_wins) || []).some(
  (w) => w && w.activation === run.activationId && w.encounter === step.battle);
if (won) { run.idx++; campaignRunStep(); }
else campaignLaunchBattle(step.battle);
```

So a resumed talk→battle→talk beat replays the dialogue but does not re-fight.

> [!tip] Entering always lands on the map
> `_campaign_enter` unconditionally does `prog.erase("active")` and echoes `arrive:false`. Entering
> fresh, re-entering after a loss, and reconnecting all put you on the **map at your last node** —
> the game never auto-plays a beat on you. Starting a node's events requires clicking it, which sends
> `campaign_arrive`. Only `travel` and `arrive` ever echo `arrive:true`.

## Losing a battle

There is no failure state beyond "try again". `returnToCampaign()` (`app.js:1927`) on a loss sends
`campaign_abandon {node, activation}`; the server clears `active` and calls
`_erase_beat_wins(prog["pending_wins"], activation_id)` so a partially-won multi-battle beat
re-fights from the top. It does **not** apply `on_complete` and does not mark the activation
completed.

The player is dropped on the map, and the current node renders as `.restartable`
(`campaignMapView`, `app.js:2095`) whenever a beat still resolves there. Clicking it sends
`campaign_arrive`, which re-arms `active` and replays the whole beat from step 0 — dialogue included.

A fresh-JS reconnect straight into a live campaign battle leaves `S.campaign` null (it is only ever
set by `enterCampaign` or a server echo), so `returnToCampaign` reseeds it from the login blob and
falls back to `campaign_enter`, which is what stops the screen wedging on "Loading campaign…".

## Rules language (the JSON)

A chapter is a start node + a node graph. A node has `x`/`y` (fractional map coordinates),
`edges`, `open_when`, and an ordered list of `activations`. Resolution is
`Campaign.resolve_activation` (`scripts/campaign.gd:92`) — **first** activation whose `when` passes
and which, if `once`, is not already in `completed`:

```gdscript
for a in n.get("activations", []):
    if a.get("once", true) and (a.get("id") in done):
        continue
    if when_passes(a.get("when", {}), prog):
        return a
```

Note the default: `a.get("once", true)` — an activation is **one-shot unless it says otherwise**.
Chapter X's `hub_train` sets `"repeatable": true`, which is *not* the key the resolver reads; it is
the `"once"` key that governs, and its absence means one-shot. Idle activations (`"when": {}`,
listed last) are the catch-all so a node always has something to say.

`when_passes` (`scripts/campaign.gd:67`) supports `stage` (scalar or array), `flags` (all must be
true) and `not_flags` (none may be true). `node_open` runs the same predicate over `open_when`.

An activation's `sequence` is a list of `{"talk": <scene>}` and `{"battle": <encounter>}` steps.
`on_complete` may carry `set_stage`, `set_flags`, and `unlocks`. `_campaign_apply_effects`
(`server_connection.gd:2861`) splits unlock tokens two ways:

- `"char:levi"` → appends `levi_unlock` to `p.unlocks` — the **shared PvP unlock token**, so a
  campaign reward genuinely unlocks the character for normal play.
- `"ability:<key>"` → appends to `campaign_state.campaign_unlocked_abilities` — campaign-only, and
  consumed exclusively by the Vessel.

`fresh_state(chapter_id)` (`scripts/campaign.gd:104`) is the canonical shape of a new run:
`chapter, node, stage, flags, visited, completed, party (chapter party sliced to 3),
campaign_unlocked_abilities, vessel_loadout, pending_wins`.

## The Vessel

`character/vessel.gd` is the campaign's player-avatar and the only character in the game whose
moveset is **assembled at battle-build time**. It has no `character_ability_counts.json` entry and
does not go through `Movesets.from_skill_count`. Instead `initialize(true)` builds an `Ability[]` by
hand and hands it to `moveset.set_base_abilities(kit, self)`.

```gdscript
const DEFAULT_ABILITY_KEYS   = ["vessel1", "vessel2", "vessel3", "vessel4"]
const AVAILABLE_ABILITY_KEYS = ["vessel1", "vessel2", "vessel3", "vessel4", "vessel5", "vessel6"]
var extra_ability_keys: Array = []   # campaign unlocks, stamped by start_campaign_battle
var loadout: Array = []              # player-chosen keys from campaign_state.vessel_loadout
```

`start_campaign_battle` stamps both fields onto the vessel seat **after** `Match.from_players` and
**before** `begin_match()` (`server_connection.gd:2759`), because the moveset is not assembled until
`begin_match` → `initialize(true)` reads them.

> [!danger] Never build more than four keys
> `MovesetComponent.display_abilities` only ever surfaces indices 0–3. Appending campaign unlocks as
> slots 5, 6, … would make them permanently unreachable in battle. `_resolve_kit_keys()` therefore
> always returns exactly four: an explicit `loadout` (filtered to the allowed pool, deduped, sliced
> to 4, padded from the defaults), otherwise the four defaults with unlocks **replacing trailing
> slots**. Over-supplying unlocks logs `push_warning("[VESSEL] %d campaign unlocks exceed the 4
> ability slots; extras dropped")`.

The four defaults (plus two alternates) are all Cost: 1 Random:

| Key | Name | Effect | CD |
|---|---|---|---|
| `vessel1` | Strike | 15 NORMAL damage | 0 |
| `vessel2` | Bandage | Heal an ally 10, immediate + over 2 turns | 1 |
| `vessel3` | Combat Direction | Shattered 2t + +5 non-Affliction damage taken 2t | 2 |
| `vessel4` | Block | Self Invulnerable 1 turn | 4 |
| `vessel5` | Second Wind *(alt)* | Self-heal 15 | 3 |
| `vessel6` | Disarm *(alt)* | Stun target enemy 1 turn | 4 |

See [[Effects and Durations]] for why "2 turns" is written as duration 3 in those scripts.

> [!warning] Two hardcoded pools must stay in sync
> `_campaign_set_vessel_skills` (`server_connection.gd:3051`) validates against a literal
> `["vessel1"…"vessel6"]` list with a comment pointing at `AVAILABLE_ABILITY_KEYS`. Author a
> `vessel7` and you must edit both, or the loadout picker offers a skill the server rejects.

The party validator refuses any team without the Vessel: *"your team must include the Vessel"* —
without it the loadout and every `ability:` unlock would be inert. The party pool is
`["vessel"] + chapter.roster_grants + anything the player unlocked in PvP` (`<name>_unlock` or
`all_unlock`).

## VN dialogue and emotion portraits

A dialogue scene is `{background, lines[]}`; a line carries `speaker`, `pos`
(`left`|`center`|`right`), an optional `portrait` (a roster `path_name`), an optional `emotion`, and
either `text` or `choices`.

`campaignDialogueView()` (`app.js:2119`) accumulates a *cast*: the last portrait shown at each
position up to the current line, so several speakers share the stage and a character **holds its
expression until it emotes again**.

Emotion art resolves entirely by filename convention — no manifest, no build step:

```js
const PORTRAIT_EMOTIONS = ["happy", "serious", "shocked"];
function emotionRel(pn, emotion) {
  if (!emotion || !PORTRAIT_EMOTIONS.includes(emotion)) return null;
  const e = (S.portraits && S.portraits[pn]) || (S.charIndex && S.charIndex[pn]);
  if (!e || !e.default) return null;
  const slash = e.default.lastIndexOf("/");
  const folder = slash >= 0 ? e.default.slice(0, slash) : "";
  return (folder ? folder + "/" : "") + pn + "_portrait_" + emotion + ".png";
}
```

The folder is **derived from the manifest's `default` path**, because the asset folder is a display
name (`assets/images/Naruto Uzumaki/`) and is not derivable from the `path_name` (`naruto`).

Missing art degrades gracefully via a one-shot `onerror` swap (`app.js:2135`):

```js
const onerr = (e) => { const img = e.target;
  if (dflt && dflt !== url && img.dataset.fb !== "1") { img.dataset.fb = "1"; img.src = dflt; }
  else img.remove(); };
```

The `img.dataset.fb` guard is what stops an infinite error loop when the *default* portrait is also
missing — second failure removes the element.

To add emotion art: drop `<path_name>_portrait_<emotion>.png` into both
`assets/images/<Display Name>/` and `deploy/assets/images/<Display Name>/` (see
[[Data Files and the Deploy Mirror]]). No code or JSON change is needed.

## Choice validation

`_campaign_choice` cannot simply trust a `{scene, line, choice}` triple. It rebuilds the set of
scenes reachable *within the active beat* — `Campaign.activation_scenes(activation)`
(`scripts/campaign.gd:125`) walks the beat's `talk` steps and then follows choice `goto`s
transitively — and rejects anything outside it. Then it bounds-checks `line_idx` against
`scene.lines` and `choice_idx` against that line's `choices` before applying the effects.

## Client/server duplication is deliberate

`Campaign.when_passes` mirrors `campaignWhenPasses` in `app.js:1790`; `resolve_activation` mirrors
`campaignResolveActivation`; `node_open` mirrors `campaignNodeOpen`. Both sides read the **same
three JSON files** — the server via `res://webclient/app/campaign_*.json`, the client via `fetch()`.
The client copy exists only so the map can draw locked/reachable/beat-pending states without a round
trip; the server copy is the one that decides. When you edit the rule tables, both sides pick up the
change with no code edit, which is the whole reason the JSON path is shared rather than duplicated.

> [!tip] Editing the resolver's class
> `Campaign` is a `class_name`. If you add another one alongside it outside the editor you must run
> `godot --headless --import` to regenerate the class cache or the server will not resolve the type
> — see [[Traps That Have Bitten Us]].

## Related

- [[Server Authority Model]] — the intent/echo pattern this mirrors from bounties
- [[The Turn Pipeline]] — campaign battles run the ordinary pipeline with `MatchType.CAMPAIGN`
- [[Bots and Training]] — the enemy seat is driven by the generic bot AI
- [[Web Client Architecture]] — `set()` / `render()` and the off-render input buffers the loadout UI uses
- [[Adding a Playable Character]] — everything the Vessel deliberately skips
