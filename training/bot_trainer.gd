extends Node
class_name BotTrainerV3

# ============================================================================
# v3 headless self-play trainer (spec: .claude/plans/bot-training-v3.md §4).
#
# Clean rewrite of the TestBattleHeadless pattern with no UI nodes:
#   - fully SEEDED: --seed drives per-match seeds (hash(seed, match_idx)),
#     team sampling, first-mover coin, and the policy's softmax — same seed +
#     same flags ⇒ byte-identical run;
#   - whole-match-per-frame driving (turns are synchronous under shadow_mode;
#     frame boundaries are only needed BETWEEN matches so queue_free settles);
#   - per-turn shaped rewards + γ-discounted returns (fixes v2's whole-match
#     ±reward), applied via BotPolicyV3.apply_returns;
#   - JSONL match log, coverage-biased team sampling, .replay emission the
#     web client's local-file viewer plays as-is, Elo ledger for eval runs,
#     checkpoints + training_status.json for the dashboard.
#
# Run (via training/run_trainer.ps1):
#   godot --headless --path <repo> res://training/trainer_scene.tscn -- \
#     --matches=500 --seed=42 --opponent=self --out=res://training/checkpoints/work.json
#
# Flags (all optional; defaults below or in res://training/trainer_config.json):
#   --matches=N --seed=N --checkpoint=PATH --out=PATH --opponent=MODE
#   --eval --variety=N --save-interval=N --replay-every=N --t-start=F --t-end=F
#   --log=PATH --max-turns=N --balanced-frac=F --elo-a=NAME --elo-b=NAME
#   --gamma=F --verbose
#   MODE: self | random | priority | contextual_v2 | policy:PATH
# ============================================================================

enum Phase { IDLE, SETUP, RUN, SETTLE, FINISH }

const CONFIG_PATH := "res://training/trainer_config.json"
const STATUS_PATH := "res://training/training_status.json"
const COVERAGE_PATH := "res://training/coverage.json"
const ELO_PATH := "res://training/elo.json"
const REPLAY_DIR := "res://training/replays/"
const LOG_DIR := "res://training/logs/"

# --- run config (defaults; trainer_config.json then CLI override) -----------
var num_matches := 100
var run_seed := 0                  # 0 = derive from clock (always printed)
var checkpoint_path := ""          # "" = fresh policy
var out_path := "res://training/checkpoints/work.json"
var opponent_mode := "self"
var eval_mode := false

# --- TEAM TOURNAMENT ---------------------------------------------------------
# Per-character training plateaued, so this asks a different and much more directly
# measurable question: which TEAMS does the current policy actually win with?
#
#   discovery  - build N colour-balanced teams (the client's "randomise team" rule),
#                round-robin them, and bank the best into a persistent pool.
#   refinement - draw up to N teams FROM that pool, round-robin them against each
#                other, and cull anything that can't hold its own among peers.
#
# Both formats use ONE fixed policy for every contestant, so the only variable is the
# team. Sides alternate within every pairing: this engine has a documented seat
# advantage (the enemy seat's first-turn energy), and without alternating we would be
# measuring seat luck as if it were team strength.
var tournament_mode := ""            # "" | "discovery" | "refinement"
var tournament_contestants := 10
var tournament_games := 6            # games per unordered pairing (rounded up to even)
var tournament_pool_path := "res://training/team_pool.json"
var tournament_keep_top := 1         # discovery: how many finishers to bank
var tournament_cull_below := 0.40    # refinement: drop teams under this win rate
var _tourney_teams: Array = []       # Array[Array[String]] - contestant index -> team
var _tourney_sched: Array = []       # match index -> [team_a_idx, team_b_idx]
var _tourney_w: Array = []           # contestant index -> wins
var _tourney_l: Array = []
var _tourney_d: Array = []
var variety_interval := 0          # every Nth match, side 1 plays uniform random
var save_interval := 50
var replay_every := 0              # 0 = never
var t_start := 1.0                 # softmax temperature schedule (training)
var t_end := 0.2
var eval_temperature := 0.0
var log_path := ""                 # "" = LOG_DIR/run_<seed>.jsonl
var max_turns := 500               # draw valve (half-turns, matches old harness)
var balanced_frac := 0.25          # fraction of matches drafted color-balanced
var elo_name_a := ""
var elo_name_b := ""
var verbose := false
var excluded_characters: Array = ["vessel"]
# Per-match persistent exploration (parameter-space noise). 0 = off, which is the
# pre-existing behaviour exactly.
var explore_sigma := 0.0
# Force one character onto the training side every match, to concentrate updates
# on its data-starved per-entry weights. "" = uniform/coverage sampling as before.
var focus_character := ""
# Parallel-worker overrides: each orchestrator worker gets its own coverage +
# status file so concurrent processes never clobber shared state.
var coverage_path := COVERAGE_PATH
var status_path := STATUS_PATH
# Merge mode: --merge=a.json,b.json,... folds worker checkpoints into --out
# and exits (no matches). --merge-base=PATH is the shared parent checkpoint
# (update counts merge as base + sum-of-deltas). --merge-coverage=... sums
# worker coverage deltas over the base at coverage_path.
var merge_paths: Array = []
var merge_base_path := ""
var merge_coverage_paths: Array = []

# reward shaping (spec §3)
var gamma := 0.92
# Multiplier on the potential-based shaping term. 0.0 reproduces the pre-shaping
# reward EXACTLY, which is what makes a clean A/B possible from one binary.
var phi_scale := 1.0
var hp_scale := 0.01
var kill_bonus := 0.5
var death_penalty := 0.5
var win_bonus := 2.0
var loss_penalty := 2.0
var draw_penalty := 0.5

# --- run state ---------------------------------------------------------------
var policy: BotPolicyV3
var policy_b = null                # BotPolicyV3 for opponent_mode policy:PATH
var contextual_v2 = null           # frozen BotContextualModel baseline
var run_rng := RandomNumberGenerator.new()
var coverage: Dictionary = {}
var _phase: int = Phase.IDLE
var _settle_frames := 0
var _match_index := 0
var _wins := 0
var _losses := 0
var _draws := 0
var _log_file: FileAccess = null

# --- per-match state ---------------------------------------------------------
var manager: BattleManager = null
var _match_rng := RandomNumberGenerator.new()
var _match_seed := 0
var _team_a: Array = []
var _team_b: Array = []
var _match_running := false
var _pending_side := -1            # set by turn signals; -1 = none
var _draw_pending := false
var _winner_side := -1             # 0 / 1 / -1 draw
var _turn_count := 0
var _random_side := -1             # variety override for this match
var _rewards := {0: [], 1: []}     # per side: shaped reward per own turn
var _records := {0: [], 1: []}     # per side: policy action records (learning)
var _open_window := {0: null, 1: null}
var _recorder = null               # MatchEventRecorder when replaying
var _replay_log = null             # MatchReplayLog when replaying


func _ready():
	_load_config_file()
	_apply_cli(OS.get_cmdline_user_args())
	if not merge_paths.is_empty():
		_run_merge()
		return
	# gen:N is sugar for policy:<checkpoint path>; any other unknown mode must
	# HARD-FAIL — an unrecognized string would silently fall through to a
	# self-mirror in _dispatch, corrupting eval results and the Elo ledger.
	if opponent_mode.begins_with("gen:"):
		opponent_mode = "policy:res://training/checkpoints/gen_%d.json" % int(opponent_mode.substr(4))
	if not (opponent_mode in ["self", "random", "priority", "contextual_v2"] or opponent_mode.begins_with("policy:")):
		push_error("[trainer] Unknown --opponent=%s (use self|random|priority|contextual_v2|policy:PATH|gen:N)" % opponent_mode)
		get_tree().quit(1)
		return
	if opponent_mode.begins_with("policy:") and not FileAccess.file_exists(opponent_mode.substr(7)):
		push_error("[trainer] Opponent checkpoint not found: %s" % opponent_mode.substr(7))
		get_tree().quit(1)
		return
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system()) & 0x7fffffff
	run_rng.seed = run_seed
	print("[trainer] seed=%d matches=%d opponent=%s eval=%s out=%s checkpoint=%s" % [
		run_seed, num_matches, opponent_mode, eval_mode, out_path,
		checkpoint_path if checkpoint_path != "" else "(fresh)"])

	policy = BotPolicyV3.load_from_path(checkpoint_path) if checkpoint_path != "" else BotPolicyV3.new()
	if policy == null:
		push_error("[trainer] Checkpoint %s exists but failed to load — refusing to run" % checkpoint_path)
		get_tree().quit(1)
		return
	if opponent_mode.begins_with("policy:"):
		policy_b = BotPolicyV3.load_from_path(opponent_mode.substr(7))
		if policy_b == null:
			push_error("[trainer] Opponent checkpoint failed to load — refusing to run")
			get_tree().quit(1)
			return
	elif opponent_mode == "contextual_v2":
		contextual_v2 = BotContextualModel.load_from_disk()
	_load_coverage()

	if log_path == "":
		log_path = LOG_DIR + "run_%d.jsonl" % run_seed
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPLAY_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	_log_file = FileAccess.open(log_path, FileAccess.WRITE)
	# A tournament is a measurement, never a training run: the policy must not move
	# under the contestants or later pairings would be judged by a different bot.
	if tournament_mode != "":
		eval_mode = true
		_setup_tournament()
	_phase = Phase.SETUP


var _idle_frames := 0


func _process(_delta):
	match _phase:
		Phase.IDLE:
			# _ready() sets SETUP as its last statement; still IDLE after 60
			# frames means initialization crashed — quit instead of hanging an
			# orchestrated run forever (a parse-error hang cost us 30 minutes
			# once; never again).
			_idle_frames += 1
			if _idle_frames > 60:
				push_error("[trainer] initialization failed (still IDLE) — quitting")
				get_tree().quit(1)
		Phase.SETUP:
			_setup_match()
		Phase.RUN:
			_drive_match()
		Phase.SETTLE:
			_settle_frames -= 1
			if _settle_frames <= 0:
				_phase = Phase.SETUP if _match_index < num_matches else Phase.FINISH
		Phase.FINISH:
			_finish_run()


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

func _load_config_file():
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		push_warning("[trainer] %s is not valid JSON — ignoring" % CONFIG_PATH)
		return
	for key in parsed.keys():
		if key in self:
			set(key, parsed[key])


func _apply_cli(args: PackedStringArray):
	for raw in args:
		var arg := String(raw)
		var key := arg
		var value := ""
		var eq := arg.find("=")
		if eq >= 0:
			key = arg.substr(0, eq)
			value = arg.substr(eq + 1)
		match key:
			"--matches":        num_matches = int(value)
			"--seed":           run_seed = int(value)
			"--checkpoint":     checkpoint_path = value
			"--out":            out_path = value
			"--opponent":       opponent_mode = value
			"--eval":           eval_mode = true
			"--variety":        variety_interval = int(value)
			"--save-interval":  save_interval = int(value)
			"--replay-every":   replay_every = int(value)
			"--t-start":        t_start = float(value)
			"--t-end":          t_end = float(value)
			"--log":            log_path = value
			"--max-turns":      max_turns = int(value)
			"--balanced-frac":  balanced_frac = float(value)
			"--elo-a":          elo_name_a = value
			"--elo-b":          elo_name_b = value
			"--gamma":          gamma = float(value)
			"--phi-scale":      phi_scale = float(value)
			"--tournament":     tournament_mode = value
			"--contestants":    tournament_contestants = int(value)
			"--games":          tournament_games = int(value)
			"--pool":           tournament_pool_path = value
			"--keep-top":       tournament_keep_top = int(value)
			"--cull-below":     tournament_cull_below = float(value)
			"--explore-sigma":  explore_sigma = float(value)
			"--focus":          focus_character = value
			"--coverage":       coverage_path = value
			"--status":         status_path = value
			"--merge":          merge_paths = value.split(",")
			"--merge-base":     merge_base_path = value
			"--merge-coverage": merge_coverage_paths = value.split(",")
			"--verbose":        verbose = true
			_:
				push_warning("[trainer cli] Unknown arg: %s" % arg)


# ---------------------------------------------------------------------------
# Match lifecycle
# ---------------------------------------------------------------------------

func _setup_match():
	_match_index += 1
	_match_seed = int(hash("%d:%d" % [run_seed, _match_index])) & 0x7fffffff
	_match_rng.seed = _match_seed + 1
	# The legacy opponent policies (perform_turn_random / priority / the v2
	# contextual model) draw from the GLOBAL RNG. Re-seeding it per match keeps
	# --variety and baseline-opponent runs reproducible too.
	seed(_match_seed + 99)
	_random_side = 1 if (variety_interval > 0 and _match_index % variety_interval == 0) else -1

	var teams := _sample_teams(_match_rng)
	_team_a = teams[0]
	_team_b = teams[1]

	manager = BattleManager.new()
	manager.name = "BattleManager"
	manager.shadow_mode = true
	add_child(manager)
	manager.turn_started.connect(_on_turn_started)
	manager.waiting_for_opponent.connect(_on_waiting_for_opponent)
	manager.match_ended.connect(_on_match_ended)
	manager.random_panel_needed.connect(_on_random_panel_needed)

	var p1 := _build_player("BotPlayer", _team_a)
	var p2 := _build_player("BotEnemy", _team_b)

	# Draw this match's persistent exploration perturbation over the TRAINING
	# side's kits. Sampled once here and held for the whole match, so the bot plays
	# a consistent variant of itself and a multi-turn setup -> payoff sequence can
	# actually be attempted (and therefore credited) as a unit.
	if explore_sigma > 0.0 and not eval_mode:
		var kit: Array = []
		for c in p1.team.characters:
			for a in c.moveset.abilities:
				if a != null:
					kit.append([c.path_name, a.ability_name])
		policy.sample_exploration(kit, explore_sigma, _match_rng)
	else:
		policy.clear_exploration()

	_match_running = true
	_pending_side = -1
	_draw_pending = false
	_winner_side = -1
	_turn_count = 0
	_rewards = {0: [], 1: []}
	_records = {0: [], 1: []}
	_open_window = {0: null, 1: null}

	_recorder = null
	_replay_log = null
	if replay_every > 0 and _match_index % replay_every == 0:
		_recorder = MatchEventRecorder.new()
		_recorder.attach(manager)
		_replay_log = MatchReplayLog.new()
		# Zero-padded index so lexicographic listings (the dashboard) stay
		# chronological across the 1000-match digit boundary.
		_replay_log.match_id = "train_%d_%06d" % [run_seed, _match_index]
		_replay_log.match_type = int(BattleManager.MatchType.BOT)
		_replay_log.date = Time.get_datetime_dict_from_system()
		_replay_log.p1_username = "v3 (gen %d)" % policy.generation
		_replay_log.p2_username = _opponent_label()
		_replay_log.p1_characters = _team_a.duplicate()
		_replay_log.p2_characters = _team_b.duplicate()

	var first := _match_rng.randi_range(0, 1) == 1
	if _replay_log != null:
		_replay_log.first_player_role = "p1" if first else "p2"
	manager.start_battle(p1, p2, first, _match_seed, BattleManager.MatchType.BOT)
	if _replay_log != null:
		_replay_log.record_initial_snapshot(manager.serialize_wire_snapshot())
		if _recorder != null:
			_recorder.clear()
	_phase = Phase.RUN


func _drive_match():
	var steps := 0
	while _match_running and steps < 60:
		if _draw_pending:
			_force_draw()
			break
		if _pending_side == -1:
			break   # waiting on a signal that hasn't fired — let the frame end
		var side := _pending_side
		_pending_side = -1
		await _dispatch(side)
		steps += 1
	if not _match_running:
		_finish_match()


func _dispatch(side: int):
	if manager == null or manager.match_over:
		return
	# Close the previous reward window for this side (everything that happened
	# between its last turn start and now), then open a fresh one.
	if _open_window[side] != null:
		_rewards[side].append(_shaped_reward(side, _open_window[side]))
	_open_window[side] = _state_snapshot(side)
	var t_idx: int = _rewards[side].size()

	var player_obj = manager.player if side == 0 else manager.enemy
	if side == 1:
		# wait_for_turn PRE-GENERATES the enemy's energy on the shadow and
		# latches acting_energy_prepared (battle_manager.gd:585, 1478-1491).
		# Generating unconditionally here — the old harness's pattern — double
		# -fed the enemy seat its first-turn energy, a measurable ~59/41 seat
		# skew in self-play mirrors (and a bias the v2 model trained under).
		# Respect the latch, then CONSUME it the way process_turn_package does,
		# so the next wait_for_turn pre-generates again: exactly one roll per
		# enemy turn in every flow, including bot-first openings.
		if not manager.acting_energy_prepared:
			manager.generate_team_energy(manager.enemy.team, manager.went_second)
		manager.acting_energy_prepared = false
		manager.went_second = false
	if verbose:
		var pool: Dictionary = (manager.player if side == 0 else manager.enemy).team.energy.true_pool()
		var pool_total := 0
		for v in pool.values():
			pool_total += int(v)
		print("[energy] turn=%d side=%d pool_total=%d %s" % [_turn_count, side, pool_total, str(pool)])

	var learn := _side_learns(side)
	if _random_side == side:
		player_obj.perform_turn_random(manager, null, side)
	elif side == 1 and opponent_mode == "random":
		# NOTE: perform_turn_random draws from the global RNG, so runs against
		# the random baseline are not seed-reproducible (the v3 side still is).
		player_obj.perform_turn_random(manager, null, side)
	elif side == 1 and opponent_mode == "priority":
		player_obj.perform_turn(manager)
	elif side == 1 and opponent_mode == "contextual_v2":
		player_obj.perform_turn_contextual(manager, contextual_v2, side)
	elif side == 1 and policy_b != null:
		var recs_b: Array = await player_obj.perform_turn_v3(manager, policy_b, _match_rng, eval_temperature, null, false)
		recs_b.clear()
	else:
		var temp := _current_temperature()
		var recs: Array = await player_obj.perform_turn_v3(manager, policy, _match_rng, temp, null, learn)
		for r in recs:
			r["t_idx"] = t_idx
			r["side"] = side
		if learn:
			_records[side].append_array(recs)

	if _replay_log != null and _recorder != null:
		_replay_log.record_turn(_recorder.events.duplicate(), manager.serialize_wire_snapshot())
		_recorder.clear()


## Which sides update the policy this run. Eval runs never learn; self-play
## trains both seats, every other mode trains only side 0.
func _side_learns(side: int) -> bool:
	if eval_mode:
		return false
	if _random_side == side:
		return false
	if side == 0:
		return true
	return opponent_mode == "self"


func _current_temperature() -> float:
	if eval_mode:
		return eval_temperature
	var progress := float(_match_index - 1) / float(maxi(num_matches - 1, 1))
	# Floor at 0.05: a training schedule that touches 0 flips selection to
	# argmax, whose picks carry no gradient and are (deliberately) not
	# recorded — the run would silently stop learning.
	return maxf(lerpf(t_start, t_end, progress), 0.05)


func _force_draw():
	_match_running = false
	if manager != null:
		manager.match_over = true
	_winner_side = -1


func _finish_match():
	# Close both sides' final windows, then attach terminal bonuses.
	for side in [0, 1]:
		if _open_window[side] != null:
			# terminal=true: PHI of the absorbing state must be 0 or the shaping
			# stops being policy-invariant on the final transition.
			_rewards[side].append(_shaped_reward(side, _open_window[side], true))
			_open_window[side] = null
		var terminal := 0.0
		if _winner_side == -1:
			terminal = -draw_penalty
		elif _winner_side == side:
			terminal = win_bonus
		else:
			terminal = -loss_penalty
		var rlist: Array = _rewards[side]
		if rlist.size() > 0:
			rlist[rlist.size() - 1] += terminal

	# γ-discounted returns per record, then one learning pass.
	if not eval_mode:
		var updates: Array = []
		for side in [0, 1]:
			if _records[side].is_empty():
				continue
			var returns := _returns_for(_rewards[side])
			for r in _records[side]:
				var idx: int = mini(r["t_idx"], returns.size() - 1)
				if idx < 0:
					continue
				r["G"] = returns[idx]
				updates.append(r)
		if not updates.is_empty():
			policy.apply_returns(updates)
		policy.trained_matches += 1

	if _winner_side == 0:
		_wins += 1
	elif _winner_side == 1:
		_losses += 1
	else:
		_draws += 1

	# Credit the CONTESTANTS, not the seats. Same 1-based offset as _sample_teams:
	# the row just played is _match_index - 1.
	if tournament_mode != "":
		var trow := _match_index - 1
		if trow >= 0 and trow < _tourney_sched.size():
			_tally_tournament(_tourney_sched[trow])

	for char_name in _team_a + _team_b:
		coverage[char_name] = int(coverage.get(char_name, 0)) + 1

	var result := "WIN" if _winner_side == 0 else ("LOSS" if _winner_side == 1 else "DRAW")
	print("[%4d/%-4d] %-4s  %3d turns   %s  vs  %s" % [
		_match_index, num_matches, result, _turn_count,
		", ".join(_team_a), ", ".join(_team_b)])
	if _log_file != null:
		_log_file.store_line(JSON.stringify({
			"i": _match_index, "seed": _match_seed, "result": result,
			"turns": _turn_count, "team_a": _team_a, "team_b": _team_b,
			"opponent": _opponent_label(),
			"r_a": _sum(_rewards[0]), "r_b": _sum(_rewards[1]),
		}))

	if _replay_log != null:
		_replay_log.winner_role = "p1" if _winner_side == 0 else ("p2" if _winner_side == 1 else "")
		_write_replay()

	if manager != null:
		manager.queue_free()
		manager = null

	if not eval_mode and save_interval > 0 and _match_index % save_interval == 0:
		policy.save_to_path(out_path)
		_save_coverage()
		_write_status(false)

	_settle_frames = 2
	_phase = Phase.SETTLE


func _finish_run():
	_phase = Phase.IDLE
	var total := _wins + _losses + _draws
	var win_rate := float(_wins) / float(maxi(total, 1)) * 100.0
	print("=== TRAINER RUN COMPLETE ===")
	print("Matches: %d   W: %d   L: %d   D: %d   Win: %.1f%%   (opponent: %s%s)" % [
		total, _wins, _losses, _draws, win_rate, _opponent_label(),
		"  [EVAL]" if eval_mode else ""])
	if tournament_mode != "":
		_finish_tournament()
	elif not eval_mode:
		policy.save_to_path(out_path)
		print("Policy saved to %s  (generation %d, trained_matches %d)" % [
			out_path, policy.generation, policy.trained_matches])
		_save_coverage()
	elif elo_name_a != "" or elo_name_b != "":
		_update_elo()
	_write_status(true)
	if _log_file != null:
		_log_file.close()
	get_tree().quit(0)


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func _on_turn_started(_is_player_turn: bool):
	if not _match_running:
		return
	_turn_count += 1
	if _turn_count >= max_turns:
		_draw_pending = true
		return
	_pending_side = 0


func _on_waiting_for_opponent():
	if not _match_running:
		return
	_turn_count += 1
	if _turn_count >= max_turns:
		_draw_pending = true
		return
	_pending_side = 1


func _on_match_ended(won: bool):
	_match_running = false
	_winner_side = 0 if won else 1


func _on_random_panel_needed(_team, _random_count, exec_order: Dictionary):
	var order: Array = []
	for key in exec_order.keys():
		order.append(key)
	manager.allotment_accepted(order, [])


# ---------------------------------------------------------------------------
# Rewards
# ---------------------------------------------------------------------------

## Full-state read is deliberate here: reward shaping is the score of the
## game, not the policy's eyes — only BotPolicyV3's INPUTS are parity-bound.
func _state_snapshot(side: int) -> Dictionary:
	var own_team = manager.player.team if side == 0 else manager.enemy.team
	var other_team = manager.enemy.team if side == 0 else manager.player.team
	# Banished characters count as alive-with-their-HP: banish is usually
	# TEMPORARY, and excluding them paid a fake full-kill reward on banish and
	# charged the reversal to whatever unrelated action was in the open window
	# when the effect expired. Banish value is learned through its downstream
	# effects (and the terminal, since full-team banish still ends the match).
	var s := {"own_hp": 0, "own_alive": 0, "enemy_hp": 0, "enemy_alive": 0, "phi": 0.0}
	for c in own_team.characters:
		if not c.dead:
			s["own_hp"] += c.health.hp
			s["own_alive"] += 1
	for c in other_team.characters:
		if not c.dead:
			s["enemy_hp"] += c.health.hp
			s["enemy_alive"] += 1
	s["phi"] = _potential(side)
	return s


## POTENTIAL-BASED shaping term (Ng, Harada & Russell 1999).
##
## The naive way to teach the bot that control matters is a bonus for APPLYING a
## debuff. That is reward hacking waiting to happen: re-applying a cheap debuff
## every turn farms the bonus forever and never closes the game out, and no choice
## of magnitude fixes it - it only moves the break-even point.
##
## Shaping of the form F = gamma*PHI(s') - PHI(s) is PROVABLY POLICY-INVARIANT: the
## set of optimal policies is unchanged for ANY potential PHI. Farming is impossible
## by construction, because a round trip s -> s' -> s contributes
## gamma*PHI(s')-PHI(s) + gamma*PHI(s)-PHI(s') = -(1-gamma)*(PHI(s)+PHI(s')) <= 0
## for a non-negative potential. What it DOES buy is credit assignment: a stun is
## paid at the moment it lands instead of diffusing into a gamma-discounted future
## HP difference that the learner can barely see.
##
## PHI is measured in the same units as the HP term (hp_scale = 0.01, so 100 HP =
## 1.0, and kill_bonus = 0.5). The weights are deliberately SMALL relative to a kill:
## PHI is here to time the credit, not to add value that competes with winning.
const PHI_CONTROL := 0.12      # an enemy that cannot act
const PHI_AMPLIFY := 0.06      # an enemy made more fragile (weakness / vulnerability / broken defense)
const PHI_REACTIVE := 0.05     # my own counter / reflect armed
const PHI_ENEMY_GUARD := 0.06  # SUBTRACTED: an enemy behind a shield / DR / invuln is worth less to hit

const PHI_CONTROL_TYPES: Array[int] = [
	EffectType.Type.STUN, EffectType.Type.COST_STUN, EffectType.Type.FALSE_STUN,
	EffectType.Type.PARALYZE, EffectType.Type.SILENCE, EffectType.Type.ISOLATE,
	EffectType.Type.TAUNT, EffectType.Type.BLIND, EffectType.Type.BANISH,
]
const PHI_AMPLIFY_TYPES: Array[int] = [
	EffectType.Type.VULNERABILITY, EffectType.Type.DEF_NEGATE,
]
const PHI_REACTIVE_TYPES: Array[int] = [
	EffectType.Type.COUNTER_USE, EffectType.Type.COUNTER_RECEIVE,
	EffectType.Type.REFLECT_USE, EffectType.Type.REFLECT_RECEIVE,
]
const PHI_GUARD_TYPES: Array[int] = [
	EffectType.Type.SHIELD, EffectType.Type.DAMAGE_REDUCTION, EffectType.Type.INVULN,
	EffectType.Type.DAMAGE_NULLIFICATION, EffectType.Type.PERCENT_DR,
	EffectType.Type.IGNORE_DAMAGE,
]

## Presence, scaled mildly by how long it has left to run, so a long stun is worth
## more than a expiring one. Floor of 0.5 keeps mere presence meaningful. Returns 0
## when none of `types` is on the character.
func _phi_term(character, types: Array[int]) -> float:
	var best := -1
	for t in types:
		for e in character.effects.get_effects_by_type(t):
			best = maxi(best, int(e.duration) if typeof(e.duration) == TYPE_INT else 1)
	if best < 0:
		return 0.0
	return 0.5 + 0.5 * minf(float(maxi(best, 0)) / 6.0, 1.0)

## Full-state read, same justification as _state_snapshot: shaping is the score of
## the game, not the policy's eyes.
func _potential(side: int) -> float:
	if phi_scale == 0.0:
		return 0.0
	var own_team = manager.player.team if side == 0 else manager.enemy.team
	var other_team = manager.enemy.team if side == 0 else manager.player.team
	var phi := 0.0
	for c in other_team.characters:
		if c.dead:
			continue
		phi += PHI_CONTROL * _phi_term(c, PHI_CONTROL_TYPES)
		phi += PHI_AMPLIFY * _phi_term(c, PHI_AMPLIFY_TYPES)
		phi -= PHI_ENEMY_GUARD * _phi_term(c, PHI_GUARD_TYPES)
	for c in own_team.characters:
		if c.dead:
			continue
		phi += PHI_REACTIVE * _phi_term(c, PHI_REACTIVE_TYPES)
	return phi * phi_scale


## terminal=true forces PHI(s')=0. The telescoping only cancels exactly if the
## potential of the absorbing state is zero; leaving it non-zero would smuggle a
## real (non-invariant) bonus into the last transition of every match.
func _shaped_reward(side: int, before: Dictionary, terminal := false) -> float:
	var after := _state_snapshot(side)
	var after_phi: float = 0.0 if terminal else float(after["phi"])
	return (before["enemy_hp"] - after["enemy_hp"]) * hp_scale \
		- (before["own_hp"] - after["own_hp"]) * hp_scale \
		+ kill_bonus * (before["enemy_alive"] - after["enemy_alive"]) \
		- death_penalty * (before["own_alive"] - after["own_alive"]) \
		+ (gamma * after_phi - float(before["phi"]))


func _returns_for(rewards: Array) -> Array:
	var returns: Array = []
	returns.resize(rewards.size())
	var acc := 0.0
	for i in range(rewards.size() - 1, -1, -1):
		acc = float(rewards[i]) + gamma * acc
		returns[i] = acc
	return returns


static func _sum(arr: Array) -> float:
	var total := 0.0
	for v in arr:
		total += float(v)
	return total


# ---------------------------------------------------------------------------
# Teams / players
# ---------------------------------------------------------------------------

func _roster() -> Array:
	var pool: Array = CharacterDatabase.char_name_list().duplicate()
	for name in excluded_characters:
		pool.erase(name)
	return pool


# --- team tournament ---------------------------------------------------------

## A team is an unordered SET of 3 characters, so the same trio in a different order
## must not enter the pool twice. Sorted-joined name is the identity.
static func team_key(team: Array) -> String:
	var t := team.duplicate()
	t.sort()
	return "|".join(t)


func _load_team_pool() -> Dictionary:
	if not FileAccess.file_exists(tournament_pool_path):
		return {"format": "aa-team-pool", "version": 1, "teams": []}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(tournament_pool_path))
	if not parsed is Dictionary or not (parsed.get("teams", null) is Array):
		push_warning("[tourney] pool at %s is unreadable - starting a fresh one" % tournament_pool_path)
		return {"format": "aa-team-pool", "version": 1, "teams": []}
	return parsed


func _save_team_pool(pool: Dictionary) -> void:
	var f := FileAccess.open(tournament_pool_path, FileAccess.WRITE)
	if f == null:
		printerr("[tourney] could not write %s" % tournament_pool_path)
		return
	f.store_string(JSON.stringify(pool, "\t"))
	f.close()


## Build the contestant list for this run, then a round-robin schedule over it.
func _setup_tournament() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	_tourney_teams = []
	if tournament_mode == "discovery":
		var pool_names := _roster()
		var seen := {}
		var guard := 0
		while _tourney_teams.size() < tournament_contestants and guard < tournament_contestants * 50:
			guard += 1
			var t = ColorBalancedDraft.build_team(pool_names, 3, [], excluded_characters, rng)
			if t.size() < 3:
				continue
			var k := team_key(t)
			if seen.has(k):
				continue            # two contestants with the same trio would just play mirrors
			seen[k] = true
			_tourney_teams.append(t)
	elif tournament_mode == "refinement":
		var pool := _load_team_pool()
		var entries: Array = (pool["teams"] as Array).duplicate()
		if entries.is_empty():
			printerr("[tourney] the pool is empty - run --tournament=discovery first")
			get_tree().quit(1)
			return
		# Random selection of up to N, so repeated refinement runs stress different
		# subsets of the pool rather than re-testing the same head every time.
		entries.shuffle()
		for e in entries.slice(0, mini(tournament_contestants, entries.size())):
			if e is Dictionary and e.get("chars", null) is Array and (e["chars"] as Array).size() == 3:
				_tourney_teams.append((e["chars"] as Array).duplicate())
	if _tourney_teams.size() < 2:
		printerr("[tourney] need at least 2 contestants, got %d" % _tourney_teams.size())
		get_tree().quit(1)
		return

	_tourney_w.resize(_tourney_teams.size()); _tourney_w.fill(0)
	_tourney_l.resize(_tourney_teams.size()); _tourney_l.fill(0)
	_tourney_d.resize(_tourney_teams.size()); _tourney_d.fill(0)

	# Round-robin. Each pairing plays an EVEN number of games with sides alternating,
	# so seat advantage cancels exactly instead of contaminating the ranking.
	var per_pair: int = maxi(2, tournament_games + (tournament_games % 2))
	_tourney_sched = []
	for i in range(_tourney_teams.size()):
		for j in range(i + 1, _tourney_teams.size()):
			for g in range(per_pair):
				_tourney_sched.append([i, j] if g % 2 == 0 else [j, i])
	num_matches = _tourney_sched.size()
	print("[tourney] %s: %d contestants, %d games/pairing -> %d matches" % [
		tournament_mode, _tourney_teams.size(), per_pair, num_matches])
	for i in range(_tourney_teams.size()):
		print("[tourney]   #%d  %s" % [i, ", ".join(_tourney_teams[i])])


## Record a finished tournament match. Called with the match's schedule row.
func _tally_tournament(row: Array) -> void:
	var a: int = int(row[0])
	var b: int = int(row[1])
	if _winner_side == 0:
		_tourney_w[a] += 1
		_tourney_l[b] += 1
	elif _winner_side == 1:
		_tourney_w[b] += 1
		_tourney_l[a] += 1
	else:
		_tourney_d[a] += 1
		_tourney_d[b] += 1


func _tourney_winrate(i: int) -> float:
	var n: int = _tourney_w[i] + _tourney_l[i]
	return float(_tourney_w[i]) / float(maxi(n, 1))


## Print the table and fold the result back into the persistent pool.
func _finish_tournament() -> void:
	var order: Array = []
	for i in range(_tourney_teams.size()):
		order.append(i)
	order.sort_custom(func(x, y): return _tourney_winrate(x) > _tourney_winrate(y))

	print("")
	print("=== %s RESULTS ===" % tournament_mode.to_upper())
	print("%-4s %-6s %-5s %-5s %-5s  %s" % ["rank", "win%", "W", "L", "D", "team"])
	for r in range(order.size()):
		var i: int = order[r]
		print("%-4d %5.1f%% %-5d %-5d %-5d  %s" % [
			r + 1, _tourney_winrate(i) * 100.0, _tourney_w[i], _tourney_l[i], _tourney_d[i],
			", ".join(_tourney_teams[i])])

	var pool := _load_team_pool()
	var teams: Array = pool["teams"]
	var by_key := {}
	for e in teams:
		if e is Dictionary:
			by_key[str(e.get("key", ""))] = e

	if tournament_mode == "discovery":
		var kept := 0
		for r in range(order.size()):
			if kept >= tournament_keep_top:
				break
			var i: int = order[r]
			var k := team_key(_tourney_teams[i])
			if by_key.has(k):
				# Already known: fold this run's record in rather than duplicating.
				var e: Dictionary = by_key[k]
				e["wins"] = int(e.get("wins", 0)) + _tourney_w[i]
				e["losses"] = int(e.get("losses", 0)) + _tourney_l[i]
				e["runs"] = int(e.get("runs", 0)) + 1
				print("[tourney] already in the pool, record folded in: %s" % ", ".join(_tourney_teams[i]))
			else:
				teams.append({
					"key": k, "chars": _tourney_teams[i],
					"wins": _tourney_w[i], "losses": _tourney_l[i], "runs": 1,
				})
				print("[tourney] BANKED: %s (%.1f%%)" % [", ".join(_tourney_teams[i]), _tourney_winrate(i) * 100.0])
			kept += 1
	elif tournament_mode == "refinement":
		var culled: Array = []
		for i in range(_tourney_teams.size()):
			var k := team_key(_tourney_teams[i])
			var e = by_key.get(k, null)
			if e == null:
				continue
			e["wins"] = int(e.get("wins", 0)) + _tourney_w[i]
			e["losses"] = int(e.get("losses", 0)) + _tourney_l[i]
			e["runs"] = int(e.get("runs", 0)) + 1
			if _tourney_winrate(i) < tournament_cull_below:
				culled.append(k)
				print("[tourney] CULLED %.1f%% < %.0f%%: %s" % [
					_tourney_winrate(i) * 100.0, tournament_cull_below * 100.0, ", ".join(_tourney_teams[i])])
			else:
				print("[tourney] held its own (%.1f%%): %s" % [_tourney_winrate(i) * 100.0, ", ".join(_tourney_teams[i])])
		if not culled.is_empty():
			var survivors: Array = []
			for e in teams:
				if e is Dictionary and not (str(e.get("key", "")) in culled):
					survivors.append(e)
			teams = survivors
			pool["teams"] = teams

	pool["teams"] = teams
	_save_team_pool(pool)
	print("[tourney] pool now holds %d team(s) -> %s" % [teams.size(), tournament_pool_path])


func _sample_teams(rng: RandomNumberGenerator) -> Array:
	# In tournament mode the matchup is SCHEDULED, not sampled.
	# _match_index is already 1-based here (incremented at the top of _setup_match), so
	# the schedule row is _match_index - 1. Using it raw skips row 0 and runs one past
	# the end, where the last match silently falls through to a RANDOM matchup.
	if tournament_mode != "":
		var row_i := _match_index - 1
		if row_i >= 0 and row_i < _tourney_sched.size():
			var row: Array = _tourney_sched[row_i]
			return [_tourney_teams[int(row[0])].duplicate(), _tourney_teams[int(row[1])].duplicate()]
	var pool := _roster()
	# CHARACTER FOCUS: force this character onto the TRAINING side every match, so
	# its per-entry weights see thousands of updates instead of the ~2 a uniformly
	# sampled 170-character roster gives them. Character-specific tricks (a setup
	# skill that unlocks a stronger one) can only be learned by the per-entry layer,
	# and that layer is currently too data-starved to learn anything.
	if focus_character != "" and focus_character in pool:
		var rest := pool.duplicate()
		rest.erase(focus_character)
		var mates: Array = [focus_character]
		for _i in range(2):
			var k: int = rng.randi_range(0, rest.size() - 1)
			mates.append(rest[k])
			rest.remove_at(k)
		var foes: Array = []
		for _i in range(3):
			var k2: int = rng.randi_range(0, rest.size() - 1)
			foes.append(rest[k2])
			rest.remove_at(k2)
		return [mates, foes]
	if rng.randf() < balanced_frac:
		var team_a = ColorBalancedDraft.build_team(pool, 3, [], excluded_characters, rng)
		var remaining := pool.duplicate()
		for name in team_a:
			remaining.erase(name)
		var team_b = ColorBalancedDraft.build_team(remaining, 3, [], excluded_characters, rng)
		return [team_a, team_b]
	# Coverage-biased sampling: under-trained characters get proportionally
	# more matches (weight 1/(1+picks)).
	var picked: Array = []
	for _i in range(6):
		var total := 0.0
		var weights: Array = []
		for name in pool:
			var w := 1.0 / (1.0 + float(coverage.get(name, 0)))
			weights.append(w)
			total += w
		var roll := rng.randf() * total
		var chosen_idx := pool.size() - 1
		for j in range(pool.size()):
			roll -= weights[j]
			if roll <= 0.0:
				chosen_idx = j
				break
		picked.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)
	return [picked.slice(0, 3), picked.slice(3, 6)]


func _build_player(username: String, char_names: Array) -> Player:
	var player_node: Player = load("res://components/player_component.tscn").instantiate()
	player_node.username = username
	player_node.set_username(username)
	player_node.mission_reference = {}
	player_node.mission_data = {}
	player_node.bot_player = true
	player_node.bot_difficulty = 70
	player_node.bot_turn_delay = 0
	var is_enemy := (username == "BotEnemy")
	for char_name in char_names:
		var character = Character.from_character_name(char_name)
		player_node.recruit_character(character, is_enemy)
	for character in player_node.team.characters:
		character.bot_character = true
	return player_node


func _opponent_label() -> String:
	if opponent_mode.begins_with("policy:"):
		return "v3:" + opponent_mode.substr(7).get_file()
	return opponent_mode


# ---------------------------------------------------------------------------
# Persistence side-files
# ---------------------------------------------------------------------------

func _load_coverage():
	if not FileAccess.file_exists(coverage_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(coverage_path))
	if parsed is Dictionary:
		coverage = parsed


func _save_coverage():
	var f := FileAccess.open(coverage_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(coverage, "\t"))
		f.close()


func _write_status(done: bool):
	var f := FileAccess.open(status_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"run_seed": run_seed,
		"opponent": _opponent_label(),
		"eval": eval_mode,
		"done": done,
		"matches_done": _wins + _losses + _draws,
		"num_matches": num_matches,
		"wins": _wins, "losses": _losses, "draws": _draws,
		"generation": policy.generation,
		"trained_matches": policy.trained_matches,
		"updated": Time.get_datetime_string_from_system(),
	}, "\t"))
	f.close()


func _write_replay():
	var path := REPLAY_DIR + "%s.replay" % _replay_log.match_id
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_line(JSON.stringify(_replay_log.to_dict()))
		f.close()
		if verbose:
			print("  [replay] %s (%d turns)" % [path, _replay_log.turn_count()])


## Merge mode: fold worker checkpoints into one next-generation policy and
## sum worker coverage deltas over the base coverage, then exit.
func _run_merge():
	var inputs: Array = []
	for p in merge_paths:
		var path := String(p).strip_edges()
		if path == "":
			continue
		if FileAccess.file_exists(path):
			var loaded = BotPolicyV3.load_from_path(path)
			if loaded != null:
				inputs.append(loaded)
			else:
				push_warning("[merge] unreadable worker checkpoint skipped: %s" % path)
		else:
			push_warning("[merge] missing worker checkpoint: %s" % path)
	if inputs.is_empty():
		push_error("[merge] no readable inputs — nothing merged")
		get_tree().quit(1)
		return
	var merge_base = null
	if merge_base_path != "" and FileAccess.file_exists(merge_base_path):
		merge_base = BotPolicyV3.load_from_path(merge_base_path)
	var merged := BotPolicyV3.merge(inputs, merge_base)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	merged.save_to_path(out_path)
	print("[merge] %d worker checkpoints -> %s  (generation %d, trained_matches %d, shared_updates %d)" % [
		inputs.size(), out_path, merged.generation, merged.trained_matches, int(merged.shared_updates)])
	# Coverage: new_master = base + Σ(worker - base). Workers each started
	# from a COPY of the base, so their files hold base + own delta.
	if not merge_coverage_paths.is_empty():
		var base: Dictionary = {}
		if FileAccess.file_exists(coverage_path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(coverage_path))
			if parsed is Dictionary:
				base = parsed
		var merged_cov: Dictionary = base.duplicate()
		for cp in merge_coverage_paths:
			var cpath := String(cp).strip_edges()
			if cpath == "" or not FileAccess.file_exists(cpath):
				continue
			var wc = JSON.parse_string(FileAccess.get_file_as_string(cpath))
			if not wc is Dictionary:
				continue
			for char_name in wc:
				var delta: int = int(wc[char_name]) - int(base.get(char_name, 0))
				if delta > 0:
					merged_cov[char_name] = int(merged_cov.get(char_name, 0)) + delta
		var f := FileAccess.open(coverage_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(merged_cov, "\t"))
			f.close()
	get_tree().quit(0)


## Sequential per-match Elo over this eval run's outcomes. "random" is the
## fixed anchor (never updated). K=16, unknowns start at 1000.
func _update_elo():
	var ledger := {"ratings": {}, "history": []}
	if FileAccess.file_exists(ELO_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ELO_PATH))
		if parsed is Dictionary:
			ledger = parsed
	if not ledger.has("ratings"):
		ledger["ratings"] = {}
	if not ledger.has("history"):
		ledger["history"] = []
	var a := elo_name_a if elo_name_a != "" else "gen_%d" % policy.generation
	var b := elo_name_b if elo_name_b != "" else _opponent_label()
	var ratings: Dictionary = ledger.get("ratings", {})
	var ra: float = float(ratings.get(a, 1000.0))
	var rb: float = float(ratings.get(b, 1000.0 if b != "random" else 800.0))
	# ONE aggregate update per eval block. Replaying grouped W-then-L-then-D
	# sequences does not commute: expectation saturates after the win block and
	# the trailing losses dominate, INVERTING the ladder (a 62%-winning gen
	# rated 250 points below its opponent — observed in the first ledger).
	var n := _wins + _losses + _draws
	var score := (_wins + 0.5 * _draws) / float(maxi(n, 1))
	var ea := 1.0 / (1.0 + pow(10.0, (rb - ra) / 400.0))
	var k := 32.0
	ra += k * (score - ea)
	if b != "random":
		rb += k * (ea - score)
	ratings[a] = ra
	ratings[b] = rb
	ledger["ratings"] = ratings
	ledger["history"].append({
		"a": a, "b": b, "w": _wins, "l": _losses, "d": _draws,
		"ra": ra, "rb": rb, "seed": run_seed,
		"date": Time.get_datetime_string_from_system(),
	})
	var f := FileAccess.open(ELO_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(ledger, "\t"))
		f.close()
	print("[elo] %s: %.0f   %s: %.0f" % [a, ra, b, rb])
