---
tags: [area/systems, type/reference]
---

# Bots and Training

A bot match is an ordinary server-authoritative `Match` whose p2 seat is a synthetic, peer-less bot
`Player`. The human plays through the normal gateway turn-input path; the server drives the bot's
turns by running the AI directly on the authoritative shadow `BattleManager` and broadcasting the
resulting events. There is no client-side bot and no client-reported result — see
[[Server Authority Model]].

## Three ways a player ends up fighting a bot

| entry point | `match_type` | `practice_match` | W/L | AP |
|---|---|---|---|---|
| explicit **Bot Match** queue (`queue_bot` → `start_immediate_bot_match`) | `BOT` | **true** | none | 50 / 0 |
| **Quick** queue fallback (`_start_bot_fallback`) | `BOT` | false | none | 100 / 50 |
| **Ladder** queue fallback (`_start_ranked_bot_fallback`) | `RANKED` | false | **yes** | 250 / 50 |

> [!warning] Trap
> The first two are **both** `BattleManager.MatchType.BOT`. You cannot tell them apart by
> `match_type`. The differentiator is `Match.practice_match`, a bool set in `start_bot_match`
> (`components/server_connection.gd:2489`). `handle_server_match_ended` passes it into
> `_calculate_ap_gain` and gates the match-history write on it.

Mastery XP, bounty progress and StatsDB recording are unchanged for practice bots — practice still
levels characters.

Because every bot match ships to the client over the **same** `receive_quick_match` frame, the
server threads a `"practice"` bool through the payload (and through
`Match.get_reconnection_info`, so a reconnect is also correct) purely so the client can label it.
Real quick senders omit the key → falsy. A *fallback* bot stays labelled "Quick Match", which is
correct: it records Quick AP and no W/L.

### Bot seats and peer ids

```gdscript
const BOT_PEER_BASE := -1000
func _is_bot_peer(peer_id) -> bool:
	return typeof(peer_id) == TYPE_INT and peer_id <= BOT_PEER_BASE
```

Synthetic peer ids are always negative so they cannot collide with real Godot peers (positive) or
JSON-gateway logical peers (`JSON_PEER_BASE = 1e9+`). With no session and no `peer_map` entry, every
peer-guarded broadcast and save skips the bot automatically.

## Driving a bot turn

`_drive_bot_if_acting(nmatch)` (`server_connection.gd:3070`) runs whenever the bot seat holds the
turn — after each human turn, after a timeout, and at match start for a bot-first flip.

> [!danger] Never gate this on match type
> `_drive_bot_if_acting` used to bail unless `match_type` was `BOT` or `CAMPAIGN`. That type
> whitelist left a **ladder** bot frozen on its turn until the clock ran out, once the ranked
> fallback started seating bots. It is now gated on the seat only (`if not is_instance_valid(nmatch):
> return`), because the `while _is_bot_peer(acting_player)` loop is already the real condition — a
> bot-free match never enters it.

Inside the loop: stop the per-match `$Timer`, pause `randf_range(4.0, 9.0)` seconds so the human can
read the board, re-check that the match is still alive and the seat unchanged, run the turn, flip
`acting_player`, broadcast, re-arm the timer. The bot acting does **not** reset the human's AFK miss
streak — a human who keeps timing out against a bot keeps shaving their timer and eventually
forfeits (see [[Matchmaking and the Ladder]]).

`_run_shadow_bot_turn(mgr)` (`:3106`) picks the brain:

```gdscript
var policy = BattleManager._get_live_bot_policy()
if policy != null:
	await mgr.enemy.perform_turn_v3(mgr, policy, null,
		BattleManager._live_tier_temperature(), BattleManager._get_live_bot_tuning(), false)
else:
	await mgr.enemy.perform_turn_contextual(mgr, BattleManager._get_live_bot_model(), 1)
```

> [!warning] Enemy-seat energy latch
> `wait_for_turn` **pre-generates** the enemy's energy on the shadow and latches
> `acting_energy_prepared`. `_run_shadow_bot_turn` therefore only calls `generate_team_energy` when
> that latch is false. A bot-vs-bot driver that generates unconditionally gives double first-turn
> energy — measured as a 41/59 seat skew, and the entire v2 model's training history carried that
> bias. Post-fix mirror match: 54.0% over 200 (fair).

## The live policy cache

`new multiplayer/battle_manager.gd:41-78`:

- `LIVE_POLICY_PATH := "res://bot_policy.json"` — loaded **once per process** into a static, on the
  first bot turn. Promoting a new policy needs a server restart.
- `LIVE_TUNING_PATH := "res://bot_tuning.json"` — the hand-tuning overlay, **hot-reloaded by
  mtime**, so score offsets and difficulty tiers apply without a restart.
- `_live_tier_temperature()` reads `global.difficulty_tiers[global.default_tier]` — softmax
  temperature, higher = sloppier. Shipped values: `easy 1.2`, `normal 0.45`, `hard 0.12`. This
  replaced the old, inverted `bot_difficulty` noise knob.

```gdscript
if _live_policy != null:
	print("[bot-v3] Live policy loaded: generation %d, %d trained matches" % ...)
else:
	push_error("[bot-v3] bot_policy.json exists but FAILED to load — falling back to the contextual bot")
```

A corrupt or wrong-format policy file must **fall back**, never play zero-weight softmax live: an
all-zero v3 policy is uniform-random, strictly worse than the legacy contextual bot the null path
selects. Same rule for `bot_tuning.json` — shape-validated by `_validate_bot_tuning` before it is
ever written by an admin.

The legacy brain is `new multiplayer/bot_contextual_model.gd` (`BotContextualModel`), a contextual
bandit with 17 ability features and 13 target features, REINFORCE-style updates
`w += lr * reward * features`, softmax selection, and annealed exploration. It is now a **frozen
eval baseline** (`contextual_v2`) plus the fallback brain; the live path is v3.

## v3 architecture

Spec: `.claude/plans/bot-training-v3.md`. Files:

| file | role |
|---|---|
| `training/bot_observation.gd` | `BotObservation` — the **only** state accessor policy features may touch |
| `training/bot_policy.gd` | `BotPolicyV3` — shared + per-(char,ability) linear scorers, softmax select, `apply_returns`, `merge`, persistence |
| `training/bot_trainer.gd` + `trainer_scene.tscn` + `run_trainer.ps1` | one seeded self-play worker |
| `training/orchestrate_training.ps1` | N workers × M matches × R rounds → merge → eval |
| `training/promote.ps1` | gated copy of a checkpoint to the live `bot_policy.json` |
| `training/eval_parallel.ps1` | shard an eval across 8 processes, print a Wilson CI |
| `training/focus_character.ps1` / `fold_focused.ps1` | per-character training and batching |
| `training/team_tournament.ps1` | which *teams* the frozen policy wins with |
| `training/bake_bot_tags.py` → `training/bot_tags.json` | static 7-bit semantic mask per ability |
| `scripts/player_component.gd:1183` `perform_turn_v3` | the decision loop that consumes all of it |

### Human parity is the hard constraint

`BotObservation` wraps `(battle, viewer_team)` and exposes exactly what the **web client renders**
for a player in that seat — not what the engine knows.

- **Own side**: everything the wire ships — hp, effects (including own invisible ones, minus
  `system` except `display_system`), live costs, `cooldown_remaining`, `usable`, the `target()`-probe
  legal-target sets, own energy pool.
- **Enemy side**: hp/max/dead/banished, kit identity + live cost + **base** cooldown + static damage
  hint (all inspect-panel visible), and effects filtered by visibility. **Never**:
  `cooldown_remaining`, `usable`, `special_targets`, or the enemy energy pool.

Visibility mirrors `app.js` `effectClusters`, **not** the engine's `get_effect_clusters` — the
engine's version skips the alive/banished check on Toph. The client wins: a living, unbanished Toph
senses invisible Physical effects; a living, unbanished Kurotsuchi bearing "Data Collection" senses
all invisible ones. Honesty is asserted by `training/tests/observation_probe.tscn`. See
[[Effects and Durations]].

> [!danger] Never call character-level predicates from feature code
> `is_stunned` / `is_invuln` / `marked_by` and friends skip the visibility filter and break parity.
> Re-derive from `obs.visible_effects()`.

Reward shaping is allowed to read full state — only the *policy's inputs* must be parity-filtered.
The outcome signal is just the score of the game.

### Scoring and learning

`score(action) = dot(shared_w, φ_ability) + dot(entry_w, φ_ability) + the same for targets`.
Weights are **name-keyed on disk** (`bot_policy.json`, `training/checkpoints/gen_N.json`) precisely
so the schema can grow — append only, never reorder, and new features load at exactly `0.0` so the
live bot is provably unchanged until retrained.

Selection is softmax with temperature over the whole team's affordable candidates (T=0 → argmax), so
one knob covers training exploration *and* live difficulty tiers.

`apply_returns` (`bot_policy.gd:620-648`) is two-pass — all advantages against the baselines as of
call entry, then weights, then the baseline EMAs move. Learning rates:

```gdscript
var lr:   float = lr0 / (1.0 + float(e["updates"]) / lr_tau)         # lr0 0.05, lr_tau 400
var lr_s: float = lr0 / (1.0 + shared_updates / shared_lr_tau)       # shared_lr_tau 20000
```

Baseline is two-level: a fast global return EMA plus a per-character residual EMA — a
per-character-only baseline lags badly on a 170-character roster.

### The gotchas that cost real debugging

> [!danger] Never give a fixed-0 STOP/pass competitor in softmax selection
> Losses produce negative updates → all scores go below 0 → STOP dominates → the bot passes whole
> turns → death spiral (measured 20.7% vs RANDOM and falling). Energy banking, if it is ever added,
> must be a **learned** action.

> [!warning] The softmax gradient must be centered
> Update with `φ_chosen − E_π[φ]`, not raw `φ_chosen`. Otherwise state-common features (bias, HP
> ratios) inflate without bound — bias hit +40 in 150 matches — and wreck the temperature/tuning
> scales. With centering plus a shared layer: 58% vs random after only 150 matches.

- **Per-ability-only weights don't learn on a 170-character roster.** ~5 updates per entry after
  150 matches is argmax noise (measured exactly 50%). The shared layer carries the transfer.
- **`merge` must count deltas over the shared parent** (`--merge-base`). Summing worker absolute
  counts inflates updates ~N× per round and crushes the lr schedule.
- **`usable()` bakes in affordability.** Planning code that wants to see unaffordable options (the
  energy exchange!) must use `authoritative_usable(user, true)` plus an explicit can-afford flag.
- **Banished characters count as alive-with-HP in reward snapshots.** Banish is usually temporary;
  excluding them pays fake kill credit.
- **Elo must update once per eval block.** A grouped W-then-L sequential replay inverts the ladder.
- The trainer **hard-fails** an unknown `--opponent`; a silent self-mirror corrupted evals once
  (`bot_trainer.gd:159`).

## The plateau, and what it taught

This is the most valuable part of the story, because three separate interventions produced three
nulls and the diagnosis is now known ground.

### Root cause: the shared layer was structurally blind

The shared gradient is `φ[j] − E_π[φ[j]]`, and `select()` runs with `allow_stop=false` so
`sum(π) = 1` exactly. **Any feature constant across the candidate set has a mathematically exact
zero gradient, forever, at any learning rate.** `φ_a` is computed once per candidate *ability*, and
10 of the original 17 ability features read only global/team state — identical for every candidate.

Confirmed directly from `gen_8.json`: after 548,225 shared updates those 10 sat at machine epsilon
(bias −4.6e-16, `team_hp_ratio` −1.0e-16, `turn_progress` 3.8e-18). The 7 survivors collapse to ~4
effective degrees of freedom: three are functions of the cost scalar, two of the damage hint.
Compounding it, `bot_damage_hint()` returns `base_damage` or 0 and only 298 of 997 ability scripts
declare it, so **~70% of abilities report hint 0** — a Stun, a Heal and a Cleanse of equal cost were
literally the same point in feature space.

Target features are healthy by contrast (12 of 13 alive) — which is exactly why the bot **targets**
sensibly (focus-fire, kill-in-range, heal-the-hurt) but **picks abilities** badly.

**Ablation**: zeroing all 2,546 per-entry weight vectors and keeping only the shared layer scores
44.1% [41.9, 46.2] vs full gen_8 at n=2000. The shared layer carries the large majority of the
strength on ~4 DOF; 548k per-entry updates buy only ~6pp.

### The fix, and why it still didn't move the needle

12 ability features (indices 17-28) and 5 target features (13-17) were **appended** — all of which
vary across candidates: `cd_norm`, `t_damage_now`, `t_control`, `t_invuln`, `t_mitigate`, `t_heal`,
`t_mark`, `t_reactive`, `t_amplify`, `aoe_fanout_norm`, `heal_x_team_missing`, `guard_x_self_hurt`;
and `control_redundant`, `payload_denied`, `reactive_on_target`, `target_shielded_norm`,
`stacks_on_target_norm`. The last two ability features deliberately **resurrect dead globals**:
`team_hp_ratio` has zero gradient alone, but multiplied by an ability semantic the *product* varies,
so "heal when hurt" becomes learnable.

Semantics come from `training/bot_tags.json` — a 7-bit mask per ability baked by
`training/bake_bot_tags.py` from static `Effect.<factory>` fingerprints. It is a **side-car file,
not `abilities_data.json`** (that file is organic mixed-indent and must never be re-dumped; see
[[Data Files and the Deploy Mirror]]).

> [!warning] Verify factory names before baking
> The real ones are `Effect.isolate(`, `Effect.taunt_effect(`, `Effect.blind_effect(`,
> `Effect.banish_effect(`, `Effect.def_negate(`. Plausible guesses like `isolate_effect` or
> `def_negate_effect` silently bake an all-zero bit. Other traps honoured: `e.mag` is
> type-overloaded (Array/String/Vector2 on some effects) so `int(mag)` crashes a live match —
> guard `typeof(e.mag) != TYPE_INT`; `stack_count()` can return −1 (reflect's "unlimited"
> sentinel); use `classes.get()` never `classes[]`; `target_type` must be *compared* to constants,
> never used to index the enum (nobara3/4, yuji2/3/4 carry an out-of-range 5).

Results, all n≈2000 with `eval_parallel`:

| intervention | vs control | verdict |
|---|---|---|
| semantic features, resumed from gen_8 | 50.8% [48.6, 52.9] | null |
| semantic features, cold start | 50.9% [48.7, 53.0] | null |
| potential-based reward shaping (paired seed) | 49.1% [46.9, 51.3] | null |

> [!info] The LR trap that blunted the resumed arm
> `lr_s = lr0 / (1 + shared_updates / shared_lr_tau)` and `shared_updates` is **cumulative and
> carried through merges**: gen_1 starts at lr_s 0.0500 (100% of lr0), gen_8 at 0.00176 (3.5%),
> gen_11 at 0.00130 (2.6%). A feature appended to a mature checkpoint starts at 0.0 and can only
> crawl — after 6,000 matches the new weights reached 0.01-0.08 while established weights sit near
> 0.9. **Appending features to a trained checkpoint does not work without warm-restarting the shared
> LR schedule** (or tracking per-feature update counts). The cold start proved the fix worked —
> weights reached 0.03-1.37 after one round — and *also* gave the strongest confirmation of the
> diagnosis: even from scratch at full LR, the ten constant features still sat at 1e-16 while
> `kill_available` reached 0.83 in the same 2,000 matches. Their deadness is **structural**.

Potential-based shaping (Ng/Harada/Russell 1999), `F = γ·Φ(s') − Φ(s)`, is implemented in
`training/bot_trainer.gd` and is provably policy-invariant, so debuff-farming can never become
optimal at any weighting. `terminal=true` forces `Φ(s')=0` at match end — without that the
telescoping does not cancel and the final transition carries a real non-invariant bonus.
`--phi-scale 0` reproduces the pre-shaping reward **exactly**, giving a clean A/B from one binary.
`training/tests/potential_shaping_probe.tscn` proves the anti-farming property empirically: 50
apply/lapse cycles accumulate −1.20 under PBRS vs +15.00 under a naive apply-bonus.

### The first positive result: character focus + persistent exploration

Diagnosis: a shared, all-purpose learner cannot discover that a *preparation* skill unlocks a
stronger one, because softmax temperature resamples noise **independently at every decision** — it
finds good single actions but essentially never a whole multi-turn setup→payoff sequence, so the
payoff is never observed and therefore never credited.

Two mechanisms, both default OFF so old behaviour is exact:

- `--explore-sigma=F` — **persistent exploration** (parameter-space noise). At match start, draw a
  Gaussian perturbation of the **per-entry** weights and hold it for the whole match, so the bot
  plays a consistent variant of itself and a sequence can be attempted as a unit. Offsets live in
  `explore_offsets`, deliberately **outside** `entries`, and `to_dict()`/`merge()` contain zero
  references to it — noise structurally cannot be serialised into a checkpoint. Never perturbs
  `shared_w`.
- `--focus=<char>` — forces that character onto the **training** side every match, never the
  opposing side (that would train against a mirror).

Result (6 workers × 700 matches, σ=0.25, focus=naruto, from the shaped cold gen_5):
**59.1% [56.8, 61.4] at n=1798** on teams containing Naruto. Naruto per-ability updates went from
150-926 to 3,659-12,546 — 1638× the median non-focused ability.

> [!warning] Why the earlier nulls were nulls: the measurement was wrong
> A character appears in only ~3-4% of random matchups, so a 10pp gain on one character is ~0.3pp
> globally — **invisible at n=2000**. All three previous interventions were measured globally.
> Character-specific work must be measured *on that character*. `focus_character.ps1` therefore
> evaluates **with** `--focus`.

## Workflows

```bash
# broad self-play: N workers x M matches x R rounds, merge -> gen_{k+1}, eval vs baselines
./training/orchestrate_training.ps1 -Workers 6 -Rounds 3 -MatchesPerWorker 250

# per-character
./training/focus_character.ps1 -Character naruto
./training/focus_character.ps1 -Character gray
./training/fold_focused.ps1 -Promote          # combine ONCE, at the end

# properly powered measurement (2000 matches in ~6 min instead of ~25)
./training/eval_parallel.ps1

# which TEAMS does the frozen policy win with? (eval_mode forced on, no learning)
./training/team_tournament.ps1 -Mode discovery -Rounds 8
./training/team_tournament.ps1 -Mode refinement

# gated copy to live (>=55% vs priority AND contextual_v2 from elo.json; -Force overrides)
./training/promote.ps1 -Generation 5
```

Opponent modes: `self | random | priority | contextual_v2 | policy:PATH`, with `gen:N` as sugar for
`policy:res://training/checkpoints/gen_N.json` (`bot_trainer.gd:154-163`).

> [!danger] Every run in a focus batch must start from the SAME baseline
> `merge` measures each input as *(its updates − the base's updates)*. Promoting mid-batch re-bases
> the later runs and silently mis-attributes every delta, with no error anywhere. Run the whole
> batch **without** `-Promote`, fold once, then promote — and after a fold+promote the batch is
> **closed**. This is enforced, not just documented: `focus_character.ps1` writes
> `focus_<char>/meta.json` with the baseline's SHA-256 and `fold_focused.ps1` refuses mismatched
> bases.

> [!warning] The Elo ledger is not a ranking
> Generations only ever play the fixed baselines, never each other, so each new generation beats an
> opponent its predecessors already dragged down (priority 972→956, contextual_v2 967→954 in one
> 3-round run). It measures **baseline decay**. Use head-to-head via `--opponent=gen:N`.
> Similarly, the promotion gate is uninformative — every generation clears it.

**Ground truth benchmarks** (all n≈2000, `eval_parallel`): gen_8 vs priority 72.0% [70.0, 73.9];
shared-layer-only vs gen_8 44.1% [41.9, 46.2]; gen_11 vs gen_8 50.8%. Eval power: n=300 gives ~14%
power to detect 3pp; ~2,200 matches are needed for 80%. Earlier n=150/200 reads of 76.0% and 66.5%
were both just noise around 72%.

## Current state

- **Live `bot_policy.json` is legacy-lineage gen_4** (~8,000 matches) and has never been promoted
  past it. Every subsequent experiment was a null or was not shipped.
- `training/checkpoints/` holds the shaped arm; `checkpoints/control_noshaping/` the same seed
  without shaping; `checkpoints/legacy_pre_semantic/` the original 11 generations. `elo.json` is the
  new lineage's; `elo_pre_semantic.json` the old one. `training/backups/pre_coldstart_*/` is a full
  backup **including** the live policy.
- Partial evidence the policies are genuinely *different* rather than a converged attractor: an
  argmax-agreement probe found all four checkpoints disagreeing on at least one of ability/target in
  every sampled state. So these look like distinct policies of equal strength, and **the ceiling
  probably belongs to the game** (team draw / energy RNG deciding a large share of matches) rather
  than to the learner.
- The suggested next step is therefore **measuring the ceiling**, not another policy tweak: play a
  fixed matchup repeatedly with the same policy on both sides and quantify how much of the outcome
  is decided regardless of play.

### Two known latent issues

> [!warning] Dead entry-centered gradient
> `select()` computes the entry-centered gradient and stores it as `picked["phi_a_egrad"]` /
> `phi_t_egrad` (`training/bot_policy.gd:574-575`), but `apply_returns` reads
> `r.get("phi_a_e", r["phi_a"])` / `phi_t_e` (`:629-630`). **The keys do not match**, so the
> entry-centered gradient is dead code and the per-entry layer trains on the fallback array. Note
> per-entry `bias` learns strongly (+1.243) while shared `bias` is dead at 1e-16, so the two layers
> demonstrably receive different arrays — trace which before "fixing" the key, since the current
> behaviour is what produced the +9.1pp focused win.

`training/tests/policy_agreement_probe.gd` is written but flaky: several character `.tscn` files
carry broken `ext_resource` UIDs (kitara, orihime, …) and `Character.from_character_name` errors on
them, killing the run before the summary prints.

## Tooling traps

- **`godot --import` does NOT compile unloaded scripts.** A parse error in a new file survives it
  silently (cost a 30-minute hang). Use `--check-only --script res://path.gd` per file. Scripts that
  reference autoloads false-fail that check — run the scene to truly verify those. See
  [[Verification Playbook]] and [[Adding a Playable Character]].
- **PowerShell 5.1 + BOM-less UTF-8**: em-dashes inside double-quoted strings decode to a smart
  quote (U+201D) that **terminates the string**, producing cascading parse errors far from the real
  site. Keep `.ps1` files strictly ASCII.
- **Never name a PowerShell parameter `-Matches`.** `$Matches` is the automatic regex-capture
  variable and `-match` silently clobbers it mid-loop. The param is `-MatchesPerWorker`. (Hit twice
  in one session.)
- `[Math]::Max(0, x)` binds the **int** overload and rounds a double bound — use `0.0` / `1.0`.
  This printed "[0%, 100%]" for every confidence interval until caught.
- **`entry["w"]` is a name-keyed dict on disk** (feature name → value), not a list — that is the
  schema-migration design. Iterating it yields feature *names*. Never wrap a parse in a swallow-all
  `except` when the result feeds a conclusion; doing so once produced the false conclusion
  "per-entry weights are exactly zero after 12,546 updates".
- **The team-tournament off-by-one**: `_match_index += 1` happens at the *top* of `_setup_match`,
  before `_sample_teams` is called, so it is already 1-based when the schedule is read. Indexing raw
  skipped row 0 and ran one past the end. The tell was arithmetic — 12 matches must produce 24 W/L
  credits and it produced 22. **Always check that per-contestant W+L sums to 2× matches.**

Related: [[Matchmaking and the Ladder]], [[Admin and Live Ops]], [[The Turn Pipeline]],
[[Targeting and Main Target]], [[Verification Playbook]], [[Traps That Have Bitten Us]],
[[Anime Arena]].
