## Headless bot-vs-bot test runner with live UI dashboard.
##
## Runs automated matches using BattleManager with no battle display.
## Shows progress, win/loss stats, and per-character performance in a
## MarginContainer panel that stays responsive throughout the run.
##
## Setup:
##   Create a scene, add this as the root (or child of any container),
##   and run it.  Or call TestBattleHeadless.quick_start() from code.

extends MarginContainer
class_name TestBattleHeadless

# ===========================================================================
# CONFIGURATION
# ===========================================================================

## How many matches to run in sequence.
@export var num_matches := 250

## How many characters per team.
const TEAM_SIZE := 3

## Safety valve — force-end a match after this many turns.
const MAX_TURNS := 500

## Print turn-by-turn details to the console (Output tab).
@export var verbose := true

## Lock character pools (leave empty for fully random).
@export var player_team_override: Array[String] = []
@export var enemy_team_override: Array[String] = []

## Use contextual-bandits model (state-aware) instead of flat win-rate tracker.
## When true, bots use board features (HP, energy, alive counts) to decide.
## When false, falls back to the old flat training data (BotTrainingData).
@export var use_contextual_model := true

## Load and use persistent training data for ability/target selection.
## Only used when use_contextual_model is false.
@export var use_training_data := true

## How often to auto-save training data (every N matches). 0 = only at end.
@export var save_interval := 50

## Every Nth match, force one randomly-chosen side to play uniformly random
## (no model, no training data). Stops the contextual model from converging
## on a fixed-point of "what beats itself" and exposes it to dumb-but-broad
## opponents. 0 = never (always model-vs-model). Typical value: 5.
@export var opponent_variety_interval := 0

## Evaluation mode: load a SECOND contextual model and pit it against the
## primary one (side 0 = primary, side 1 = eval_model_b). No weight updates
## are committed to either model — purely for measuring head-to-head winrate.
## Use to validate "does the new model beat the old one?" after a retrain.
@export var eval_mode := false

## Path to the second model file when eval_mode is true. Leave the primary
## at the default `res://bot_contextual_model.json` and snapshot it to a
## different path before retraining.
@export var eval_model_b_path := ""

## When set to 0 or 1, that side plays via the live game's priority-based
## bot logic (perform_turn / Character.get_action), not the contextual model.
## Use to measure "does the new contextual model actually beat what we ship
## today?" Default -1 = neither side uses priority.
##   0 = player side (side 0) plays priority
##   1 = enemy side (side 1) plays priority
## Compatible with eval_mode (no commits) for clean head-to-head measurement.
## When opponent_variety_interval also fires for this match, variety wins —
## that side plays uniformly random instead of priority.
@export var priority_opponent_side: int = -1

## When set to 0 or 1, that side plays uniformly random EVERY match (no model,
## no training data, no priority). Use to establish baselines: "how often does
## the contextual model beat random?" or "how often does priority beat random?"
## Default -1 = no fixed random side.
##   0 = player side (side 0) plays random
##   1 = enemy side (side 1) plays random
## Distinct from opponent_variety_interval, which only flips a random side
## intermittently and coin-flips which side it is.
@export var random_opponent_side: int = -1

## Use ColorBalancedDraft for that side's team composition instead of uniform
## random. Color-balanced teams cover the energy spectrum more reliably and
## should pay for their kits — matters most when comparing models that depend
## on team energy availability. Player team_overrides still take precedence.
@export var p1_balanced := false
@export var p2_balanced := false

## Anchor-sweep mode. When `anchor` is non-empty, the harness fixes that
## character in slot 1 of the player team and rotates color-balanced 2nd
## and 3rd teammates each "set" — a block of `matches_per_set` matches with
## the same fixed team. Use to discover which teammates work well with a
## given anchor (e.g. "what pairs well with Luffy?") in much less time than
## a full N×N character grid would take.
##
## When anchor is set, num_matches is recomputed as anchor_sets × matches_per_set.
## Player_team_override and p1_balanced are ignored (the team is anchored
## explicitly). Enemy team selection is unchanged — vs_priority / vs_random /
## p2_balanced all still apply.
@export var anchor: String = ""
@export var anchor_sets: int = 50
@export var matches_per_set: int = 20

# ===========================================================================
# STATE MACHINE  —  one step per _process frame keeps the UI responsive
# ===========================================================================

# SETTLE sits between match-end and the next match's setup. Match-end calls
# queue_free on the previous BattleManager subtree; SETTLE just transitions
# to SETUP_MATCH next frame so Godot has TWO frame boundaries (one for the
# deferred free to run, plus a buffer) before we instantiate the new tree.
# Bounds memory growth across long runs.
enum Phase { IDLE, SETTLE, SETUP_MATCH, PLAYER_TURN, ENEMY_TURN, DONE }
var _phase := Phase.IDLE

# ===========================================================================
# INTERNAL STATE
# ===========================================================================

var manager: BattleManager
var _current_match := 0
var _turn_count := 0
var _wins := 0
var _losses := 0
var _draws := 0
var _match_running := false
var _current_player_team: Array[String] = []
var _current_enemy_team: Array[String] = []

## -1 = both sides use the model; 0 or 1 = that side plays uniformly random
## this match. Reset each `_setup_next_match`.
var _random_side: int = -1

## Per-character performance: name -> { wins:int, losses:int, draws:int }
var _char_stats: Dictionary = {}

## Persistent training data (loaded from disk, saved back after tests).
var _training_data: BotTrainingData

## Contextual bandits model (state-aware alternative).
var _contextual_model: BotContextualModel

## Second model used by side 1 when eval_mode is true.
var _contextual_model_b: BotContextualModel

# ── Anchor-sweep state (only used when `anchor` is non-empty) ──
## 1-indexed; advances each time we start a new teammate combination.
var _current_set: int = 0
## Matches completed within the current set so far.
var _matches_in_current_set: int = 0
## Frozen player team for this set: [anchor, teammate1, teammate2].
var _set_player_team: Array[String] = []
var _set_wins: int = 0
var _set_losses: int = 0
var _set_draws: int = 0
## Accumulated per-set summaries; printed sorted by win-rate at the end.
## Each entry: { "teammates": Array[String], "wins": int, "losses": int, "draws": int }
var _anchor_results: Array = []

# ===========================================================================
# UI REFERENCES  (built in _build_ui)
# ===========================================================================

var _progress_bar: ProgressBar
var _progress_label: Label
var _stats_label: Label
var _match_info_label: Label
var _log: RichTextLabel


# ===========================================================================
# LIFECYCLE
# ===========================================================================

func _ready():
	_build_ui()
	# Apply CLI overrides before any state derived from exports is read.
	# `OS.has_feature("headless")` is unreliable in Godot 4; the canonical check
	# is the display-server name.
	if _is_headless():
		_apply_cli_overrides(OS.get_cmdline_user_args())
	# Anchor-sweep validation. Must come after CLI parsing, before any team
	# selection happens. On error we abort cleanly rather than crashing inside
	# the per-set team build.
	if anchor != "":
		var roster = CharacterDatabase.char_name_list()
		if not (anchor in roster):
			push_error("--anchor=%s: not a valid character path_name" % anchor)
			if OS.has_feature("headless"):
				get_tree().quit(1)
			return
		# In anchor mode, num_matches is dictated by sets × per-set count.
		num_matches = anchor_sets * matches_per_set
		print("[anchor] anchor=%s  sets=%d  matches/set=%d  total=%d" % [
			anchor, anchor_sets, matches_per_set, num_matches])
	# Gate per-action bot prints behind the same verbose toggle. These prints
	# come from player_component._contextual_bot_act / perform_turn_random and
	# dominate runtime past a few hundred matches if left on.
	BotContextualModel.verbose_logging = verbose
	if use_contextual_model:
		_contextual_model = BotContextualModel.load_from_disk()
		# Load model B if a path is given. Eval_mode alone only means "don't
		# commit weight updates" — it composes with --vs-priority (contextual
		# vs priority bot) or --eval-b (contextual A vs contextual B).
		if eval_model_b_path != "":
			_contextual_model_b = BotContextualModel.load_from_path(eval_model_b_path)
		elif eval_mode and priority_opponent_side < 0 and random_opponent_side < 0 and opponent_variety_interval == 0:
			push_warning("eval_mode is set but no opponent specified — both sides will use the same model. Add --eval-b=PATH, --vs-priority, or --vs-random for a meaningful comparison.")
	elif use_training_data:
		_training_data = BotTrainingData.load_from_disk()
	# Kick off the first match on the next frame so the UI draws first.
	_phase = Phase.SETUP_MATCH


## Parses `--key=value` and `--flag` arguments and overrides matching exports.
## Unknown args are reported but not fatal so the harness keeps moving.
##
## Supported:
##   --matches=N                 num_matches
##   --variety=N                 opponent_variety_interval
##   --save-interval=N           save_interval
##   --verbose                   verbose = true
##   --quiet                     verbose = false
##   --no-contextual             use_contextual_model = false
##   --eval                      eval_mode = true (no weight commits)
##   --eval-b=PATH               eval_model_b_path (implies --eval)
##   --vs-priority               priority_opponent_side = 1 (enemy = priority bot)
##   --vs-priority=0|1           priority_opponent_side = N
##   --vs-random                 random_opponent_side = 1 (enemy = uniform random)
##   --vs-random=0|1             random_opponent_side = N
##   --p1-balanced                p1 team uses ColorBalancedDraft (default off)
##   --p2-balanced                p2 team uses ColorBalancedDraft (default off)
##   --anchor=NAME                anchor-sweep mode: fix NAME in slot 1, rotate
##                                color-balanced teammates each set
##   --anchor-sets=N              how many distinct teammate combinations to try
##   --matches-per-set=N          matches per teammate combination (default 20)
##   --p1-team=name1,name2,name3 player_team_override
##   --p2-team=name1,name2,name3 enemy_team_override
func _apply_cli_overrides(args: PackedStringArray):
	for raw in args:
		var arg := String(raw)
		var key := arg
		var value := ""
		var eq := arg.find("=")
		if eq >= 0:
			key = arg.substr(0, eq)
			value = arg.substr(eq + 1)
		match key:
			"--matches":              num_matches = int(value)
			"--variety":              opponent_variety_interval = int(value)
			"--save-interval":        save_interval = int(value)
			"--verbose":              verbose = true
			"--quiet":                verbose = false
			"--no-contextual":        use_contextual_model = false
			"--eval":                 eval_mode = true
			"--eval-b":
				eval_model_b_path = value
				eval_mode = true
			"--vs-priority":
				priority_opponent_side = int(value) if value != "" else 1
			"--vs-random":
				random_opponent_side = int(value) if value != "" else 1
			"--p1-balanced":          p1_balanced = true
			"--p2-balanced":          p2_balanced = true
			"--anchor":               anchor = value
			"--anchor-sets":          anchor_sets = int(value)
			"--matches-per-set":      matches_per_set = int(value)
			"--p1-team":              player_team_override = _split_team(value)
			"--p2-team":              enemy_team_override = _split_team(value)
			_:
				push_warning("[cli] Unknown arg: %s" % arg)
	var priority_label := "off" if priority_opponent_side < 0 else ("p%d" % (priority_opponent_side + 1))
	var random_label := "off" if random_opponent_side < 0 else ("p%d" % (random_opponent_side + 1))
	var balanced_label := _format_balanced_label(p1_balanced, p2_balanced)
	if anchor != "":
		# Anchor mode line — different shape since the relevant knobs differ.
		print("[cli] anchor=%s  sets=%d  matches/set=%d  vs-priority=%s  vs-random=%s  p2-balanced=%s  eval=%s  verbose=%s" % [
			anchor, anchor_sets, matches_per_set,
			priority_label, random_label, p2_balanced, eval_mode, verbose])
	else:
		print("[cli] matches=%d  variety=%d  eval=%s  vs-priority=%s  vs-random=%s  balanced=%s  verbose=%s" % [
			num_matches, opponent_variety_interval, eval_mode,
			priority_label, random_label, balanced_label, verbose])


static func _format_balanced_label(p1: bool, p2: bool) -> String:
	if p1 and p2: return "both"
	if p1: return "p1"
	if p2: return "p2"
	return "off"


static func _split_team(csv: String) -> Array[String]:
	var out: Array[String] = []
	for piece in csv.split(",", false):
		var trimmed := piece.strip_edges()
		if trimmed != "":
			out.append(trimmed)
	return out


func _process(_delta):
	match _phase:
		Phase.SETTLE:
			# One-frame buffer after match-end: gives Godot's deferred-free
			# queue room to actually reclaim the previous match's node tree
			# before we instantiate the next one.
			_phase = Phase.SETUP_MATCH
		Phase.SETUP_MATCH:
			_phase = Phase.IDLE
			_setup_next_match()
		Phase.PLAYER_TURN:
			_phase = Phase.IDLE
			_do_player_turn()
		Phase.ENEMY_TURN:
			_phase = Phase.IDLE
			_do_enemy_turn()
		Phase.DONE:
			set_process(false)


## Convenience factory — call from any script to launch headless tests.
static func quick_start(parent: Node, matches: int = 1,
		player_names: Array[String] = [],
		enemy_names: Array[String] = []) -> TestBattleHeadless:
	var test := TestBattleHeadless.new()
	test.num_matches = matches
	test.player_team_override = player_names
	test.enemy_team_override = enemy_names
	parent.add_child(test)
	return test


# ===========================================================================
# UI CONSTRUCTION
# ===========================================================================

func _build_ui():
	add_theme_constant_override("margin_left", 16)
	add_theme_constant_override("margin_right", 16)
	add_theme_constant_override("margin_top", 16)
	add_theme_constant_override("margin_bottom", 16)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	# ── Title ──
	var title := Label.new()
	title.text = "Bot-vs-Bot Test Runner"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	# ── Progress bar ──
	var prog_row := HBoxContainer.new()
	vbox.add_child(prog_row)

	_progress_bar = ProgressBar.new()
	_progress_bar.max_value = num_matches
	_progress_bar.value = 0
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.custom_minimum_size.y = 24
	_progress_bar.show_percentage = false
	prog_row.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.text = "0 / %d" % num_matches
	_progress_label.custom_minimum_size.x = 80
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_row.add_child(_progress_label)

	# ── Stats line ──
	_stats_label = Label.new()
	_stats_label.text = "W: 0   L: 0   D: 0   |   Win: --"
	vbox.add_child(_stats_label)

	# ── Current-match info ──
	_match_info_label = Label.new()
	_match_info_label.text = "Starting..."
	_match_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_match_info_label)

	vbox.add_child(HSeparator.new())

	# ── Scrollable match log ──
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.scroll_active = true
	_log.selection_enabled = true
	_log.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_log)


# ===========================================================================
# MATCH ORCHESTRATION
# ===========================================================================

func _setup_next_match():
	if _current_match >= num_matches:
		_finish_all()
		return

	_current_match += 1
	_turn_count = 0
	_match_running = true

	# Decide which side (if any) plays uniformly random this match. Precedence:
	#   1. random_opponent_side: pinned to a specific side every match (use for
	#      baseline measurement — eval_mode does NOT suppress this)
	#   2. opponent_variety_interval: every Nth match, randomly chosen side
	#      (suppressed under eval_mode to keep head-to-head results clean)
	if random_opponent_side >= 0:
		_random_side = random_opponent_side
	elif not eval_mode and opponent_variety_interval > 0 and _current_match % opponent_variety_interval == 0:
		_random_side = randi() % 2
	else:
		_random_side = -1

	# Anchor mode: regenerate the player team only at the start of each set.
	# A new set begins when we've completed matches_per_set matches, OR on the
	# very first match (_current_set still 0).
	if anchor != "":
		if _matches_in_current_set >= matches_per_set or _current_set == 0:
			if _current_set > 0:
				_record_set_results()
			_current_set += 1
			_set_wins = 0
			_set_losses = 0
			_set_draws = 0
			_matches_in_current_set = 0
			_set_player_team = _build_anchor_team()
		_matches_in_current_set += 1

	# Previous manager (if any) was already queue_free'd in _on_match_ended /
	# _force_draw, giving Godot at least one extra frame to actually free the
	# subtree (players, characters, ability components, effects) before we
	# instantiate the new one. Don't free here — that'd just queue another
	# free on a node that's already in the cleanup queue.
	manager = BattleManager.new()
	manager.name = "BattleManager"
	# Headless training has no UI to pace for — run execution synchronously.
	# Without this, each turn would block on the per-action animation timers
	# from the display-mode async loop, turning a fast training pass into one
	# that takes real-time seconds per turn.
	manager.shadow_mode = true
	add_child(manager)

	if anchor != "":
		_current_player_team = _set_player_team
	else:
		_current_player_team = _pick_team(player_team_override, [], p1_balanced)
	_current_enemy_team  = _pick_team(enemy_team_override, _current_player_team, p2_balanced)

	var player_obj := _build_player("BotPlayer", _current_player_team)
	var enemy_obj  := _build_player("BotEnemy",  _current_enemy_team)

	var seed_val := randi()
	var first    := bool(randi() % 2)

	# Wire signals before the battle fires its first turn_started / waiting
	_connect_signals()

	# UI: log the matchup header
	_log.append_text("[b]Match %d / %d[/b]   " % [_current_match, num_matches])
	_log.append_text("%s   vs   %s\n" % [
		", ".join(_current_player_team),
		", ".join(_current_enemy_team),
	])
	_update_match_info()
	_update_progress()

	if verbose:
		print("Match %d: %s vs %s  (seed=%d first=%s)" % [
			_current_match,
			", ".join(_current_player_team),
			", ".join(_current_enemy_team),
			seed_val,
			"Player" if first else "Enemy",
		])

	manager.start_battle(player_obj, enemy_obj, first, seed_val, BattleManager.MatchType.BOT)


func _connect_signals():
	manager.turn_started.connect(_on_turn_started)
	manager.waiting_for_opponent.connect(_on_waiting_for_opponent)
	manager.match_ended.connect(_on_match_ended)
	manager.random_panel_needed.connect(_on_random_panel_needed)

	if verbose:
		manager.message_request.connect(func(msg):
			print("  [msg]   %s" % msg)
		)
		manager.ability_will_execute.connect(func(character, ability):
			print("  [exec]  %s used %s" % [character.character_name, ability.ability_name])
		)
		manager.ticking_effect_will_execute.connect(func(effect):
			print("  [tick]  %s's %s on %s" % [
				effect.user.character_name,
				effect.source.ability_name,
				effect.target.character_name,
			])
		)
		manager.round_loop_started.connect(func():
			print("  [exec]  --- Round execution ---")
		)
		manager.action_cancelled.connect(func(character):
			print("  [undo]  %s cancelled" % character.character_name)
		)


# ===========================================================================
# SIGNAL HANDLERS  →  just set the _phase flag; _process acts next frame
# ===========================================================================

func _on_turn_started(_is_player_turn: bool):
	if not _match_running:
		return
	_turn_count += 1
	if _turn_count >= MAX_TURNS:
		_force_draw()
		return
	_phase = Phase.PLAYER_TURN


func _on_waiting_for_opponent():
	if not _match_running:
		return
	_phase = Phase.ENEMY_TURN


func _on_match_ended(won: bool):
	_match_running = false
	_record_result(won)
	# Commit this match's actions to the active model. Eval mode is read-only:
	# discard pending so neither model is updated.
	if eval_mode:
		if _contextual_model:
			_contextual_model.commit_draw()
		if _contextual_model_b:
			_contextual_model_b.commit_draw()
	elif _contextual_model:
		var reward = _compute_hp_margin_reward(won)
		_contextual_model.commit_match(0 if won else 1, reward)
		if save_interval > 0 and _current_match % save_interval == 0:
			_contextual_model.save_to_disk()
	elif _training_data:
		_training_data.commit_match(0 if won else 1)
		if save_interval > 0 and _current_match % save_interval == 0:
			_training_data.save_to_disk()
	_update_stats_display()
	_update_progress()

	# Free this match's manager subtree NOW so Godot can clear the players,
	# characters, and ability/effect components before we instantiate a new
	# tree next frame. queue_free is deferred to end-of-frame; freeing here
	# instead of in _setup_next_match gives the cleanup a full frame to run
	# before the new match's nodes get added — meaningful for memory pressure
	# on long runs because each match instantiates ~hundreds of nodes.
	_free_match_subtree()

	if _current_match >= num_matches:
		_finish_all()
	else:
		_phase = Phase.SETTLE


## Queues the current match's BattleManager (and everything under it — both
## Player nodes, all 6 Characters, every ability/effect component) for
## deferred free. Safe to call multiple times; no-ops if manager is null.
## Also clears the UI log periodically so its bbcode-parsed buffer doesn't
## grow unbounded over thousand-match runs.
func _free_match_subtree():
	if manager != null:
		manager.queue_free()
		manager = null
	# RichTextLabel keeps the parsed bbcode for everything ever appended.
	# In headless mode the UI is never rendered so this is pure overhead.
	# Clear it every `save_interval` matches (or every 50 if save_interval=0)
	# to bound the buffer. Final summary appends after _finish_all reads the
	# stats so this doesn't lose the end-of-run report.
	var clear_every: int = save_interval if save_interval > 0 else 50
	if _log != null and _current_match % clear_every == 0:
		_log.clear()


## Maps the winning team's surviving HP fraction to a reward magnitude in
## [0.5, 1.5]. A pyrrhic 1-HP win → ~0.5 (soft); an untouched sweep → 1.5
## (strong). Symmetric for losers — a narrow loss is softly punished, a
## blowout heavily. Adds dynamic range to the reward signal so the model
## doesn't treat every win as identical.
func _compute_hp_margin_reward(won: bool) -> float:
	if manager == null:
		return 1.0
	var winner_team = manager.player.team if won else manager.enemy.team
	var max_total = 0.0
	var alive_total = 0.0
	for c in winner_team.characters:
		max_total += float(c.health.max_hp)
		if not c.dead:
			alive_total += float(c.health.hp)
	if max_total < 1.0:
		return 1.0
	return clampf(0.5 + alive_total / max_total, 0.5, 1.5)


func _on_random_panel_needed(_team, _random_count, exec_order: Dictionary):
	var order: Array = []
	for key in exec_order.keys():
		order.append(key)
	manager.allotment_accepted(order, [])


# ===========================================================================
# TURN EXECUTION  (called from _process, one per frame)
# ===========================================================================

func _do_player_turn():
	_update_match_info()
	if not _match_running or manager == null or manager.match_over:
		return
	if verbose:
		print("  [turn %d] Player%s" % [_turn_count, _side_tag(0)])
	_dispatch_turn(manager.player, 0)


func _do_enemy_turn():
	_update_match_info()
	if not _match_running or manager == null or manager.match_over:
		return
	if verbose:
		print("  [turn %d] Enemy%s" % [_turn_count, _side_tag(1)])
	manager.generate_team_energy(manager.enemy.team, manager.went_second)
	manager.went_second = false
	_dispatch_turn(manager.enemy, 1)


## Routes a side's turn to the right bot implementation. Priority order:
##   1. Variety override — uniformly random for this match (no model)
##   2. Priority bot — perform_turn(), the live game's logic
##   3. Contextual model — perform_turn_contextual() (eval_mode_b for side 1)
##   4. Fallback — perform_turn_random with training_data (or null)
func _dispatch_turn(player_obj, side: int):
	if _random_side == side:
		player_obj.perform_turn_random(manager, null, side)
		return
	if priority_opponent_side == side:
		player_obj.perform_turn(manager)
		return
	if _contextual_model:
		var model := _contextual_model
		if side == 1 and eval_mode and _contextual_model_b:
			model = _contextual_model_b
		player_obj.perform_turn_contextual(manager, model, side)
		return
	player_obj.perform_turn_random(manager, _training_data, side)


## Tag for verbose per-turn lines indicating which bot type acted on this side.
func _side_tag(side: int) -> String:
	if _random_side == side:
		return "  [random]"
	if priority_opponent_side == side:
		return "  [priority]"
	return ""


# ===========================================================================
# RESULT TRACKING
# ===========================================================================

func _force_draw():
	_match_running = false
	manager.match_over = true
	_draws += 1
	if anchor != "":
		_set_draws += 1
	_record_char_results("draws")
	_log.append_text("  [color=yellow]DRAW[/color] (MAX_TURNS %d)  %d turns\n" % [MAX_TURNS, _turn_count])
	_log_health_summary()
	_update_stats_display()
	_update_progress()
	if _contextual_model:
		_contextual_model.commit_draw()
	if _contextual_model_b:
		_contextual_model_b.commit_draw()
	if not _contextual_model and _training_data:
		_training_data.commit_draw()
	if verbose:
		print("  >> DRAW (%d turns, MAX_TURNS reached)" % _turn_count)
	else:
		_print_match_oneliner("DRAW")
	_free_match_subtree()
	if _current_match >= num_matches:
		_finish_all()
	else:
		_phase = Phase.SETTLE


func _record_result(won: bool):
	var result_label := "WIN" if won else "LOSS"
	if won:
		_wins += 1
		if anchor != "":
			_set_wins += 1
		_record_char_results("wins")
		_log.append_text("  [color=green]WIN[/color]   %d turns\n" % _turn_count)
	else:
		_losses += 1
		if anchor != "":
			_set_losses += 1
		_record_char_results("losses")
		_log.append_text("  [color=red]LOSS[/color]  %d turns\n" % _turn_count)
	_log_health_summary()
	if verbose:
		print("  >> %s (%d turns)" % [result_label, _turn_count])
	else:
		_print_match_oneliner(result_label)


## Single-line per-match summary for non-verbose runs. Always goes to stdout
## so headless wrappers see one line per completed match.
func _print_match_oneliner(result_label: String):
	print("[%4d/%-4d] %-4s  %3d turns   %s  vs  %s" % [
		_current_match, num_matches, result_label, _turn_count,
		", ".join(_current_player_team), ", ".join(_current_enemy_team),
	])


func _record_char_results(result_key: String):
	# Initialise entries for any new characters
	for char_name in _current_player_team + _current_enemy_team:
		if char_name not in _char_stats:
			_char_stats[char_name] = { "wins": 0, "losses": 0, "draws": 0 }
	# Player team gets the result directly
	for char_name in _current_player_team:
		_char_stats[char_name][result_key] += 1
	# Enemy team gets the inverse (their win is the player's loss)
	var enemy_key := result_key
	if result_key == "wins":
		enemy_key = "losses"
	elif result_key == "losses":
		enemy_key = "wins"
	for char_name in _current_enemy_team:
		_char_stats[char_name][enemy_key] += 1


func _finish_all():
	_phase = Phase.DONE
	_match_info_label.text = "All %d matches complete." % num_matches
	# Anchor mode: snapshot the final set's results before reporting.
	if anchor != "" and _matches_in_current_set > 0:
		_record_set_results()
	_log_character_stats()
	# Eval mode is read-only — never persist either model.
	if eval_mode and _contextual_model:
		_log.append_text("\n[b]══════ Eval Mode ══════[/b]\n")
		_log.append_text("  Side 0 (primary): %s\n" % BotContextualModel.SAVE_PATH)
		_log.append_text("  Side 1 (model_b): %s\n" % eval_model_b_path)
		_log.append_text("  No weights persisted (eval is read-only).\n")
	elif _contextual_model:
		_contextual_model.save_to_disk()
		_log_contextual_summary()
	elif _training_data:
		_training_data.save_to_disk()
		_log_training_summary()
	if verbose:
		_print_console_summary()
	# In headless mode, the harness IS the program — exit cleanly so the CLI
	# wrapper can chain commands. Print summary unconditionally so the user
	# sees it even with --quiet.
	if _is_headless():
		if not verbose:
			_print_console_summary()
		if anchor != "":
			_print_anchor_summary()
		get_tree().quit(0)


## Snapshots the current set's win/loss/draw counts into _anchor_results
## along with the teammate identity. Called when a set ends — either when
## starting the next set or in _finish_all for the final set.
func _record_set_results():
	# Teammates = player team minus the anchor (preserving order).
	var teammates: Array = []
	for n in _set_player_team:
		if n != anchor:
			teammates.append(n)
	var entry := {
		"teammates": teammates,
		"wins": _set_wins,
		"losses": _set_losses,
		"draws": _set_draws,
	}
	_anchor_results.append(entry)
	# Per-set summary line so progress is visible during long sweeps.
	if not verbose:
		var total: int = _set_wins + _set_losses + _set_draws
		var wr: float = 100.0 * float(_set_wins) / float(maxi(total, 1))
		print("[Set %3d/%-3d] %s + %s  ->  W:%d L:%d D:%d  (%.1f%%)" % [
			_current_set, anchor_sets, anchor, ", ".join(teammates),
			_set_wins, _set_losses, _set_draws, wr])


## Final sorted ranking of all teammate combinations tried this run.
## Sort key: win rate descending; ties broken by absolute wins descending.
func _print_anchor_summary():
	print("")
	print("═══ ANCHOR SWEEP COMPLETE ═══")
	print("Anchor: %s   Sets: %d   Matches/set: %d   Total: %d" % [
		anchor, _anchor_results.size(), matches_per_set, num_matches])
	print("")
	# Sort by win rate (desc), then wins (desc) as tiebreaker
	var sorted := _anchor_results.duplicate()
	sorted.sort_custom(func(a, b):
		var ta: int = a.wins + a.losses + a.draws
		var tb: int = b.wins + b.losses + b.draws
		var wra: float = float(a.wins) / float(maxi(ta, 1))
		var wrb: float = float(b.wins) / float(maxi(tb, 1))
		if wra != wrb:
			return wra > wrb
		return a.wins > b.wins
	)
	print("═══ Per-set results, sorted by win rate ═══")
	var rank := 1
	for entry in sorted:
		var total: int = entry.wins + entry.losses + entry.draws
		var wr: float = 100.0 * float(entry.wins) / float(maxi(total, 1))
		print("%3d.  %5.1f%%  (%2dW / %2dL / %dD)  %s + %s" % [
			rank, wr, entry.wins, entry.losses, entry.draws,
			anchor, ", ".join(entry.teammates)])
		rank += 1


## True when running under `--headless`. Godot 4 has no `headless` feature tag,
## so we check the display server name (the canonical test per docs).
static func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


# ===========================================================================
# TEAM BUILDING
# ===========================================================================

## Anchor-sweep team builder: anchor is forced into slot 1, slots 2-3 are
## color-balanced random draws around it. Used only when anchor != "".
func _build_anchor_team() -> Array[String]:
	var pool = CharacterDatabase.char_name_list().duplicate()
	var built = ColorBalancedDraft.build_team(pool, TEAM_SIZE, [anchor], [])
	var team: Array[String] = []
	for n in built:
		team.append(String(n))
	return team


func _pick_team(overrides: Array[String], exclude: Array[String] = [],
		balanced: bool = false) -> Array[String]:
	if overrides.size() >= TEAM_SIZE:
		return overrides.slice(0, TEAM_SIZE)
	var pool = CharacterDatabase.char_name_list().duplicate()
	for n in exclude:
		pool.erase(n)
	if balanced:
		# Color-balanced pick. ColorBalancedDraft.build_team handles the
		# `force` (overrides) seeding internally and skips the `excluded`
		# list. No need to remove overrides from the pool first.
		var built = ColorBalancedDraft.build_team(pool, TEAM_SIZE, overrides, exclude)
		var result: Array[String] = []
		for n in built:
			result.append(String(n))
		return result
	# Original uniform-random fill.
	for n in overrides:
		pool.erase(n)
	pool.shuffle()
	var result: Array[String] = overrides.duplicate()
	while result.size() < TEAM_SIZE and pool.size() > 0:
		result.append(pool.pop_back())
	return result


func _build_player(username: String, char_names: Array[String]) -> Player:
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


# ===========================================================================
# UI UPDATES
# ===========================================================================

func _update_progress():
	_progress_bar.value = _current_match
	_progress_label.text = "%d / %d" % [_current_match, num_matches]


func _update_stats_display():
	var total := _wins + _losses + _draws
	var pct   := "%.1f%%" % (100.0 * _wins / total) if total > 0 else "--"
	_stats_label.text = "W: %d   L: %d   D: %d   |   Win: %s" % [_wins, _losses, _draws, pct]


func _update_match_info():
	_match_info_label.text = "Match %d/%d   |   %s   vs   %s   |   Turn %d" % [
		_current_match, num_matches,
		", ".join(_current_player_team),
		", ".join(_current_enemy_team),
		_turn_count,
	]


func _log_health_summary():
	if manager == null:
		return
	var p_parts: Array[String] = []
	for c in manager.player.team.characters:
		var hp := "DEAD" if c.dead else ("BAN" if c.banished else "%dHP" % c.health.hp)
		p_parts.append("%s:%s" % [c.character_name, hp])
	var e_parts: Array[String] = []
	for c in manager.enemy.team.characters:
		var hp := "DEAD" if c.dead else ("BAN" if c.banished else "%dHP" % c.health.hp)
		e_parts.append("%s:%s" % [c.character_name, hp])
	_log.append_text("[color=gray]    P: %s[/color]\n" % "   ".join(p_parts))
	_log.append_text("[color=gray]    E: %s[/color]\n" % "   ".join(e_parts))


func _log_character_stats():
	_log.append_text("\n[b]══════ Character Performance ══════[/b]\n")

	# Sort by total appearances (descending), then by win-rate
	var names := _char_stats.keys()
	names.sort_custom(func(a, b):
		var ta: int = _char_stats[a].wins + _char_stats[a].losses + _char_stats[a].draws
		var tb: int = _char_stats[b].wins + _char_stats[b].losses + _char_stats[b].draws
		if ta != tb:
			return ta > tb
		var wa: float = float(_char_stats[a].wins) / max(ta, 1)
		var wb: float = float(_char_stats[b].wins) / max(tb, 1)
		return wa > wb
	)

	for char_name in names:
		var s: Dictionary = _char_stats[char_name]
		var total: int = s.wins + s.losses + s.draws
		var wr: float  = 100.0 * s.wins / max(total, 1)
		var color := "green" if wr >= 55.0 else ("red" if wr <= 45.0 else "white")
		_log.append_text("  [color=%s]%-20s[/color]  %dW  %dL  %dD   (%d games, %.0f%% win)\n" % [
			color, char_name, s.wins, s.losses, s.draws, total, wr,
		])


func _log_training_summary():
	_log.append_text("\n[b]══════ Training Data Summary ══════[/b]\n")
	_log.append_text("  Saved to: %s\n" % BotTrainingData.SAVE_PATH)
	_log.append_text("  Total action records: %d\n" % _training_data.total_actions())
	_log.append_text("  Characters tracked: %d\n\n" % _training_data.data.size())

	# Show top abilities for characters that appeared in overrides
	var focus_chars: Array[String] = []
	for n in player_team_override:
		if n not in focus_chars:
			focus_chars.append(n)
	for n in enemy_team_override:
		if n not in focus_chars:
			focus_chars.append(n)

	for char_name in focus_chars:
		if char_name not in _training_data.data:
			continue
		_log.append_text("  [b]%s[/b]\n" % char_name)
		var abilities = _training_data.data[char_name]
		# Sort abilities by score descending
		var ability_names = abilities.keys()
		ability_names.sort_custom(func(a, b):
			var sa: float = (float(abilities[a].wins) + 1.0) / (float(abilities[a].uses) + 2.0)
			var sb: float = (float(abilities[b].wins) + 1.0) / (float(abilities[b].uses) + 2.0)
			return sa > sb
		)
		for ab_name in ability_names:
			var entry = abilities[ab_name]
			var score := (float(entry.wins) + 1.0) / (float(entry.uses) + 2.0)
			var color := "green" if score >= 0.55 else ("red" if score <= 0.45 else "white")
			_log.append_text("    [color=%s]%s[/color]: %.0f%% (%dW/%dU)" % [
				color, ab_name, score * 100, entry.wins, entry.uses])
			# Show top 3 targets by score
			if "vs" in entry and entry.vs.size() > 0:
				var targets = entry.vs.keys()
				targets.sort_custom(func(a, b):
					var sa2: float = (float(entry.vs[a].wins) + 1.0) / (float(entry.vs[a].uses) + 2.0)
					var sb2: float = (float(entry.vs[b].wins) + 1.0) / (float(entry.vs[b].uses) + 2.0)
					return sa2 > sb2
				)
				var shown := 0
				var parts: Array = []
				for t_name in targets:
					if shown >= 3:
						break
					var t = entry.vs[t_name]
					var ts := (float(t.wins) + 1.0) / (float(t.uses) + 2.0)
					parts.append("%s %.0f%%" % [t_name, ts * 100])
					shown += 1
				_log.append_text("  best vs: %s" % ", ".join(parts))
			_log.append_text("\n")
		_log.append_text("\n")


func _log_contextual_summary():
	_log.append_text("\n[b]══════ Contextual Model Summary ══════[/b]\n")
	_log.append_text("  Saved to: %s\n" % BotContextualModel.SAVE_PATH)
	_log.append_text("  Total weight updates: %d\n" % _contextual_model.total_updates())
	_log.append_text("  Characters tracked: %d\n\n" % _contextual_model.data.size())

	# Show learned weights for characters in overrides
	var focus_chars: Array[String] = []
	for n in player_team_override:
		if n not in focus_chars:
			focus_chars.append(n)
	for n in enemy_team_override:
		if n not in focus_chars:
			focus_chars.append(n)

	for char_name in focus_chars:
		if char_name not in _contextual_model.data:
			continue
		_log.append_text("  [b]%s[/b]\n" % char_name)
		var abilities = _contextual_model.data[char_name]
		var ability_names = abilities.keys()
		# Sort by update count descending
		ability_names.sort_custom(func(a, b):
			return int(abilities[a].get("updates", 0)) > int(abilities[b].get("updates", 0))
		)
		for ab_name in ability_names:
			var entry = abilities[ab_name]
			var updates := int(entry.get("updates", 0))
			_log.append_text("    [b]%s[/b] (%d updates)\n" % [ab_name, updates])

			# Ability weights — show which features drive this ability's selection
			var aw = entry.get("ability_weights", [])
			if aw.size() > 0:
				var ab_parts: Array = []
				for i in range(mini(aw.size(), BotContextualModel.ABILITY_FEATURE_NAMES.size())):
					var w := float(aw[i])
					if absf(w) < 0.005:
						continue
					var color := "green" if w > 0 else "red"
					ab_parts.append("[color=%s]%s=%+.2f[/color]" % [
						color, BotContextualModel.ABILITY_FEATURE_NAMES[i], w])
				if ab_parts.size() > 0:
					_log.append_text("      ability: %s\n" % ", ".join(ab_parts))
				else:
					_log.append_text("      ability: [color=gray](all near zero)[/color]\n")

			# Target weights — show what target features matter
			var tw = entry.get("target_weights", [])
			if tw.size() > 0:
				var tgt_parts: Array = []
				for i in range(mini(tw.size(), BotContextualModel.TARGET_FEATURE_NAMES.size())):
					var w := float(tw[i])
					if absf(w) < 0.005:
						continue
					var color := "green" if w > 0 else "red"
					tgt_parts.append("[color=%s]%s=%+.2f[/color]" % [
						color, BotContextualModel.TARGET_FEATURE_NAMES[i], w])
				if tgt_parts.size() > 0:
					_log.append_text("      target:  %s\n" % ", ".join(tgt_parts))
				else:
					_log.append_text("      target:  [color=gray](all near zero)[/color]\n")
		_log.append_text("\n")


func _print_console_summary():
	print("")
	print("═══ TEST RUN COMPLETE ═══")
	print("Matches: %d   W: %d   L: %d   D: %d   Win: %.1f%%" % [
		num_matches, _wins, _losses, _draws,
		100.0 * _wins / max(num_matches, 1),
	])
	if _contextual_model:
		print("Contextual model: %d weight updates saved to %s" % [
			_contextual_model.total_updates(), BotContextualModel.SAVE_PATH])
	elif _training_data:
		print("Training data: %d action records saved to %s" % [
			_training_data.total_actions(), BotTrainingData.SAVE_PATH])
	print("")
