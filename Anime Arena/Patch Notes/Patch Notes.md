---
tags: [area/playbook, type/concept]
---

# Patch Notes

Balance patches live here. Each patch gets **two** pages that are written together and kept in sync:

| Page | Audience | Answers |
| --- | --- | --- |
| `Patch YYYY-MM-DD` | Players | *What changed, in the game's own words* |
| `Patch YYYY-MM-DD - Implementation Roadmap` | Whoever builds it | *What work each line costs, in what order, and what it will break* |

The split exists because in this repo the two are genuinely different documents. A one-line
player-facing change ("Titan Bite deals 40 damage") can be a hardcoded literal in a `.gd`, a stale
cache in `abilities_data.json`, a client JSON rebuild and a bot weight — and a different one-line
change ("Mahapadma is no longer a stun effect") can silently delete six unrelated interactions across
four other characters. The roadmap is where that is written down **before** anyone edits a file.

## Patches

| Patch | Scope | Status |
| --- | --- | --- |
| [[Patch 2026-08-02]] · [[Patch 2026-08-02 - Implementation Roadmap]] | 44 characters, 77 changes | **Implemented.** All 77 changes landed; the seal primitive is new engine work. Browser pass still owed |

## The convention for a new patch

1. **Take the owner's change list verbatim first.** Do not paraphrase it into the notes before the
   recon — the paraphrase is where "cost increased to 1 Blue" quietly becomes "1 Blue *in addition
   to* the Random it already cost".
2. **Recon before drafting.** Open every named ability script *and* its `abilities_data.json` row.
   Roughly a quarter of the numbers a change list describes turn out to live in a `.gd` literal or
   in a `character/<name>.gd` method rather than in the data file, and a few live in a *different*
   ability than the one named.
3. **Write the roadmap first, the player notes second.** The recon decides how a change is honestly
   phrased. A change that cannot be built as stated should surface as an open question, not as a
   confident sentence in the player notes.
4. **Every ambiguity becomes a numbered open question** phrased so a yes/no or a single number
   closes it. Do not resolve an ambiguity by picking the reading that is easiest to implement.
5. **Mark the status.** A patch page describes something that has not shipped until it has. Say so
   at the top; the vault's norm is that a page is honest about its own state.

> [!warning] The three facts every patch roadmap has to restate
> They are restated per patch rather than linked, because every patch has re-learned them.
> - **Durations tick at the end of *every* player's turn.** "1 turn" is `2`. See
>   [[Effects and Durations]].
> - **A recurring effect cannot fire on the turn it is planted.** Windows that include the cast turn
>   are `immediate + 2N-1`; pure delayed riders are `2N+1`. See [[Trigger Types]].
> - **Editing `describe()` / `split_desc()` reaches nobody.** The client reads a generated JSON. See
>   [[Changing Ability Text]].

## Related

[[Anime Arena]] · [[Changing Ability Text]] · [[Effects and Durations]] · [[Trigger Types]] ·
[[Cooldowns and Energy]] · [[Verification Playbook]] · [[Traps That Have Bitten Us]]
