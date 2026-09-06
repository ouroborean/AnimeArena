---
tags: [area/architecture, type/concept]
---

# Anime Arena

A turn-based team fighting game. Two players field three characters each, spend a shared coloured
energy pool on four skills apiece, and resolve a turn at a time. A **Godot 4.6 headless GDScript
server** owns all game state; a **vanilla-JS web client** renders it and sends intents. There is no
desktop client any more — see [[System Overview]].

This vault is the map of how it works, and of how to change it without breaking it.

## Start here

| If you want to… | Read |
| --- | --- |
| Understand the shape of the whole thing | [[System Overview]] |
| Know who decides what | [[Server Authority Model]] |
| Touch anything that happens "each turn" | [[The Turn Pipeline]] ← **read this first** |
| Write or edit a skill | [[Effects and Durations]], [[Trigger Types]] |
| Add a character | [[Adding a Playable Character]] |
| Change what a skill's text says | [[Changing Ability Text]] |
| Ship an update to the live server | [[Season Reset and Maintenance]] |
| Know what has bitten us before | [[Traps That Have Bitten Us]] |
| Extend the player-facing skill builder | [[The Creator]] → [[What Cannot Be Built Yet]] |
| Pressure-test the Creator against a real kit | [[Creator Roulette]] |

> [!warning] The one fact that causes the most bugs
> A side's ticking effects are **snapshotted before that turn's abilities run**. An effect a skill
> plants therefore *cannot* fire on the turn it was cast. Any skill promising a recurring per-turn
> effect must deal its first instance by hand. Full explanation in [[The Turn Pipeline]] and
> [[Effects and Durations]].

## Architecture

- [[System Overview]] — the processes, the transport, and where state lives
- [[Server Authority Model]] — what the server owns, what the client is trusted for, peer id namespaces
- [[The Turn Pipeline]] — the exact ordering of a turn, and what breaks when you misread it
- [[Web Client Architecture]] — the single state object, `render()`, and the net layer
- [[Data Files and the Deploy Mirror]] — the JSON that feeds the client, and keeping `deploy/` in sync

## Battle engine

- [[Effects and Durations]] — the duration model, effect naming, visibility flags
- [[Trigger Types]] — ticking vs start-of-turn vs end-of-turn vs reactive, and which to reach for
- [[Damage Pipeline]] — ability damage vs effect damage, redirects, reflects
- [[Targeting and Main Target]] — why target order matters, and invulnerability bypass
- [[Cleanse Silence and Effect Removal]] — the `cleansable` model and the death cleanse
- [[Cooldowns and Energy]] — the +1 bookkeeping, Paralyze, the colour pool
- [[Node Lifecycle and Orphans]] — parenting, deferred frees, and reading the orphan count correctly

## Systems

- [[Matchmaking and the Ladder]] — queues, rating, rank tiers, the bot fallback
- [[Bots and Training]] — the contextual model, the trainer, team pools
- [[Campaign Mode]] — server-authoritative progress, the Vessel, VN dialogue
- [[The Nexus]] — the community AP-donation leaderboard
- [[Social Clans and Chat]] — friends, DMs, clans, spectating, replays
- [[Admin and Live Ops]] — the admin panel, maintenance, season reset, stats

## The Creator

The player-facing block authoring system: skills composed as validated JSON block trees, interpreted
at runtime through the same engine primitives hand-written abilities use. Players are the authors, so
**data-never-code** is a hard constraint rather than a style preference.

- [[The Creator]] — architecture, safety model, authoring and approval lifecycle, honest current state
- [[Block Palette Reference]] — every block, field and limit, with a worked example
- [[What Cannot Be Built Yet]] — the measured gap between the palette and the real roster
- [[Creator Roadmap]] — phased plan to close the gaps, and what deliberately stays out

## Creator Roulette

A recurring robustness exercise: draw a random playable character, ask honestly whether the Creator
could rebuild their kit, and where it could not, design the open-ended system that would make it
possible — never a band-aid for one character.

- [[Creator Roulette]] — the process, the sampling frame, the design bar, and the run ledgers

## Playbooks

- [[Adding a Playable Character]] — the full registration checklist
- [[Adding Nexus Concepts]] — non-playable concepts, art, and the Universe enum
- [[Changing Ability Text]] — why editing `describe()` alone changes nothing
- [[Season Reset and Maintenance]] — the live-ops procedures

## Working with Claude

Notes on how the AI assistant operates in this repo — the rules it holds to, how it verifies work,
and the mistakes already made and recorded so they are not repeated.

- [[How I Work in This Repo]] — the working loop
- [[Hard Rules and Guardrails]] — the absolutes (git, test accounts, data-file formatting)
- [[Verification Playbook]] — compile → probe → **revert the fix and re-run** → live → browser → review
- [[Traps That Have Bitten Us]] — a numbered field guide, symptom first

---

> [!info] Provenance
> These notes are distilled from the codebase and from ~48 engineering memory notes accumulated while
> building the game. Where a claim was not verifiable against the code it was left out rather than
> guessed. Anything describing runtime behaviour was measured, not assumed.
