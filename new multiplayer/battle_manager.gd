## BattleManager: Server-ready game logic for the battle system.
##
## This class contains ALL game execution logic extracted from battle_scene.gd.
## It maintains the same public API surface that abilities, characters, and
## QueryContext use (all_characters, roll, request_message, etc.) so existing
## game scripts work without modification — just pass this as the `battle`
## reference instead of the old BattleScene.
##
## On the server: instantiate BattleManager directly and drive it with turn
## packages received from clients.
##
## On the client: BattleDisplay creates a BattleManager internally, connects
## to its signals, and renders the UI.

extends Node
class_name BattleManager

# ===========================================================================
# LIVE-GAME BOT MODEL
# ===========================================================================
# Lazily-loaded contextual model shared by all live (non-headless) bot
# matches in this process. Loaded once on first bot turn; never written
# back to disk (live matches use commit_draw at match end so player
# actions don't leak into training data). The headless harness loads its
# own independent instance via load_from_disk; this static cache is not
# the same object.
static var _live_bot_model: BotContextualModel = null

static func _get_live_bot_model() -> BotContextualModel:
	if _live_bot_model == null:
		_live_bot_model = BotContextualModel.load_from_disk()
	return _live_bot_model


# --- v3 policy (training/bot_policy.gd) -----------------------------------
# Clean break from the contextual model: when a promoted res://bot_policy.json
# exists, live bot turns run BotPolicyV3 via perform_turn_v3; when it doesn't
# (nothing promoted yet), callers fall back to the legacy contextual path.
# bot_tuning.json is the hand-tuning overlay: hot-reloaded by mtime so score
# offsets / style knobs / difficulty temperatures apply without a restart.
const LIVE_POLICY_PATH := "res://bot_policy.json"
const LIVE_TUNING_PATH := "res://bot_tuning.json"
static var _live_policy = null
static var _live_policy_checked := false
static var _live_tuning: Dictionary = {}
static var _live_tuning_mtime := 0

static func _get_live_bot_policy():
	if not _live_policy_checked:
		_live_policy_checked = true
		if FileAccess.file_exists(LIVE_POLICY_PATH):
			_live_policy = BotPolicyV3.load_from_path(LIVE_POLICY_PATH)
			if _live_policy != null:
				print("[bot-v3] Live policy loaded: generation %d, %d trained matches" % [
					_live_policy.generation, _live_policy.trained_matches])
			else:
				# Corrupt/wrong-format file: an all-zero v3 policy would play
				# uniform-random live — strictly worse than the contextual
				# fallback the null path selects.
				push_error("[bot-v3] bot_policy.json exists but FAILED to load — falling back to the contextual bot")
	return _live_policy

static func _get_live_bot_tuning() -> Dictionary:
	var mtime := FileAccess.get_modified_time(LIVE_TUNING_PATH)
	if mtime != _live_tuning_mtime:
		_live_tuning_mtime = mtime
		_live_tuning = {}
		if FileAccess.file_exists(LIVE_TUNING_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(LIVE_TUNING_PATH))
			if parsed is Dictionary:
				_live_tuning = parsed
	return _live_tuning

## Softmax temperature for the configured difficulty tier (live "difficulty").
static func _live_tier_temperature() -> float:
	var g: Dictionary = _get_live_bot_tuning().get("global", {})
	var tiers: Dictionary = g.get("difficulty_tiers", {})
	return float(tiers.get(str(g.get("default_tier", "normal")), 0.45))


# ===========================================================================
# GAME STATE
# ===========================================================================
var player
var enemy

enum Gamestate {
	LOADING,
	OPEN,
	RESOLVING,
	CLOSED,
	TARGETING
}

# Match kind. APPEND-ONLY — the ordinal is the wire/JSON value, persisted in match
# records, replays and stats. Absorbed the identical enum that used to live on the
# retired desktop client's BattleScene (same ordinals), which server code referenced
# as BattleManager.MatchType.
enum MatchType {
	PRIVATE,
	QUICK,
	BOT,
	RANKED,
	CAMPAIGN   # single-player PvE campaign encounter — bot-driven shadow, skips PvP bookkeeping
}

var gamestate = Gamestate.CLOSED
var match_type = MatchType.QUICK
var action_order: Array = []
var ticking_order: Array = []
var ticking_character_order: Array = []
var went_second: bool = false
# Live bot matches set this true to pace bot character actions in
# perform_turn_contextual; headless training leaves it false so bot turns
# remain synchronous and don't slow the training loop.
var paced_bot_actions: bool = false
# True while a turn's action animations are being played back. UI elements
# that display the selection-phase state (queued ability icons, targeting
# indicators) check this and render their cleared state so the playback
# isn't visually competing with the leftover selection tooltips.
var in_playback: bool = false
var waiting_for_turn: bool = false
# Server-only latch: Match.validate_input calls prepare_acting_energy_if_needed()
# to run the acting team's pre-turn energy generation before the affordability
# check, so the shadow's pool reflects reality when validation fires. This flag
# tells process_turn_package to skip its own generate_team_energy step so the
# same energy isn't rolled twice.
var acting_energy_prepared: bool = false
var execution_order: Dictionary = {}
var last_exchange = null
var die: RandomNumberGenerator = RandomNumberGenerator.new()
var match_over: bool = false
# One-shot latch for the empty-roster alarm in check_lose_condition/check_win_condition (see
# _report_empty_roster). Per MANAGER, not per turn: those predicates run constantly.
var _empty_roster_reported: bool = false
var true_execution_order: Array = []
var reconnecting: bool = false
# When true, this manager is the server-side shadow simulation: end_match
# must skip real-world side effects (rank, bounties, missions, save) since
# the authoritative server flow already applies them via send_match_ending.
var shadow_mode: bool = false
# Phase 6: when true, this manager does not run its own simulation. All
# state changes come from server-emitted events via apply_turn_result.
# `start_round_loop` becomes inert, `roll` returns 0 (no client-side RNG),
# and `allotment_accepted` builds + sends a turn input package instead of
# starting the local execution loop. Phase 6 only adds the gating; the
# flag stays false during Phase 6 so the existing relay path remains
# authoritative. Phase 7 sets `passive = (match_type != BOT)` so
# multiplayer matches consume server events while bot matches stay local.
var passive: bool = false
var spectator: bool = false
# Canonical wire role of THIS manager's local user: 0 = p1, 1 = p2. The
# server's shadow always sees player == p1 by construction so this stays 0;
# clients receive their role over the match-creation RPCs because the seat
# assignment is decided on the server. _role / _team_role / _canonical_index
# all read this so the protocol's "p1 vs p2" coordinates stay consistent
# regardless of which seat the local user occupies.
var local_canonical_role: int = 0

# ===========================================================================
# SIGNALS — the display layer (or network layer) observes these
# ===========================================================================

# Match lifecycle
signal battle_started(first: bool)
# Phase 8: reconnection seeds the passive manager from a server wire snapshot
# instead of replaying package_history, so the signal carries the snapshot
# (already-applied at emit time) for any listener that wants it.
signal battle_reconnect_started(snapshot: Dictionary)
signal match_ended(won: bool)

# Turn flow
signal turn_started(is_player_turn: bool)
signal waiting_for_opponent()
signal refreshing()
signal round_loop_started()
# Fires the moment in_playback flips from true to false (i.e., the per-action
# animation playback for this turn has fully completed). Used by the display
# layer to defer the turn-change banner so it doesn't overlap the last
# action's animation in passive mode (where TURN_STARTED for the next player
# applies inside the last action group, before that group's pacing await).
signal playback_ended()

# Execution events
signal ability_will_execute(character, ability)
signal ticking_effect_will_execute(effect)
signal execution_step_completed()

# Character actions
signal character_action_confirmed(character)
signal character_click_missed()
signal action_cancelled(character)
signal character_clicked(character)
signal targeting_reset_needed()

# Messages (formerly directly updated UI; now emitted for display)
signal message_request(message: String)
signal message_demand(message: String)
signal log_event(event)

# Display bridge — UI code reaches `character.battle.show_panel(...)`;
# since character.battle == manager, we emit a signal for the display layer.
signal show_panel_requested(tooltip, panel)

# Gamestate change
signal gamestate_changed(new_state: Gamestate)

# Energy / panels
signal random_panel_needed(team, random_count, exec_order: Dictionary)
signal exchange_processed()

# Turn packaging (networking)
signal turn_package_ready(package: Dictionary)
# Phase 7: passive multiplayer clients emit this instead of turn_package_ready
# when the acting player accepts the random panel. Carries the canonical-frame
# input payload defined in MATCH_PROTOCOL.md section 2.2; the chain forwards it
# to ServerConnection which RPCs submit_turn_input on the server.
signal turn_input_ready(input: Dictionary)
signal send_surrender()

# Bot
signal bot_turn_requested(fake_delay: float, crash_delay: float)
signal bot_surrender_triggered()

# Persistence / navigation
signal save_mission_progress_requested(player_ref)
signal save_player_requested(player_ref)
signal char_select_return_requested(player_ref)
signal match_report_ready(won: bool, package: Dictionary)

# Phase 5 — protocol-facing event signals (consumed by MatchEventRecorder
# on the server-side shadow). Distinct names from the existing display-facing
# signals (e.g. character_clicked, ability_will_execute) so the recorder can
# subscribe without entangling the UI flow.
signal turn_started_event(turn_number: int, acting_role: int)
signal turn_ended_event(turn_number: int)
signal energy_gained_event(team_role: int, energy_list: Array)
signal energy_spent_event(team_role: int, energy_dict: Dictionary)
signal energy_exchanged_event(team_role: int, offer: Dictionary, request: int)
signal damage_dealt(target, amount: int, source, dealer)
signal healing_done(target, amount: int, source, healer)
signal effect_added_to(character, effect)
signal effect_removed_from(character, effect)
signal cooldown_set_event(character, ability, value: int)
signal character_died(character)
signal character_banished(character)
signal match_ended_event(winner_role: int)

# Phase 5 — protocol bookkeeping. Bumped at the start of each new turn so
# the recorder can stamp events with the round they belong to.
var current_turn_number: int = 0

# ===========================================================================
# INITIALIZATION
# ===========================================================================

## Main entry point — starts a new match.
## Call this instead of the old start_battle_scene().
## The display layer should connect to `battle_started` BEFORE calls to this.
##
## `canonical_role` is 0 if the local user is p1 in the protocol's coordinate
## system, 1 if p2. Bot matches always pass 0 since the local sim is the only
## perspective. The server's shadow also passes 0 because it constructs the
## match with the canonical p1 as `player`.
##
## When `m_type` is anything other than BOT and this manager is not the
## server-side shadow, `passive` flips on so the local sim is suppressed and
## state changes only arrive via server-broadcast apply_turn_result events.
func start_battle(nplayer, nenemy, first: bool, seed: int, m_type, canonical_role: int = 0):
	# Reset every piece of per-match bookkeeping that would otherwise carry
	# over on a consecutive match. The client's BattleManager is a single
	# long-lived node reused across matches, so any state left from the
	# previous match silently poisons the next one. In particular:
	#
	#   - _highest_seen_turn: the apply_turn_result stale-snapshot filter
	#     compares against this. Left at e.g. 15 from the previous match,
	#     the new match's initial snapshot (current_turn=1) is discarded,
	#     which drops the opening TURN_STARTED / ENERGY_GAINED events and
	#     leaves the client with no energy, everything unusable, and the
	#     server-side acting_player out of sync with the client's turn view.
	#
	#   - current_turn_number: start_new_turn / wait_for_turn pre-increment,
	#     so a stale counter would stamp TURN_STARTED with the wrong round.
	#
	#   - execution_order / true_execution_order / action_order / ticking
	#     buffers: accumulated during the previous match's execution loop.
	#     Leftover entries here would re-enter start_round_loop on the next
	#     round and try to re-execute dead abilities.
	#
	#   - waiting_for_turn / gamestate / went_second / last_exchange /
	#     acting_energy_prepared / reconnecting: the paths below that call
	#     start_new_turn(true) or wait_for_turn() assume a clean slate.
	match_over = false
	match_type = m_type
	local_canonical_role = canonical_role
	passive = not shadow_mode and m_type != MatchType.BOT
	die.set_seed(seed)
	_highest_seen_turn = -1
	current_turn_number = 0
	gamestate = Gamestate.CLOSED
	waiting_for_turn = false
	went_second = false
	last_exchange = null
	acting_energy_prepared = false
	reconnecting = false
	execution_order = {}
	true_execution_order = []
	action_order = []
	ticking_order = []
	ticking_character_order = []

	player = nplayer
	player.team.reset_energy_pool()
	player.set_mission_diff()

	if not player in get_children():
		add_child(player)

	enemy = nenemy
	# Player objects are reused across matches on the server; their team's
	# energy pool would otherwise carry leftover state from the previous match.
	enemy.team.reset_energy_pool()
	if not enemy in get_children():
		add_child(enemy)

	if not first:
		waiting_for_turn = true

	set_log_paused(true)
	for character in all_characters():
		character.initialize(true)

	for character in all_characters():
		character.startup(self)

	# Passive clients must NOT run startup_passives locally. Each passive's
	# execute() adds runtime Effect objects to character.effects._effects, and
	# the server independently ships the matching EFFECT_ADDED events (which
	# become DisplayEffects in character.effects._display_effects). Running
	# both paths makes get_renderable_effects return the same passive twice,
	# so the hover tooltip shows every passive description twice on startup.
	if not passive:
		# Semiramis must start passives last (game-specific ordering rule)
		var semis: Array = []
		for character in all_characters():
			if character.path_name == "semiramis":
				semis.append(character)
				continue
			character.startup_passives(self)
		for semiramis in semis:
			semiramis.startup_passives(self)

	# Assign missions
	for character in player.team.characters:
		for mission_id in player.mission_reference.keys():
			var mission = player.mission_reference[mission_id]
			if mission.is_character_valid(character.path_name):
				mission.assign(character, player)

	set_log_paused(false)
	battle_started.emit(first)

	if not first:
		went_second = true
		waiting_for_turn = true
		# The side that goes first still needs its start-of-turn triggers fired. When the PLAYER
		# goes first that happens in start_new_turn(true); but when the ENEMY goes first we only
		# called wait_for_turn(), which skips them — so a START_OF_TURN passive on the first-acting
		# side (e.g. Mavis's Fairy Star Strategy) was silently skipped on turn 1, and only every
		# later turn worked. Fire them here (mirroring turn_over's transition) so the effect lands
		# before that side acts. waiting_for_turn is already true, so team-gated passives resolve
		# to the correct acting team.
		if not passive:
			set_log_paused(true)
			for character in enemy.team.characters:
				character.check_start_of_turn_triggers(self)
			for character in player.team.characters:
				character.check_start_of_turn_triggers(self)
			set_log_paused(false)
		wait_for_turn()
	else:
		start_new_turn(true)


## Reconnection entry point — Phase 8.
##
## Seeds a freshly-built passive manager from a wire snapshot instead of
## re-rolling the RNG and replaying every turn package. The snapshot is the
## same shape that apply_turn_result's trailing payload uses, so the existing
## _reconcile_* helpers already know how to walk it.
##
## Bot matches never reconnect (single-player, in-process), so this path is
## effectively "any remote match" and always runs passive.
func start_battle_reconnect(nplayer, nenemy, snapshot: Dictionary, m_type, canonical_role: int = 0):
	reconnecting = true
	match_over = false
	match_type = m_type
	local_canonical_role = canonical_role
	passive = not shadow_mode and m_type != MatchType.BOT

	player = nplayer
	player.team.reset_energy_pool()
	if not player in get_children():
		add_child(player)

	enemy = nenemy
	enemy.team.reset_energy_pool()
	if not enemy in get_children():
		add_child(enemy)

	set_log_paused(true)
	for character in all_characters():
		character.initialize(true)

	for character in all_characters():
		character.startup(self)

	# Passive clients must NOT run startup_passives locally — the wire snapshot
	# already carries DisplayEffect payloads for every live passive, and running
	# the passives here would double them up alongside the reconciled DisplayEffects.
	# Non-passive paths (shadow, bots) don't reconnect, so this branch is
	# essentially dead in practice but kept for symmetry with start_battle.
	if not passive:
		var semis: Array = []
		for character in all_characters():
			if character.path_name == "semiramis":
				semis.append(character)
				continue
			character.startup_passives(self)
		for semiramis in semis:
			semiramis.startup_passives(self)

	for character in player.team.characters:
		for mission_id in player.mission_reference.keys():
			var mission = player.mission_reference[mission_id]
			mission.assign(character, player)
	set_log_paused(false)

	# Order matters here. The display layer wires per-character reactive signals
	# (CharacterPanel.set_character connects character.update, EffectTooltipDisplay
	# connects effects_changed) and populates the energy tracker dict inside
	# _on_battle_reconnect_started → create_test_interface. Applying the snapshot
	# before that wiring would silently drop HP updates, leave _display_effects
	# unrendered, and leave the energy trackers stuck at zero. Fire the signal
	# first so the display is primed, THEN pour in the authoritative state via
	# apply_match_state so every update.emit / effects_changed has a listener.
	battle_reconnect_started.emit(snapshot)
	apply_match_state(snapshot)

	var acting_role: String = snapshot.get("acting_role", "p1")
	var is_player_turn: bool = (acting_role == "p1" and _role(player) == 0) or (acting_role == "p2" and _role(player) == 1)
	turn_started.emit(is_player_turn)
	if is_player_turn:
		refreshing.emit()
	else:
		waiting_for_opponent.emit()

	reconnecting = false


func start_battle_spectate(nplayer, nenemy, snapshot: Dictionary, m_type):
	passive = true
	spectator = true
	match_over = false
	match_type = m_type
	local_canonical_role = 0

	player = nplayer
	player.team.reset_energy_pool()
	if not player in get_children():
		add_child(player)

	enemy = nenemy
	enemy.team.reset_energy_pool()
	if not enemy in get_children():
		add_child(enemy)

	set_log_paused(true)
	for character in all_characters():
		character.initialize(true)
	for character in all_characters():
		character.startup(self)
	set_log_paused(false)

	battle_reconnect_started.emit(snapshot)
	apply_match_state(snapshot)

	var acting_role: String = snapshot.get("acting_role", "p1")
	var is_player_turn: bool = (acting_role == "p1")
	turn_started.emit(is_player_turn)
	if not is_player_turn:
		waiting_for_opponent.emit()


func full_startup():
	set_log_paused(true)
	for character in all_characters():
		character.initialize(true)
		character.startup(self)
		character.startup_passives(self)
	set_log_paused(false)

# ===========================================================================
# CHARACTER CONNECTION
# ===========================================================================

## Connects only the LOGIC-relevant signals from a character.
## The display layer should call its own connect_character_display()
## to hook up UI signals (describe_ability, describe_character, etc.).
func connect_character(char):
	char.ability_selected.connect(receive_ability_use_request)
	char.character_selected.connect(receive_character_use_request)
	char.request_aoe_targets.connect(get_other_aoe_targets)
	char.request_random_targets.connect(get_valid_random_targets)
	char.cancel_action.connect(_on_action_cancelled)
	character_clicked.connect(char.other_character_clicked)
	char.effects.effect_added.connect(func (eff): effect_added_to.emit(char, eff))
	char.effects.effect_removed.connect(func (eff): effect_removed_from.emit(char, eff))

# ===========================================================================
# TURN MANAGEMENT
# ===========================================================================

func start_new_turn(first_turn: bool = false):
	print_verbose("Starting new turn")
	current_turn_number += 1
	log_turn_header(current_turn_number)
	# Emit TURN_STARTED before any downstream side effects so the wire event
	# stream tags subsequent damage/effect/cooldown events as belonging to the
	# new turn. acting_role for the new round is the local player's role; the
	# server-side shadow has player == p1, so this is 0 on the shadow.
	turn_started_event.emit(current_turn_number, _role(player))
	reset_character_targeted()
	print_verbose("Finished start of turn target reset")
	# Passive clients never source their own game-logic events — start-of-turn
	# triggers and energy generation are both server-authoritative. Running them
	# locally would poison the pool with phantom energy (roll() returns 0 on
	# passive, so every local gen lands as GREEN) and the display trackers would
	# drift permanently from the authoritative pool.
	waiting_for_turn = false
	if not passive:
		if first_turn:
			set_log_paused(true)
		for character in player.team.characters:
			character.check_start_of_turn_triggers(self)
		for character in enemy.team.characters:
			character.check_start_of_turn_triggers(self)
		if first_turn:
			set_log_paused(false)

		if not reconnecting:
			generate_team_energy(player.team, first_turn)

	
	execution_order = {}
	true_execution_order = []

	for character in all_characters():
		if character in player.team.characters:
			character.was_countered = false
		if character in enemy.team.characters:
			character.hp_last_last_turn = character.hp_last_turn
			character.hp_last_turn = character.health.hp
		character.refresh()
		character.targeted = false
		character._casseur_ctx = null   # release Casseur's held skill context at each turn boundary
		character.update.emit()

	refreshing.emit()
	gamestate = Gamestate.OPEN
	turn_started.emit(true)


func wait_for_turn():
	# Mark a new protocol turn for the OPPONENT side. The local manager goes
	# silent here while it waits for the opponent's package, but the wire
	# protocol still needs a TURN_STARTED so the receiving client can render
	# their turn boundary.
	current_turn_number += 1
	turn_started_event.emit(current_turn_number, _role(enemy))
	execution_order = {}
	true_execution_order = []

	for character in all_characters():
		if character in enemy.team.characters:
			character.was_countered = false
		if character in player.team.characters:
			character.hp_last_last_turn = character.hp_last_turn
			character.hp_last_turn = character.health.hp
		character.refresh()

	# Shadow-only: pre-generate the incoming acting team's (enemy.team) energy
	# now so the end-of-turn broadcast carries the ENERGY_GAINED events for the
	# opponent's upcoming turn. Without this, the events would only fire when
	# validate_input lazily calls prepare_acting_energy_if_needed at submit time,
	# making passive clients see 0 energy at turn start and the "real" pool only
	# at turn end. prepare_acting_energy_if_needed sets the same latch so it
	# no-ops when called from the normal validate path.
	prepare_acting_energy_if_needed()

	gamestate = Gamestate.CLOSED
	waiting_for_opponent.emit()

	# Bot handling — display layer owns the timers and calls back into us
	if enemy.bot_player:
		if bot_wants_surrender() and not randi_range(0, 3):
			bot_surrender_triggered.emit()
		else:
			bot_turn_requested.emit(randi_range(8, 16), 2)


func turn_over():
	action_order = []
	if check_match_over():
		return
	reset_character_targeted()
	if waiting_for_turn:
		start_new_turn()
	else:
		waiting_for_turn = true
		for character in enemy.team.characters:
			character.check_start_of_turn_triggers(self)
		for character in player.team.characters:
			character.check_start_of_turn_triggers(self)
		wait_for_turn()


func bot_wants_surrender() -> bool:
	var total_player_hp: int = 0
	var total_bot_hp: int = 0
	for character in player.team.characters:
		total_player_hp += character.health.hp
	for character in enemy.team.characters:
		total_bot_hp += character.health.hp
	return total_bot_hp <= int(total_player_hp * 0.3)

# ===========================================================================
# ACTION MANAGEMENT
# ===========================================================================

func receive_ability_use_request(character, ability):
	if character.enemy:
		return
	if gamestate == Gamestate.CLOSED:
		return
	reset_character_targeted()
	if ability.usable(character):
		character.targeter.start_targeting(ability)
		# Passive clients have no runtime _effects, so they can't evaluate
		# invulnerability, isolation, marks, target changes, or any other
		# effect-dependent targeting locally. The server ships the full
		# valid-target set for every ability in each snapshot — use it
		# verbatim instead of calling target().
		if passive and ability.server_targets_set:

			for canonical_idx in ability.server_targets:
				var target_char = _char_at(canonical_idx)
				if target_char != null:
					target_char.set_targeted()
		else:
			ability.target(character, self)


func receive_character_use_request(character):
	if gamestate == Gamestate.CLOSED:
		return
	if character.targeted:
		var pre_targeting_states = []
		for char in player.team.characters:
			pre_targeting_states.append(str(char.path_name) + ":" + str(char.targeter.targeting))
		var appended_char = null
		var guard_blocked = false
		for char in player.team.characters:
			if char.targeter.targeting:
				# Preserve the FIRST queue position for this character. If they
				# re-confirm an action mid-flow (e.g. picked a new ability for
				# the same slot), don't append a duplicate that would corrupt
				# the dict insertion order downstream in
				# get_used_ability_information.
				if not char in action_order:
					action_order.append(char)
					appended_char = char
				else:
					guard_blocked = true
					appended_char = char
				break
		character_clicked.emit(character)
		character_action_confirmed.emit(character)
	else:
		character_click_missed.emit()


func _on_action_cancelled(character):
	action_order.erase(character)
	reset_character_targeted()
	for char in all_characters():
		character.update.emit()
	action_cancelled.emit(character)


func finalize_action(char):
	player.team.pay_for_ability(char.used_ability)
	char.acted = true


func reset_character_targeted():
	for character in all_characters():
		if character.targeter.targeting:
			character.targeter.reset()
		character.set_untargeted()
		

# ===========================================================================
# TURN END & RANDOM ALLOCATION
# ===========================================================================

## Called when the player clicks the end-turn button.
## Validates state, resets targeting, and requests the random panel from display.
func turn_end_clicked():
	if gamestate == Gamestate.CLOSED:
		return
	reset_character_targeted()
	for character in all_characters():
		character.update.emit()

	# Build execution order from used abilities + ticking effects.
	# Passive clients have no runtime _effects, so the normal
	# get_ticking_effect_information returns nothing.  Read from
	# _display_effects (wire-snapshot driven) instead.
	var used_ability_information = get_used_ability_information()
	var ticking_effect_information: Dictionary
	if passive:
		ticking_effect_information = get_passive_ticking_display_info()
	else:
		ticking_effect_information = get_ticking_effect_information()
	execution_order = {}
	for key in used_ability_information.keys():
		execution_order[key] = used_ability_information[key]
	for key in ticking_effect_information.keys():
		execution_order[key] = ticking_effect_information[key]

	random_panel_needed.emit(
		player.team,
		player.team.energy.promised_pool[Energy.Type.RANDOM],
		execution_order
	)


## Called when the player accepts the random energy allocation.
func allotment_accepted(exe_order: Array, random_history: Array):
	true_execution_order = exe_order

	# Passive mode (multiplayer client): build the canonical-frame input
	# package, emit it for ServerConnection to RPC, and DO NOT start the local
	# execution loop. Authoritative state will arrive via apply_turn_result
	# from the server. The shadow manager runs with passive=false so it still
	# falls through to the bot/active branch below.
	if passive:
		var input = build_turn_input(exe_order, random_history)
		turn_input_ready.emit(input)
		return

	if not enemy.bot_player:
		var package = package_round_information(random_history)
		turn_package_ready.emit(package)
	start_round_loop()


func get_used_ability_information() -> Dictionary:
	var output: Dictionary = {}
	var seen: Array = []
	# Process each character at most once, using their FIRST appearance in
	# action_order. This guarantees the dict insertion order matches the
	# original queue order regardless of any duplicate appends upstream, and
	# avoids relying on Dictionary reassignment preserving key position.
	for character in action_order:
		if character in seen:
			continue
		seen.append(character)
		if character.used_ability != null:
			output[player.team.characters.find(character)] = character.used_ability
	return output


func get_ticking_effect_information(is_enemy: bool = false) -> Dictionary:
	var exclusion_check: Dictionary = {}
	var output: Dictionary = {}
	var counter: int = 3
	var acting_team = player.team.characters
	var enemy_team_chars = enemy.team.characters
	if is_enemy:
		acting_team = enemy.team.characters
		enemy_team_chars = player.team.characters

	for character in acting_team:
		var ticking_effects = get_ticking_effects(character, is_enemy)
		for effect in ticking_effects:
			var origin = [effect.source.ability_name, effect.effect_type, effect.id]
			if origin in exclusion_check.values():
				var index_of_match = exclusion_check.values().find(origin)
				var key_match = exclusion_check.keys()[index_of_match]
				output[key_match].append(effect)
			else:
				output[counter] = [effect]
				exclusion_check[counter] = origin
				counter += 1

	for character in enemy_team_chars:
		var ticking_effects = get_ticking_effects(character, is_enemy)
		for effect in ticking_effects:
			var origin = [effect.source.ability_name, effect.effect_type, effect.id]
			if origin in exclusion_check.values():
				var index_of_match = exclusion_check.values().find(origin)
				var key_match = exclusion_check.keys()[index_of_match]
				output[key_match].append(effect)
			else:
				output[counter] = [effect]
				exclusion_check[counter] = origin
				counter += 1

	return output


func get_ticking_effects(character, is_enemy: bool = false) -> Array:
	var ticking_effects: Array = []
	var team = player.team.characters
	if is_enemy:
		team = enemy.team.characters

	for effect in character.get_damage_effects():
		if effect.user in team and (not effect.last_turn_only or effect.duration == 1):
			ticking_effects.append(effect)

	for effect in character.get_healing_effects():
		# Same last_turn_only filter the DAMAGE loop above already carries: a "heals once, at the
		# end" effect (last_turn_only) must NOT be collected until the turn it actually fires
		# (duration == 1), or it shows as a phantom draggable reorder tile every turn in between.
		if effect.user in team and (not effect.last_turn_only or effect.duration == 1):
			ticking_effects.append(effect)

	for effect in character.get_ticking_triggers():
		# THE FIX. A `recurring` with last_turn_only set — a "fires once, at the end" ticker — was
		# collected every turn here (no filter), producing a phantom reorder tile on every turn it did
		# not actually fire. Gate it exactly as the DAMAGE loop does: only when it will fire this turn.
		if effect.user in team and (not effect.last_turn_only or effect.duration == 1):
			ticking_effects.append(effect)

	for effect in character.get_delayed_skills():
		if effect.user in team and effect.duration == 1:
			ticking_effects.append(effect)

	return ticking_effects


# Passive-client equivalent of get_ticking_effect_information. Reads from
# _display_effects (populated by wire snapshots) instead of _effects (always
# empty on passive clients). Returns the same Dictionary shape so the random
# panel and execution-order encoding work identically.
func get_passive_ticking_display_info() -> Dictionary:
	var ticking_types: Array = [
		EffectType.Type.DAMAGE,
		EffectType.Type.HEALING,
		EffectType.Type.TICKING_TRIGGER,
		EffectType.Type.DELAYED_SKILL,
	]
	var exclusion_check: Dictionary = {}
	var output: Dictionary = {}
	var counter: int = 3
	var acting_team = player.team.characters

	for character in all_characters():
		for de in character.effects._display_effects:
			if de.effect_type not in ticking_types:
				continue
			if de.user == null or de.user not in acting_team:
				continue
			if de.effect_type == EffectType.Type.DELAYED_SKILL and de.duration != 1:
				continue
			var origin = [de.source.ability_name, de.effect_type, de.id]
			if origin in exclusion_check.values():
				var index_of_match = exclusion_check.values().find(origin)
				var key_match = exclusion_check.keys()[index_of_match]
				output[key_match].append(de)
			else:
				output[counter] = [de]
				exclusion_check[counter] = origin
				counter += 1

	return output


# ===========================================================================
# EXECUTION LOOP
# ===========================================================================

# Pacing constants for action-feedback sequencing. The acted animation plays
# on the user's portrait, then floats (damage/heal/status) have time to be
# read before the next action begins.
const ACTED_ANIM_HOLD = 0.32
const POST_ACTED_GAP = 0.10
const FEEDBACK_HOLD = 0.55
const TICKING_BATCH_HOLD = 0.95
# Fast-forward: holding SPACE during playback compresses every pacing await
# by this multiplier. Releasing the key restores normal speed for any
# subsequent awaits in the same playback sequence.
const FAST_FORWARD_MULTIPLIER = 3.0
var anim_speed_multiplier: float = 1.0

# Failsafe: if a single playback sequence takes longer than this, assume
# something silently bailed (Godot swallows errors inside coroutines) and
# force-recover so the UI doesn't lock up. Comfortably longer than any
# real turn — a 5-action turn at 1× takes ~6s; even with very long animations
# and full ticking effects, 30s is well outside normal.
const PLAYBACK_WATCHDOG_TIMEOUT = 30.0
# Generation counter for the active watchdog. Every start or clear bumps
# this; pending timers compare their stored id against the current one and
# bail if they don't match (effectively a cheap cancellation since
# SceneTreeTimer has no direct cancel API).
var _playback_watchdog_id: int = 0


func _pacing(seconds: float) -> float:
	# Clamp speed so we never accidentally produce a zero-or-negative wait
	# (which would error on create_timer). Reads anim_speed_multiplier at
	# the moment the await starts, so each new pacing window picks up the
	# current FF state.
	var divisor: float = max(0.01, anim_speed_multiplier)
	return max(0.0, seconds / divisor)


# Wraps the pacing await so it becomes a true no-op when animations are
# disabled (rather than yielding for a zero-second timer, which would still
# eat a frame per call). When enabled, behaves identically to the inline
# `await get_tree().create_timer(_pacing(seconds)).timeout` pattern.
func _await_pacing(seconds: float) -> void:
	if not GlobalPlayerSettings.animations_enabled:
		return
	await get_tree().create_timer(_pacing(seconds)).timeout


func _unhandled_key_input(event):
	if event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed and not event.echo:
			anim_speed_multiplier = FAST_FORWARD_MULTIPLIER
		elif not event.pressed:
			anim_speed_multiplier = 1.0


func start_round_loop():
	# In passive mode the server is authoritative for execution; the local
	# manager waits for an apply_turn_result payload instead of running
	# its own action/effect loop. We still emit round_loop_started so any
	# UI listeners can flip into "round playing out" state, but no local
	# logic fires.
	if passive:
		round_loop_started.emit()
		return
	round_loop_started.emit()
	execution_loop_step()


var _execution_loop_active: bool = false


# Dispatches to a sync or async variant depending on whether we're the
# server-side shadow (or any context where pacing would corrupt timing).
# The shadow MUST run sync: apply_input → execution_loop_step → recorder
# fills → _broadcast_turn_result happens immediately after, so if the loop
# yielded mid-turn only the first action's events would be broadcast.
func execution_loop_step():
	if shadow_mode:
		_execution_loop_step_sync()
	else:
		_execution_loop_step_async()


func _execution_loop_step_sync():
	if _execution_loop_active:
		return
	_execution_loop_active = true
	while len(true_execution_order) > 0:
		var action_id = true_execution_order.pop_front()
		for key in execution_order.keys():
			if typeof(key) == 3 and key == action_id:
				action_id = float(action_id)
			elif typeof(key) == 2 and key == action_id:
				action_id = int(action_id)
		var executable = execution_order[action_id]
		var result = execute_step(executable)
		if not result == OK:
			var nm = "(unknown)"
			if executable is Ability:
				nm = executable.ability_name
			print("An error occurred while attempting to execute " + nm)
		if check_match_over():
			_execution_loop_active = false
			return
	end_of_turn_effect_handling()
	_execution_loop_active = false


func _set_in_playback(value: bool) -> void:
	if in_playback == value:
		return
	in_playback = value
	for character in all_characters():
		character.update.emit()
	if not value:
		playback_ended.emit()


# Watchdog timer for stuck playback. If a coroutine in the execution chain
# silently bails (Godot swallows errors inside async functions), the
# animation loop never advances and the UI freezes. This timer fires after
# PLAYBACK_WATCHDOG_TIMEOUT seconds and forcibly recovers state so the player
# isn't stranded.
func _start_playback_watchdog() -> void:
	# Bump the id first: this invalidates any prior pending timer that
	# hasn't fired yet, then we register a new one bound to the fresh id.
	_playback_watchdog_id += 1
	var id := _playback_watchdog_id
	var timer := get_tree().create_timer(PLAYBACK_WATCHDOG_TIMEOUT)
	timer.timeout.connect(_on_playback_watchdog_fire.bind(id))


func _clear_playback_watchdog() -> void:
	# Bumping the id invalidates any still-pending timer; when it fires
	# it'll see id != _playback_watchdog_id and bail.
	_playback_watchdog_id += 1


func _on_playback_watchdog_fire(id: int) -> void:
	if id != _playback_watchdog_id:
		return  # this watchdog was already cleared; stale fire
	if not in_playback and not _execution_loop_active:
		return  # state is already clean somehow; nothing to recover
	push_warning("[WATCHDOG] Playback exceeded %.1fs — forcing recovery" % PLAYBACK_WATCHDOG_TIMEOUT)
	_force_end_playback()


# Recover from a stuck playback by clearing the gating flags and (in active
# mode) advancing to the next turn. If end_of_turn_effect_handling itself
# errors, the flags above are already cleared so subsequent player input
# can still re-enter the system.
func _force_end_playback() -> void:
	_execution_loop_active = false
	paced_bot_actions = false
	_set_in_playback(false)
	if not passive:
		end_of_turn_effect_handling()


# An action is "shown" (with its acted animation and pacing pause) when
# either the ability is visible or its user belongs to the local player's
# team. Hiding only applies to OPPONENT invisible skills — the owning
# player always sees their own actions play out.
#
# Exception: Toph Beifong's passive lets her allies see invisible Physical
# skills. So opponent-invisible abilities also surface if the player has a
# living, non-banished Toph on their team and the ability has the Physical
# class.
func _should_show_action(actor, ability) -> bool:
	if ability == null or not ability.invisible:
		return true
	if actor == null or player == null:
		return true
	if actor in player.team.characters:
		return true
	if ability.classes.get("Physical", false) and _player_has_living_toph():
		return true
	return false


func _player_has_living_toph() -> bool:
	if player == null:
		return false
	for character in player.team.characters:
		if character.path_name == "toph" and not character.dead and not character.banished:
			return true
	return false


func _execution_loop_step_async():
	# Reentrance guard: timers like DelayTimer can fire execution_loop_step
	# while a previous async loop is still mid-pacing. Without this, both
	# coroutines would drain the queue and each call
	# end_of_turn_effect_handling, ending the turn twice.
	if _execution_loop_active:
		return
	_execution_loop_active = true
	_set_in_playback(true)
	_start_playback_watchdog()
	while len(true_execution_order) > 0:
		var action_id = true_execution_order.pop_front()
		for key in execution_order.keys():
			if typeof(key) == 3 and key == action_id:
				action_id = float(action_id)
			elif typeof(key) == 2 and key == action_id:
				action_id = int(action_id)
		var executable = execution_order[action_id]
		var result = execute_step(executable)
		if not result == OK:
			var nm = "(unknown)"
			if executable is Ability:
				nm = executable.ability_name
			print("An error occurred while attempting to execute " + nm)
		if check_match_over():
			_clear_playback_watchdog()
			_set_in_playback(false)
			_execution_loop_active = false
			return
		await _play_action_feedback_sequence(executable)
	_clear_playback_watchdog()
	_set_in_playback(false)
	end_of_turn_effect_handling()
	_execution_loop_active = false


func _play_action_feedback_sequence(executable) -> void:
	# The acted animation itself is emitted from execute_ability (so any caller
	# — player loop or direct bot call — gets it). This just paces the gap
	# between actions so floats are readable before the next one starts.
	# Opponent-invisible abilities skip pacing entirely so attentive players
	# can't detect their use from a perceptible pause in the playback rhythm.
	# The owning player's own invisible skills still pace normally — they
	# see their character act.
	if executable is Ability:
		var ability: Ability = executable
		if _should_show_action(ability.user, ability):
			await _await_pacing(ACTED_ANIM_HOLD + POST_ACTED_GAP + FEEDBACK_HOLD)
	elif executable is Array:
		await _await_pacing(TICKING_BATCH_HOLD)


func execute_step(executable) -> int:
	if executable is Ability:
		execute_ability(executable)
	elif executable is Array:
		executable.sort_custom(func (a, b): return a.twin_priority < b.twin_priority)
		for effect in executable:
			execute_ticking_effect(effect)
	return OK


# Before a queued skill executes, drop any hostile target that has become invulnerable to THIS skill
# since it was queued — e.g. an earlier action this turn (Death Barrier's counter) granted invuln to a
# character another already-queued skill was aimed at; without this the skill would still land because the
# target is still in its targeter. Only HOSTILE targets are considered (invuln never blocks allied/self
# skills). Bypass is NOT inferred from the "Bypassing" class — many invuln-piercing skills express bypass
# only through the bypassing arg their target() passes to the targeting helper. So we re-run the skill's
# OWN target() (side-effect-free: it snapshots/restores the targeted flags) to learn who it can still
# legally hit right now, and drop an invuln hostile only when its own targeting no longer offers it. This
# also naturally keeps class-filtered invuln (an invuln that excludes the skill's class) correct. Repoints
# main_target if it was removed, and returns FALSE when EVERY target was dropped (skill fizzles) so the
# caller skips execute() — abilities that dereference main_target/targets[0] would crash on an empty targeter.
func _drop_invuln_targets(actor, ability) -> bool:
	var original: int = actor.targeter.targets.size()
	if original == 0:
		return true
	# Cheap pre-check: only do the (target()-rerun) work if some hostile target is invuln to this skill.
	var any_invuln := false
	for target in actor.targeter.targets:
		if actor.is_hostile(target) and target.is_invuln(ability):
			any_invuln = true
			break
	if not any_invuln:
		return true
	var targetable := _compute_special_targets(ability, actor)
	var kept := []
	for target in actor.targeter.targets:
		if actor.is_hostile(target) and target.is_invuln(ability) and not (_canonical_index(target) in targetable):
			continue
		kept.append(target)
	if kept.size() == original:
		return true
	actor.targeter.targets = kept
	if not (actor.targeter.main_target in kept):
		actor.targeter.main_target = kept[0] if kept.size() > 0 else null
	return kept.size() > 0


func execute_ability(ability):
	var char = ability.user
	if not (char.is_stunned(ability) or (char.dead or char.banished)):

		for target in char.targeter.targets:
			if ability.ability_name == "Bluff Kamehameha" and target.marked_by("Big Bang Kamehameha", char):
				return
			if ability.ability_name == "Rankyaku Gaicho":
				for effect in target.get_effects_by_type(EffectType.Type.COUNTER_RECEIVE):
					char.manually_advance_mission(9, 1)
					target.effects.erase_effect(effect)
				for effect in target.get_effects_by_type(EffectType.Type.REFLECT_RECEIVE):
					target.effects.erase_effect(effect)
					char.manually_advance_mission(9, 1)

		log_ability_use(char, ability)
		ability_will_execute.emit(char, ability)
		ability.start_cooldown()
		if ability.ability_blinded:
			get_valid_random_targets(char)
		if Character.ability_acts_harmful(ability) and char.is_taunted():
			char.resolve_taunt()
		var delay_check = ability.is_delayed()
		if delay_check > 0:
			ability.delay_execution(char, self, delay_check)
			return
		if not ability.classes["Preserves Channel"]:
			char.cancel_channels()
		if not char.countered(self, ability):
			if _drop_invuln_targets(char, ability):
				# Snapshot the real (pre-reflect) targets: reflect_check can repoint the targeter to the
				# caster's own team, which would otherwise flip the use-trigger faction read.
				var acting_targets = char.targeter.targets.duplicate()
				char.reflect_check(self, ability)
				char.accuracy_check(ability)
				ability.execute(char, self)
				char.check_ability_use_triggers(self, ability, char.path_name == "emiyaarcher", acting_targets)
			char.acted = true
			# Invisible abilities are hidden ONLY from the opponent; their
			# owner still sees the portrait pop + ability overlay because
			# they're the one who used the skill.
			if _should_show_action(char, ability):
				char.acted_animation_requested.emit(ability)
		else:
			char.was_countered = true
			for eff in char.effects.get_effects_by_type(EffectType.Type.XANXUS_STORAGE):
				eff.user.wrath_check("counter")


func execute_ticking_effect(effect):
	if effect.target.dead or effect.target.banished:
		return
	if effect.source.classes["Action"] and effect.user.is_stunned(effect.source):
		return
	if effect.removed:
		return
	ticking_effect_will_execute.emit(effect)

	if effect.effect_type == EffectType.Type.DAMAGE:
		if effect.target.is_invuln(effect.source) and not (effect.source.classes["Bypassing"] or effect.bypassing or effect.damage_type == DamageType.Type.AFFLICTION or effect.damage_type == DamageType.Type.BLEED):
			return
		if effect.last_turn_only and effect.duration != 1:
			return
		if effect.duration == 1 and effect.source.ability_name == "Zanni di Squalo":
			effect.user.manually_advance_mission(7, 1)
		if effect.per_stack:
			for i in range(effect.stack_count()):
				var context = QueryContext.from_game_state(effect.user, self)
				Character.resolve_effect_damage(context, effect, effect.target, effect.mag, effect.damage_type)
		else:
			var context = QueryContext.from_game_state(effect.user, self)
			Character.resolve_effect_damage(context, effect, effect.target, effect.mag, effect.damage_type)

	elif effect.effect_type == EffectType.Type.HEALING:
		if effect.target.is_isolated():
			return
		if effect.per_stack:
			for i in range(effect.stack_count()):
				effect.user.give_effect_healing(effect, effect.mag, effect.target)
		else:
			effect.user.give_effect_healing(effect, effect.mag, effect.target)

	elif effect.effect_type == EffectType.Type.TICKING_TRIGGER:
		# The DAMAGE branch's last_turn_only guard, mirrored here — the second site of the two-site
		# fix. A last_turn_only ticking trigger fires ONLY on the turn it expires (duration == 1);
		# without this a "fires once, at the end" recurring executed every turn.
		if effect.last_turn_only and effect.duration != 1:
			return
		if effect.user in effect.target.team.characters:
			# Isolation stops an ally-APPLIED ticking trigger from firing on the isolated ally, but it
			# must not stop a SELF-applied ticker (user == target) — that is the character's own channel
			# (e.g. Mavis's Fairy Law, whose payload is a hostile AOE on the enemy team), and isolation
			# never removes a character's ability to act on itself. Any ally-facing HEALING / Helpful buff
			# in the payload is still gated per-recipient downstream (resolve_effect_healing /
			# can_apply_allied_effect); isolation only ever blocks RECEIVING help, not acting on others.
			if effect.target.is_isolated() and not (effect.target == effect.user):
				return
		else:
			# Mirror the DAMAGE branch's invuln guard, INCLUDING its Affliction/Bleed exemption: a ticking
			# trigger that delivers Affliction/Bleed damage (damage_type set) pierces Invulnerability the
			# same way a real Affliction/Bleed DAMAGE effect does. Triggers with no damage_type are unchanged.
			if effect.target.is_invuln(effect.source) and not (effect.source.classes["Bypassing"] or effect.bypassing or effect.damage_type == DamageType.Type.AFFLICTION or effect.damage_type == DamageType.Type.BLEED):
				return
		var context = QueryContext.from_effect_end(effect)
		effect.trigger.check(context)

	elif effect.effect_type == EffectType.Type.DELAYED_SKILL:
		var context = QueryContext.from_effect_end(effect)
		effect.source.delay_trigger(context)
		if effect.duration != 1:
			return
		if effect.user in effect.target.team.characters:
			# Same self-target exemption as the TICKING_TRIGGER branch above: a SELF-cast delayed skill
			# (user == target, e.g. Hashirama's delayed Deep Forest Blooms) is the caster's own channel,
			# and isolation must not stop a character acting on itself/the enemy team. Ally-facing HEALING /
			# Helpful buffs remain gated per-recipient downstream; isolation blocks receiving help, not acting.
			if effect.target.is_isolated() and not (effect.target == effect.user):
				return
		else:
			if effect.target.is_invuln(effect.set_source) and not effect.source.classes["Bypassing"]:
				return
		var delayed_skill = effect.delay_skill
		var targets = effect.delay_targets
		var main_target = effect.delay_main_target

		var target_storage = effect.user.targeter.targets
		var main_target_storage = effect.user.targeter.main_target
		var used_skill_storage = effect.user.used_ability

		effect.user.targeter.targets = targets
		effect.user.targeter.main_target = main_target
		effect.user.used_ability = delayed_skill

		if not effect.user.countered(self, delayed_skill):
			var acting_targets = effect.user.targeter.targets.duplicate()   # pre-reflect snapshot (see execute_ability)
			effect.user.reflect_check(self, delayed_skill)
			effect.user.accuracy_check(delayed_skill)
			delayed_skill.execute(effect.user, self)
			effect.user.check_ability_use_triggers(self, delayed_skill, effect.user.path_name == "emiyaarcher", acting_targets)
			effect.user.acted = true
		else:
			effect.user.was_countered = true

		effect.user.targeter.targets = target_storage
		effect.user.targeter.main_target = main_target_storage
		effect.user.used_ability = used_skill_storage

# ===========================================================================
# END-OF-TURN
# ===========================================================================

func tick_durations():
	for character in all_characters():
		if not character.banished:
			character.effects.tick_all_effects_durations()
		else:
			for banish in character.effects.get_effects_by_type(EffectType.Type.BANISH):
				banish.tick_effect()
			if len(character.effects.get_effects_by_type(EffectType.Type.BANISH)) < 1:
				character.banished = false
			for eff in character.effects._effects:
				if eff.tick_during_banish:
					eff.tick_effect()


func end_of_turn_effect_handling():
	turn_ended_event.emit(current_turn_number)
	reset_character_targeted()
	var team = player.team.characters
	if waiting_for_turn:
		team = enemy.team.characters
	for character in all_characters():
		# Defensive: a character whose .battle points at a torn-down / previously-freed manager
		# (a stale cross-match reference) would crash from_game_state below. It isn't part of this
		# live match's state, so skip its end-of-turn handling entirely. Logged so the source of the
		# stale reference can be pinned down from server logs (which character, how often).
		if not is_instance_valid(character.battle):
			push_warning("[STALE-BATTLE] end_of_turn skipped a character with a freed battle ref: " + str(character.path_name) + " (match_type=" + str(match_type) + ")")
			continue
		if character.dead or character.banished:
			character.check_cancels()
			if not character.banished:
				character.effects.clear_non_system_effects(character)
	for character in team:
		if not (character.dead or character.banished):
			character.moveset.advance_cooldowns(character)
			character.check_end_of_turn_triggers(self)

	tick_durations()
	print_verbose("Turn over")
	turn_over()

# ===========================================================================
# ENERGY
# ===========================================================================

func generate_team_energy(team, first_turn: bool = false):
	var energy_list: Array = []
	if not first_turn:
		var enhanced := _team_is_ultra_bot(team)   # P6: Ultra Bot teams roll 75% own-colour energy
		for char in team.characters:
			if not char.dead and not char.banished and not char.sleepy_frieren() and not char.marked_by("Named Reconstitution"):
				energy_list += char.generate_energy(enhanced)
	else:
		var energy_roll = roll(0, 3, "Generate 1-off first turn energy")
		energy_list.append(Energy.Type[Energy.Type.keys()[energy_roll]])
	# Pay off drains this team could not pay in cash (TeamComponent.lose_energy).
	# The trim happens AFTER every roll above and BEFORE the pool is credited:
	# rolling first keeps the seeded RNG stream identical whether or not a denial
	# is pending, and trimming from the back with resize() picks a victim without
	# touching the stream at all (pick_random uses the unseeded global RNG, and
	# roll() would add a draw). Every entry is an i.i.d. uniform color, so which
	# index we drop is distributionally irrelevant.
	if team.denied_energy_generation > 0:
		energy_list.resize(max(0, energy_list.size() - team.denied_energy_generation))
	# Unconditional, and deliberately BEFORE any early exit: the denial never
	# crosses a second turn boundary. Draining 2 from a team that only generates
	# 1 denies 1 and FORGIVES the remainder — it does not stack into next turn.
	# Do not "fix" this into a carry-over; the forgiveness is the design.
	# It also has to run when energy_list came out empty (whole team dead, asleep
	# or banished), or a stale counter would strand and fire a turn late.
	team.denied_energy_generation = 0
	for energy in energy_list:
		team.change_energy(energy, 1)
	# Emitted after the trim so the wire event reports what was actually gained,
	# not what was rolled. A fully denied generation emits nothing at all.
	if energy_list.size() > 0:
		energy_gained_event.emit(_team_role(team), energy_list)


func add_player_energy(energy_list: Array):
	for energy in energy_list:
		player.team.change_energy(energy, 1)


func accept_exchange(offer: Dictionary, request):
	if not reconnecting:
		last_exchange = [offer, request]
	for key in offer.keys():
		player.team.energy.change_energy(key, -offer[key])
	player.team.energy.change_energy(request, 1)
	for character in player.team.characters:
		character.update.emit()
	exchange_processed.emit()
	energy_exchanged_event.emit(_team_role(player.team), offer, request)


func accept_enemy_exchange(offer: Dictionary, request):
	for key in offer.keys():
		enemy.team.energy.change_energy(key, -offer[key])
	enemy.team.energy.change_energy(request, 1)
	energy_exchanged_event.emit(_team_role(enemy.team), offer, request)

# ===========================================================================
# TURN PACKAGES (NETWORKING)
# ===========================================================================

func package_round_information(random_history: Array) -> Dictionary:
	var round_package: Dictionary = {}
	var character_actions: Array = []
	for character in player.team.characters:
		if character.used_ability != null:
			var targets: Array = []
			for target in character.targeter.targets:
				targets.append(all_characters().find(target))
			character_actions.append([
				player.team.characters.find(character),
				character.moveset.get_active_abilities(character).find(character.used_ability),
				targets
			])
	round_package['random_history'] = random_history
	round_package['character_actions'] = character_actions
	round_package['execution_order'] = true_execution_order
	round_package['timeout'] = false
	round_package['exchange'] = last_exchange
	last_exchange = null
	return round_package


# Phase 7: canonical-frame input package emitted by passive multiplayer
# clients. Schema is defined in MATCH_PROTOCOL.md section 2.2. Coordinates are
# canonical 0..5 indices via _canonical_index, so the server (and the opposing
# client, when it later replays via apply_turn_result) read the same numbers
# regardless of which seat the local user occupies. The current_turn_number
# stamp lets the server reject stale or replayed inputs.
func build_turn_input(exe_order: Array, random_history: Array) -> Dictionary:
	var actions: Array = []
	for character in player.team.characters:
		if character.used_ability == null:
			continue
		var ability_idx = character.moveset.get_active_abilities(character).find(character.used_ability)
		var target_idxs: Array = []
		for target in character.targeter.targets:
			target_idxs.append(_canonical_index(target))
		actions.append({
			"char_idx": _canonical_index(character),
			"ability_idx": ability_idx,
			"target_idxs": target_idxs,
		})

	# execution_order entries are encoded as canonical character indices for
	# ability steps and offset ticking-effect counter IDs for ticking steps.
	# The legacy local-frame uses 0..2 = acting-team character, 3+ = ticking
	# counter (allocated by get_ticking_effect_information). In the canonical
	# 0..5 frame, indices 3..5 are p2's character slots — they collide with
	# legacy ticking IDs. To keep the wire entries unambiguous we partition
	# the space at 6:
	#   0..5  → canonical character index (action step)
	#   >= 6  → ticking effect counter ID (legacy_id + 3)
	# The server reverses both transforms in apply_input.
	var canonical_exec_order: Array = []
	for entry in exe_order:
		if typeof(entry) == TYPE_INT and entry >= 0 and entry < 3:
			var character = player.team.characters[entry]
			canonical_exec_order.append(_canonical_index(character))
		elif typeof(entry) == TYPE_INT and entry >= 3:
			canonical_exec_order.append(entry + 3)
		else:
			canonical_exec_order.append(entry)

	var exchange_payload = null
	if last_exchange != null:
		var offer_dict: Dictionary = {}
		for energy_type in last_exchange[0].keys():
			offer_dict[int(energy_type)] = int(last_exchange[0][energy_type])
		exchange_payload = {
			"offer": offer_dict,
			"request": int(last_exchange[1]),
		}
	last_exchange = null

	# match_id is left at 0 for Phase 7.2: the client doesn't currently know
	# its own match_id (the match-start RPCs in server_connection don't ship
	# it). The server resolves the match via session.current_match in
	# submit_turn_input, so this field is informational. Phase 7.3 will thread
	# the real match_id end-to-end so the server can reject stale inputs whose
	# match_id no longer matches the live session match.
	return {
		"match_id": 0,
		"turn_number": current_turn_number,
		"actions": actions,
		"execution_order": canonical_exec_order,
		"energy_allocation": random_history,
		"exchange": exchange_payload,
		"timeout": false,
	}


func receive_turn_package(package: Dictionary):
	process_turn_package(package, went_second)


# Server-only: run the acting team's pre-turn energy generation up front so
# Match.validate_input can check affordability against the real pool. Mirrors
# the gen step that process_turn_package would otherwise do on entry. Idempotent
# — the latch prevents duplicate rolls if validation fires more than once before
# apply_input consumes the package.
func prepare_acting_energy_if_needed() -> void:
	if acting_energy_prepared:
		return
	if not shadow_mode:
		return
	# p1-first / mid-match p1 turn: start_new_turn already generated player.team
	# energy. Nothing to do here; just latch so the gen-skip path stays consistent.
	if not waiting_for_turn:
		acting_energy_prepared = true
		return
	# Acting team is enemy.team (canonical p2). Mirror the first= argument that
	# process_turn_package would pass: received_turn_package forwards went_second.
	generate_team_energy(enemy.team, went_second)
	acting_energy_prepared = true


func process_turn_package(package: Dictionary, first: bool = false, last: bool = false):
	var team = player.team
	var team_mod: int = 0
	if waiting_for_turn:
		team = enemy.team
		team_mod = 3
	if team_mod == 3:
		log_turn_header(_current_turn_count + 1)
	# Consume the pre-generation latch on entry so any code path below can run
	# generate_team_energy without worrying about double-rolling. Early-return
	# branches below are already past the gen step, so clearing up front is safe.
	var skip_acting_gen = acting_energy_prepared
	acting_energy_prepared = false
	if package['timeout']:
		if team_mod == 3:
			if last:
				reconnecting = false
			handle_opponent_timeout()
			return
		# See note below: skip team_mod==0 generation on the server-side shadow.
		if not (shadow_mode and team_mod == 0) and not skip_acting_gen:
			generate_team_energy(team, first)
		if last:
			reconnecting = false
		handle_timeout()
		return

	# Server-side shadow already generated player.team's energy via start_new_turn
	# (initial first-turn random energy from start_battle, plus per-character
	# generation between rounds when turn_over -> start_new_turn fires after the
	# opponent's package). The matching client never reaches generate_team_energy
	# through this path either — the local actor goes allotment_accepted ->
	# start_round_loop directly. Letting it run on the shadow would double the
	# acting team's per-turn energy and cause every hash to drift.
	if not (shadow_mode and team_mod == 0) and not skip_acting_gen:
		generate_team_energy(team, first)
	if went_second:
		went_second = false

	if package['exchange'] != null:
		if team_mod == 0:
			accept_exchange(package['exchange'][0], package['exchange'][1])
		else:
			accept_enemy_exchange(package['exchange'][0], package['exchange'][1])

	var character_actions = package['character_actions']
	for action_set in character_actions:
		var index_of_character = action_set[0] + team_mod
		var char = all_characters()[index_of_character]
		var index_of_ability = action_set[1]
		var used_ability = char.moveset.get_active_abilities(char)[index_of_ability]
		team.pay_for_ability(used_ability)
		char.used_ability = used_ability
		char.acted = true
		var target_indexes = action_set[2]
		for target in target_indexes:
			if team_mod == 3:
				if target > 2:
					target -= 3
				else:
					target += 3
			char.targeter.add_target(all_characters()[target])

		var ttype = used_ability.target_type()
		if char.blind_check():
			if ttype == TargetType.Type.ALL or ttype == TargetType.Type.ALL_FACTION or ttype == TargetType.Type.SELF:
				pass
			else:
				used_ability.ability_blinded = true
		execution_order[action_set[0]] = char.used_ability

	# Drain the acting team's pool using the client's aggregated random_history.
	# random_history is [[type, count], ...] in specific colors only (the random
	# panel builds rows from GREEN/BLUE/WHITE/RED and then appends the specific-
	# color promised_pool entries, so nothing keyed RANDOM ever ends up in it).
	# This is also the source of truth for ENERGY_SPENT — emitting the raw
	# ability cost instead would leak the RANDOM key (4) onto the wire, and the
	# passive client's change_energy/lose_energy replay would crash when it hit
	# pool[4], which doesn't exist.
	#
	# The old code only ran this for team_mod == 0, which meant p2's acting turn
	# never actually drained the shadow's enemy.team pool and promised_pool grew
	# unbounded. Always run for the acting team.
	team.energy.receive_generic_allocation_offer(package['random_history'], true)
	var spent_totals: Dictionary = {}
	for entry in package['random_history']:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 2:
			continue
		var element = int(entry[0])
		var count = int(entry[1])
		if count == 0:
			continue
		spent_totals[element] = spent_totals.get(element, 0) + count
	if spent_totals.size() > 0:
		energy_spent_event.emit(_team_role(team), spent_totals)

	var ticking_information = get_ticking_effect_information(team_mod == 3)
	for key in ticking_information.keys():
		ticking_information[key].sort_custom(func (a, b): return a.twin_priority < b.twin_priority)
		execution_order[key] = ticking_information[key]
	true_execution_order = package['execution_order']
	# Passive clients build ticking IDs from display effects, which may
	# group differently than the server's real effects (different id
	# semantics). Sanitize: drop any client entry that isn't a key in the
	# server's execution_order, then append any server ticking keys the
	# client didn't include so nothing is silently skipped.
	true_execution_order = true_execution_order.filter(
		func(e): return e in execution_order
	)
	for key in ticking_information.keys():
		if key not in true_execution_order:
			true_execution_order.append(key)
	if last:
		reconnecting = false
	start_round_loop()


# Phase 8.3: history_loop is gone. Reconnection is snapshot-based now — the
# client seeds its manager with apply_match_state(snapshot) instead of
# replaying every package since turn 0.


# Phase 8: bulk state-load from a wire snapshot.
#
# Called from start_battle_reconnect after characters have been initialized
# and connected, and never again after that. Walks the snapshot with the same
# helpers as _reconcile_to_snapshot so a freshly-built passive manager ends up
# in the exact game state the server had when the reconnection package was
# minted: correct HP, cooldowns, death flags, energy pools, and display
# effects for both sides, plus the acting-side / waiting_for_turn bookkeeping.
#
# The snapshot does not carry used_ability, targets, or mid-execution state,
# which is fine — reconnection always lands on a clean turn boundary (the
# server only serializes between processed packages), so every character is
# pre-turn by construction.
#
# State-load only: no display signals. The caller (start_battle_reconnect)
# emits battle_reconnect_started first and then the turn-start display
# signals, matching the start_battle → battle_started → start_new_turn order.
func apply_match_state(snapshot: Dictionary) -> void:
	# Reset the turn-ordering gate so subsequent apply_turn_result payloads
	# use the reconnected snapshot's turn as the baseline, not whatever this
	# manager had before (which on a fresh manager is -1, but being explicit
	# avoids a stale latch if the same manager is ever reused).
	_highest_seen_turn = int(snapshot.get("current_turn", -1))
	# _reconcile_to_snapshot handles match_over, current_turn_number, energy
	# pools, per-character HP/dead/banished/acted/cooldowns, and display effects.
	# It also fixes the energy display trackers on drift, which here means
	# seeding them from the snapshot since the fresh pool is all zeros.
	set_log_paused(true)
	_reconcile_to_snapshot(snapshot)
	set_log_paused(false)

	# _reconcile_to_snapshot doesn't touch acting-side state because mid-match
	# apply_turn_result carries a TURN_STARTED event that does it instead. On a
	# cold reconnect there is no TURN_STARTED, so derive waiting_for_turn /
	# gamestate from snapshot.acting_role here. This is the same derivation the
	# TURN_STARTED handler uses.
	var acting_role: String = snapshot.get("acting_role", "p1")
	var is_player_turn: bool = (acting_role == "p1" and _role(player) == 0) or (acting_role == "p2" and _role(player) == 1)
	waiting_for_turn = not is_player_turn
	gamestate = Gamestate.OPEN if is_player_turn else Gamestate.CLOSED

	# Mirror the TURN_STARTED event handler: refresh() clears waiting /
	# used_ability / targeted so ability.usable() passes on the acting player's
	# characters. Without this, character.waiting stays latched at its init
	# default of `true` and every skill renders as disabled on reconnect even
	# though it's the player's turn. Matches the all_characters() scope the
	# TURN_STARTED handler uses — both teams get reset at turn start.
	for character in all_characters():
		character.was_countered = false
		character.refresh()
		character.targeted = false
		character.update.emit()

# ===========================================================================
# TIMEOUT HANDLING
# ===========================================================================

func handle_timeout():
	for character in player.team.characters:
		if character.used_ability:
			character.acted_clicked()
	var ticking_information = get_ticking_effect_information()
	true_execution_order = []
	for key in ticking_information.keys():
		ticking_information[key].sort_custom(func (a, b): return a.twin_priority <= b.twin_priority)
		execution_order[key] = ticking_information[key]
		true_execution_order.append(key)
	start_round_loop()


func handle_opponent_timeout():
	# A timeout skips generate_team_energy entirely (see the team_mod == 3 branch in
	# process_turn_package), and generate_team_energy is the ONLY place a pending denial is
	# consumed. Without this line a drain landed before an AFK timeout would survive the skipped
	# turn and eat the generation AFTER it — the denial is defined to expire at the drained team's
	# next generation whether or not it found anything to cancel, and must never reach a second
	# turn. There was no generation to deny here, so the debt is simply forgiven.
	enemy.team.denied_energy_generation = 0
	for character in enemy.team.characters:
		if not character.dead and not character.banished and not character.marked_by("Named Reconstitution"):
			character.generate_energy()

	var ticking_information = get_ticking_effect_information(true)
	true_execution_order = []
	for key in ticking_information.keys():
		ticking_information[key].sort_custom(func (a, b): return a.twin_priority <= b.twin_priority)
		execution_order[key] = ticking_information[key]
		true_execution_order.append(key)
	start_round_loop()

# ===========================================================================
# WIN / LOSS
# ===========================================================================

func check_match_over() -> bool:
	if check_lose_condition():
		end_match(false)
		return true
	if check_win_condition():
		end_match(true)
		return true
	return false


# An EMPTY roster is a CORRUPTED BOARD, not a wiped-out team. Both loops below are vacuous on an
# empty array — they fall straight through to `return true` and check_match_over turns that into a
# real, recorded result: an instant Defeat for a player at full health, or a phantom Victory for
# their opponent (lose is tested before win, so the victim eats the loss either way). A team can only
# empty mid-match through external corruption of the persistent Player object (Match.from_players
# calling team.clear_characters() on a player who still holds this match — see the guard there), so
# treat it as UNDECIDED and shout about it instead.
#
# Deliberately NOT cancelling the match here: Match.cancel_match() sends no frame to either client
# (server_connection.match_ended just releases the players and frees the node), so cancelling would
# strand both of them on a dead battle screen with a session pointer to a freed match. An
# unwinnable-but-live match they can surrender out of is the less harmful failure.
func _report_empty_roster(which: String) -> void:
	# ONE-SHOT per manager: these predicates run after every executed step and every turn, so a
	# per-turn log would bury the live log in seconds.
	if _empty_roster_reported:
		return
	_empty_roster_reported = true
	var pname = str(player.username) if player != null and is_instance_valid(player) else "<invalid>"
	var ename = str(enemy.username) if enemy != null and is_instance_valid(enemy) else "<invalid>"
	var line := "[EMPTY-ROSTER] %s team is EMPTY mid-match (p1=%s, p2=%s, type=%s) — treating the match as UNDECIDED instead of fabricating a result. Something rebuilt a live Player's team." % [which, pname, ename, match_type]
	push_error(line)
	print(line)


func check_lose_condition() -> bool:
	if player.team.characters.is_empty():
		_report_empty_roster("player")
		return false
	for character in player.team.characters:
		if not (character.dead or character.banished):
			return false
	return true


func check_win_condition() -> bool:
	if enemy.team.characters.is_empty():
		_report_empty_roster("enemy")
		return false
	for character in enemy.team.characters:
		if not (character.dead or character.banished):
			return false
	return true


func end_match(won: bool):
	match_over = true
	# won is from the local manager's perspective (player == this client/shadow's
	# p1). On the server-side shadow player is always p1, so winner_role = 0 if
	# won else 1.
	var winner_role: int = _role(player) if won else _role(enemy)
	match_ended_event.emit(winner_role)
	if shadow_mode:
		# Server-side shadow: skip every real-world side effect. Only the
		# match_ended signal is emitted so any local observers can release
		# resources. Rank, AP, bounties, missions, and save are owned by
		# the authoritative server flow in send_match_ending.
		match_ended.emit(won)
		return
	if match_type != MatchType.BOT and match_type != MatchType.PRIVATE:
		match_report_ready.emit(won, {"won": won})
	elif match_type == MatchType.BOT:
		var char_names = player.team.characters.map(func(c): return c.path_name)
		var enemy_names = enemy.team.characters.map(func(c): return c.path_name)
		match_report_ready.emit(won, {"won": won, "bot_match": true, "characters": char_names, "enemy_characters": enemy_names})

	if won and match_type != MatchType.PRIVATE:
		player.rank.add_win(match_type, enemy.rank.get_rating())
	elif not won and match_type != MatchType.PRIVATE:
		player.rank.add_loss(match_type, enemy.rank.get_rating())

	for character in player.team.characters:
		character.check_game_end_triggers(won, self)
	save_mission_progress_requested.emit(player)


	if match_type != MatchType.PRIVATE and won:
		player.check_all_bounties(
			player.team.characters.map(func(c): return c.path_name),
			enemy.team.characters.map(func(c): return c.path_name)
		)
	save_player()
	# Drop any pending records the live bot's contextual turns accumulated
	# this match. We never call commit_match in the live path — player-vs-bot
	# outcomes shouldn't pollute the trained model (training is the harness's
	# job). commit_draw is a no-op on an empty buffer, so this is safe to
	# call even when match_type != BOT.
	if _live_bot_model != null:
		_live_bot_model.commit_draw()
	match_ended.emit(won)


func return_to_char_select():
	player.team.reset_energy_pool()
	for character in player.team.characters:
		character.effects._effects.clear()
		character.health.hp = 100
		character.dead = false
		character.banished = false
		character.acted = false
		character.used_ability = null
		character.targeter.reset()
		for ability in character.moveset.abilities:
			ability.cooldown_remaining = 0
			ability.cooldown_started_turn = -1
		character.update.emit()
	for character in enemy.team.characters:
		character.effects._effects.clear()
		character.health.hp = 100
		character.dead = false
		character.acted = false
		character.banished = false
		character.used_ability = null
		character.targeter.reset()
		for ability in character.moveset.abilities:
			ability.cooldown_remaining = 0
			ability.cooldown_started_turn = -1
		character.update.emit()
	char_select_return_requested.emit(player)

# ===========================================================================
# TARGETING UTILITIES
# ===========================================================================

func get_other_aoe_targets(targeter, main_target, faction_specific, and_check: bool = false):
	for character in all_characters():
		if not (character in targeter.targeter.targets) and not character == main_target and character.targeted and (not faction_specific or not are_characters_hostile(character, main_target)) and (not and_check or targeter.used_ability.and_target(character)):
			targeter.targeter.add_target(character)


func get_valid_random_targets(char):
	var hostile: bool = true
	if char.targeter.main_target in char.team.characters:
		hostile = false
	char.targeter.clear_targets()
	var output: Array = []
	char.targeter.targeting_ability = char.used_ability
	char.targeter.targeting_ability.target(char, self)

	for character in all_characters():
		if character.targeted and (character in char.team.characters or (hostile and not character in char.team.characters)):
			output.append(character)
	var target_roll = roll(0, len(output) - 1, "Valid Random Targets")
	var new_target = output[target_roll]
	char.targeter.add_target(new_target)
	char.targeter.main_target = new_target

# ===========================================================================
# PUBLIC API — called by abilities, characters, QueryContext, and triggers
# ===========================================================================

func all_characters() -> Array:
	return player.team.characters + enemy.team.characters


func get_team_factions_from_character(character) -> Array:
	if character in player.team.characters:
		return [player.team, enemy.team]
	else:
		return [enemy.team, player.team]


func are_characters_hostile(first, second) -> bool:
	if first in player.team.characters:
		return second in enemy.team.characters
	else:
		return second in player.team.characters


func find_enemy_by_path(ref_character, path):
	for character in all_characters():
		if character.path_name == path:
			if are_characters_hostile(ref_character, character):
				return character
	return false


func get_player_owner(character):
	if character in player.team.characters:
		return player
	if character in enemy.team.characters:
		return enemy
	return null


## Deterministic RNG — seeded so both clients produce the same results.
## In passive mode the server owns RNG; the client never rolls. Returning
## 0 keeps any caller that ignores the result happy and surfaces a clear
## "this code path should never run on a passive client" pattern in any
## caller that does use the result. After Phase 7 there should be no
## remaining call sites that hit this branch.
func roll(min_val: int, max_val: int, desc: String = "None") -> int:
	if passive:
		return 0
	var result = die.randi_range(min_val, max_val)
	return result


## Emits a message for the display layer to show.
## Abilities/triggers call this as `battle.request_message(...)`.
func request_message(message: String):
	message_request.emit(message)


## Emits an urgent message for the display layer to show.
func demand_message(message: String):
	message_demand.emit(message)


var _current_turn_count: int = 0
var _log_paused: bool = false

func set_log_paused(paused: bool):
	_log_paused = paused

func emit_log_event(event):
	if event == null or _log_paused:
		return
	if event.turn == 0:
		event.turn = _current_turn_count
	log_event.emit(event)

func _resolve_wire_ability(character, ability_name: String):
	if character == null or ability_name == "":
		return null
	if character.moveset == null:
		return null
	for ability in character.moveset.get_active_abilities(character):
		if ability.ability_name == ability_name:
			return ability
	for ability in character.moveset.base_abilities:
		if ability.ability_name == ability_name:
			return ability
	return null

func log_ability_use(user, ability):
	if ability != null:
		if "invisible" in ability and ability.invisible:
			return
		if "classes" in ability and ability.classes is Dictionary and ability.classes.get("Passive", false):
			return
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.ABILITY_USE).with_actor(user).with_ability(ability))

func log_damage(dealer, target, amount, damage_type, source_ability = null, source_effect = null):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.DAMAGE).with_actor(dealer).with_target(target).with_amount(amount).with_damage_type(damage_type)
	if source_ability != null:
		event.with_ability(source_ability)
	if source_effect != null:
		event.with_effect(source_effect)
	emit_log_event(event)

func log_healing(healer, target, amount, source_ability = null, source_effect = null):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.HEALING).with_actor(healer).with_target(target).with_amount(amount)
	if source_ability != null:
		event.with_ability(source_ability)
	if source_effect != null:
		event.with_effect(source_effect)
	emit_log_event(event)

func log_effect_applied(applier, target, effect):
	if effect == null or effect.invisible or (effect.system and not effect.display_system):
		return
	if effect.effect_type == EffectType.Type.COUNTER_TRIGGER_NOTIFICATION or effect.effect_type == EffectType.Type.INVISIBLE_EXPIRATION:
		return
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.EFFECT_APPLIED).with_actor(applier).with_target(target).with_effect(effect))

func log_effect_expired(target, effect, reason: String = "expired"):
	if effect == null or effect.invisible or (effect.system and not effect.display_system):
		return
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.EFFECT_EXPIRED).with_target(target).with_effect(effect).with_extra("reason", reason))

func log_counter(actor):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.COUNTER).with_actor(actor))

func log_reflect(actor):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.REFLECT).with_actor(actor))

func log_invuln_block(actor, target, ability = null):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.INVULN_BLOCK).with_actor(actor).with_target(target)
	if ability != null:
		event.with_ability(ability)
	emit_log_event(event)

func log_miss(actor, target):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.MISS).with_actor(actor).with_target(target))

func log_death(character):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.DEATH).with_actor(character))

func log_revive(character):
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.REVIVE).with_actor(character))

func log_energy_gain(team, element_name: String):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.ENERGY_GAIN).with_extra("element", element_name)
	if team != null and team.characters.size() > 0:
		event.with_actor(team.characters[0])
	emit_log_event(event)

func log_turn_header(turn_number: int, who: String = ""):
	_current_turn_count = turn_number
	emit_log_event(BattleLogEvent.make(BattleLogEvent.Kind.TURN_HEADER).with_extra("who", who))

func log_system(text: String, demand: bool = false):
	var event = BattleLogEvent.make(BattleLogEvent.Kind.SYSTEM).with_extra("text", text)
	if demand:
		event.as_demand()
	emit_log_event(event)


## Called by UI code via character.battle.show_panel(...).
## Emits a signal so the display layer can handle the actual panel display.
func show_panel(tooltip, panel):
	show_panel_requested.emit(tooltip, panel)


func save_player():
	save_player_requested.emit(player)


func package_match_report(won: bool):
	return {}


func receive_surrender():
	# After Phase 7.7 the server always broadcasts MATCH_ENDED via
	# apply_turn_result before this RPC arrives, so match_over is already true
	# and end_match would be a redundant double-fire (extra rank increment,
	# double save_player, redundant signals). Bail out in passive mode if the
	# match is already over.
	if passive and match_over:
		return
	end_match(true)


func stringify_gamestate():
	player.team.pretty_print()
	enemy.team.pretty_print()


func serialize_gamestate() -> Dictionary:
	# Perspective-independent game state for shadow validation. The server's
	# BattleManager has player=P1, enemy=P2 by construction; each client has
	# player=local-user. Keying by username (sorted) gives all three managers
	# the same shape for the same physical state.
	#
	# Deliberate omissions:
	#   - waiting_for_turn: between turns the sender is in wait_for_turn() and
	#     the receiver has already advanced through start_new_turn(); they will
	#     never agree on this flag at hash time.
	#   - energy pools: the local-actor branch of process_turn_package commits
	#     payment via receive_generic_allocation_offer (clearing promised_pool
	#     and decrementing pool), while the opponent branch leaves the cost in
	#     promised_pool and never touches pool. true_pool matches across sides
	#     but the start_new_turn timing for the *next* turn's generation still
	#     differs by one package between sender and receiver, so excluding
	#     energy from the hash is the only way to keep this stable.
	#   - acted / used_ability: refresh() resets both during turn_over before
	#     control returns from process_turn_package, so they're always cleared
	#     by the time the snapshot is taken — no signal worth hashing.
	var output := {}
	output["match_over"] = match_over
	var sides := []
	sides.append(_serialize_side(player))
	sides.append(_serialize_side(enemy))
	sides.sort_custom(func (a, b): return a["username"] < b["username"])
	output["sides"] = sides
	return output


func _serialize_side(p) -> Dictionary:
	return {
		"username": p.username,
		"team": _serialize_team(p.team),
	}


func _serialize_team(team) -> Array:
	var characters := []
	for character in team.characters:
		var char_dict := {
			"path_name": character.path_name,
			"hp": character.health.hp,
			"dead": character.dead,
			"banished": character.banished,
		}
		var abilities := []
		for ability in character.moveset.get_active_abilities(character):
			abilities.append({
				"ability_name": ability.ability_name,
				"cooldown_remaining": ability.cooldown_remaining,
			})
		char_dict["abilities"] = abilities
		char_dict["effects"] = _serialize_effects_for_hash(character.effects._effects)
		characters.append(char_dict)
	return characters


func _serialize_effects_for_hash(effects: Array) -> Array:
	# Flat, sorted list of effects keyed only by stable values. The original
	# get_effect_clusters() grouping is unsuitable here because:
	#   1. Cluster keys include effect.unique_render_id which several abilities
	#      assign from int(Time.get_ticks_msec()) — wall-clock time differs
	#      across server and clients, so cluster grouping diverges.
	#   2. The grouping function filters invisible-on-enemy effects based on
	#      effect.user.enemy, and that flag is perspective-dependent (P2's own
	#      invisible effects are visible to the P2 client but filtered out on
	#      the server and the P1 client).
	# We also drop effect.description because it's a Callable that can return
	# stat-derived strings.
	var entries := []
	for effect in effects:
		# Same rule as the wire loop: display_system effects ARE part of the visible state.
		if effect.system and not effect.display_system:
			continue
		entries.append({
			"name": effect.effect_name(),
			"user": effect.user.path_name,
			"source": effect.source.get_script().resource_path.get_file().get_basename(),
			"duration": effect.duration,
		})
	entries.sort_custom(func (a, b):
		if a["name"] != b["name"]:
			return a["name"] < b["name"]
		if a["user"] != b["user"]:
			return a["user"] < b["user"]
		if a["source"] != b["source"]:
			return a["source"] < b["source"]
		return a["duration"] < b["duration"]
	)
	return entries


# Stable digest of the current gamestate, used by Phase 2 shadow validation
# to compare server view against the clients. Two managers that ran identical
# logic on identical inputs must produce identical hashes.
func compute_state_hash() -> String:
	var state = serialize_gamestate()
	var json_str = JSON.stringify(state)
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(json_str.to_utf8_buffer())
	return ctx.finish().hex_encode()


# ===========================================================================
# PHASE 5 — wire-protocol helpers
# ===========================================================================

# Canonical role of a player object: 0 = p1, 1 = p2. The server-side shadow
# always has player == p1 by construction, so role(player) == 0; on a client
# the local user's role depends on which seat they joined.
func _role(p) -> int:
	if p == player:
		return local_canonical_role
	return 1 - local_canonical_role


func _team_role(team) -> int:
	if team == player.team:
		return local_canonical_role
	return 1 - local_canonical_role

# P6: does `team` belong to an Ultra Bot? Maps the team back to its seated Player (the player/enemy
# split) and reads the durable flag. Only the authoritative side reaches the enhanced roll (passive
# clients apply the credited colours via energy_gained_event and never generate), so this is safe.
func _team_is_ultra_bot(team) -> bool:
	var owner = player if team == player.team else enemy
	return owner != null and owner.is_ultra_bot


# Canonical 0..5 index of a character in the protocol's frame: p1[0..2] then
# p2[0..2]. On the shadow this matches all_characters() directly. On a client
# whose local player is p2, this swaps the halves so the server and the
# remote client all agree on the same numeric coordinate for the same chair.
func _canonical_index(character) -> int:
	var local = all_characters().find(character)
	if local == -1:
		return -1
	if _role(player) == 0:
		return local
	# Local p2: local indices 0..2 are this client's player.team (canonical 3..5),
	# local indices 3..5 are this client's enemy.team (canonical 0..2).
	if local < 3:
		return local + 3
	return local - 3


# Wire-format snapshot, used as the trailing payload of apply_turn_result.
# Unlike serialize_gamestate (which sorts sides by username for hashing),
# this is index-stable: sides[0] is always p1, sides[1] is always p2. The
# server is the sole producer, so the canonical order is the natural one.
func serialize_wire_snapshot() -> Dictionary:
	var acting_role_str := "p1" if (_role(player) if not waiting_for_turn else _role(enemy)) == 0 else "p2"
	return {
		"match_over": match_over,
		"current_turn": current_turn_number,
		"acting_role": acting_role_str,
		"execution_preview": _serialize_execution_preview(),
		"sides": [
			_serialize_wire_side(player, "p1"),
			_serialize_wire_side(enemy, "p2"),
		],
	}


# Ticking-effect execution preview for the ACTING team, baked into every snapshot so
# the thin web client can list + drag-reorder ticking steps alongside its staged skills.
# Computed with the EXACT get_ticking_effect_information(is_enemy) the apply path uses
# (process_turn_package keys ticking by team_mod==3, i.e. waiting_for_turn), on the same
# frozen board — so each order_id the client sends back maps to the identical
# execution_order key at resolution time. order_id is the WIRE frame (legacy counter + 3,
# i.e. >= 6), matching build_turn_input's ticking encoding; the client merges these with
# its skill steps (canonical char_idx 0..5) into one reorderable list.
func _serialize_execution_preview() -> Array:
	var ticking := get_ticking_effect_information(waiting_for_turn)
	var out: Array = []
	for key in ticking.keys():
		var group = ticking[key]
		if typeof(group) != TYPE_ARRAY or group.is_empty():
			continue
		var first = group[0]
		# Hidden machinery ticks (system == true, e.g. Minene's Explosives Detonator incrementer) are
		# filtered from the on-board effect list by the wire-effects loop; keep them out of the player-facing
		# reorder preview too, or they surface as phantom draggable tiles with no matching visible effect.
		# Execution is unaffected — it reads _effects directly, so the tick still resolves at its default slot.
		if first.system and not first.display_system:
			continue
		var user_name := ""
		if first.user != null:
			user_name = str(first.user.character_name)
		var type_name := "Effect"
		match int(first.effect_type):
			EffectType.Type.DAMAGE: type_name = "Damage"
			EffectType.Type.HEALING: type_name = "Healing"
			EffectType.Type.TICKING_TRIGGER: type_name = "Ticking effect"
			EffectType.Type.DELAYED_SKILL: type_name = "Delayed skill"
		var src_name := ""
		if first.source != null:
			src_name = str(first.source.ability_name)
		var icon_path := ""
		if first.tooltip != null and first.tooltip is Resource:
			icon_path = first.tooltip.resource_path
		out.append({
			"order_id": int(key) + 3,
			"label": user_name + "'s " + type_name + " from " + src_name,
			"source_ability_name": src_name,
			"icon_path": icon_path,
		})
	return out


func _serialize_wire_side(p, role_str: String) -> Dictionary:
	return {
		"username": p.username,
		"role": role_str,
		"energy": _serialize_energy_pool(p.team),
		"team": _serialize_wire_team(p.team),
	}


func _serialize_energy_pool(team) -> Dictionary:
	var pool := {}
	var promised := {}
	for energy_type in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		pool[int(energy_type)] = team.energy.pool[energy_type]
		promised[int(energy_type)] = team.energy.promised_pool[energy_type]
	return {
		"pool": pool,
		"promised_pool": promised,
		# Points of this team's NEXT generation already owed to unpayable drains.
		# Serialized so the client can warn the player before they plan a turn
		# around energy that will not arrive; nothing renders it yet.
		"denied_next_generation": team.denied_energy_generation,
	}


func _serialize_wire_team(team) -> Array:
	var characters := []
	for character in team.characters:
		var char_dict := {
			"path_name": character.path_name,
			"hp": character.health.hp,
			"max_hp": character.get_modified_max_hp(),
			"dead": character.dead,
			"banished": character.banished,
			"acted": character.acted,
		}
		# Same reason as the inline ability desc below: an authored character isn't
		# in the client's roster.json, so its name can't be looked up from path_name
		# ("auth_zz_creat_1785090781" would title-case into gibberish).
		if character is AuthoredCharacter:
			char_dict["display_name"] = character.character_name
		var abilities := []
		for ability in character.moveset.get_active_abilities(character):
			# Resolve cost once on the server. The passive client has no runtime
			# _effects to evaluate COST_CHANGE / COST_MOD / COLOR_CHANGE against,
			# so it can't compute this locally — it reads this field verbatim.
			# Keys are int enums; the dict may round-trip through JSON on the
			# reconnect path, so serialize keys and values as ints for a stable
			# shape on both wire paths (the reconcile loop re-keys via int()).
			var live_cost = ability.cost()
			var cost_dict := {}
			for element in live_cost.keys():
				cost_dict[int(element)] = int(live_cost[element])
			# Resolve the full usable() state on the server for the same reason
			# as cost: is_stunned / is_skill_currently_delayed / effect-reading
			# extra_usable() walk _effects, and on the passive client that array
			# is empty so every stunned/delayed/banished ability would report
			# usable. Pre-evaluate here; the passive client's usable() trusts
			# this and only layers local UI state on top.
			#
			# Use authoritative_usable() (not usable()) so the shadow doesn't
			# fold its own waiting_for_turn / used_ability / character.waiting
			# state into the shipped value. The shadow always runs from
			# canonical p1's perspective, so when p2 is the first player the
			# shadow is sitting in wait_for_turn and usable() would return
			# false for every ability on both teams. The passive client
			# layers its own waiting_for_turn / waiting gates on top.
			# `source_basename` is the JSON key (e.g. "mavis6") of the underlying
			# script — equivalent to how Effect.copy_effect() derives mod_path —
			# so the passive client can reconstruct SKILL_COPY-overridden slots
			# via Ability.from_database() when the name isn't in the recipient's
			# own base_abilities. Empty when the script can't be resolved.
			var ability_script = ability.get_script()
			var source_basename := ""
			if ability_script != null:
				var script_path: String = ability_script.resource_path
				if script_path.begins_with("res://abilities/") and script_path.ends_with(".gd"):
					source_basename = script_path.substr(16, script_path.length() - 3 - 16)
			var ability_dict := {
				"ability_name": ability.ability_name,
				"source_basename": source_basename,
				"cooldown_remaining": ability.cooldown_remaining,
				"cost": cost_dict,
				"usable": bool(ability.authoritative_usable(character, true)),   # non-energy usability; clients check affordability themselves (so a pending exchange counts)
			}
			# Compute valid targets for every ability on the server. Passive
			# clients have no runtime _effects, so they can't evaluate
			# invulnerability, isolation, marks, target changes, or any other
			# effect-dependent targeting condition locally. Ship the full
			# server-resolved target set and target_type for each ability so
			# the client uses them verbatim instead of calling target().
			ability_dict["special_targets"] = _compute_special_targets(ability, character)
			ability_dict["target_type"] = int(ability.target_type())
			# The client's ability_info.json is generated from the shipped roster,
			# so an authored skill has no entry there and its panel would read
			# "(description unavailable)". Ship the generated segments inline —
			# only for authored abilities, so the wire doesn't grow for the 170
			# hand-written characters that already have a client-side copy.
			if ability is ScriptedAbility:
				var segs := []
				for seg in ability.split_desc():
					if seg is Array:
						var col := "" if seg.size() < 2 else "#" + (seg[1] as Color).to_html(false)
						segs.append({"text": str(seg[0]), "color": col})
					else:
						segs.append({"text": str(seg), "color": ""})
				ability_dict["desc"] = segs
				ability_dict["cooldown"] = ability.cooldown
				# Skill art lives on the game server, not the static asset host, so
				# the client needs the (character, slot) pair to pull it. An empty
				# icon_slot means "no art uploaded" — shipping the pair only when it
				# exists is what stops the client firing pointless fetches.
				if ability.icon_slot != "":
					ability_dict["icon_char"] = character.path_name
					ability_dict["icon_slot"] = ability.icon_slot
			abilities.append(ability_dict)
		char_dict["abilities"] = abilities
		# Server-resolved portrait override. PORTRAIT_CHANGE / DISGUISE effects
		# are marked system=true so they're filtered out of the wire effects list
		# below, and active_portrait() on the passive client walks _effects which
		# is empty — without this field the client would always render the base
		# portrait even when the shadow is mid-transformation. -1 / "" mean
		# "default portrait"; the reconciler treats a present field (even with
		# default values) as authoritative so effects ending properly revert.
		var portrait_alt := -1
		var portrait_disguise := ""
		for swap in character.effects.get_effects_by_type(EffectType.Type.PORTRAIT_CHANGE):
			if not swap.source in character.moveset.base_abilities:
				continue
			portrait_alt = int(swap.mag)
		for disguise in character.effects.get_effects_by_type(EffectType.Type.DISGUISE):
			portrait_disguise = str(disguise.mag)
		char_dict["portrait_alt"] = portrait_alt
		char_dict["portrait_disguise"] = portrait_disguise
		# Sung Jin-woo's equipped summon ("" for everyone else) so the opponent's client can label the
		# form and browse the correct hidden kit. The form's live skills already ride `abilities`.
		char_dict["summon_form"] = character.summon_form
		var wire_effects: Array = []
		for effect in character.effects._effects:
			# system = machinery, stripped from the wire. display_system opts an effect out of the
			# hiding while keeping system's cleanse-survival semantics — see Effect.display_system.
			if effect.system and not effect.display_system:
				continue
			wire_effects.append(_serialize_wire_effect(effect))
		char_dict["effects"] = wire_effects
		characters.append(char_dict)
	return characters


# Run the ability's target() function on the server's real state and collect
# the canonical indices of every character it flags as targetable. target()
# mutates character.targeted via set_targeted(), so we snapshot every flag
# around the call and restore it after — otherwise the server's UI-less
# targeted state (used by reset_character_targeted, reconnect snapshots, etc.)
# would permanently drift from whatever ability was last serialized. Each
# ability is probed independently, so overlapping target sets don't bleed
# between abilities.
func _compute_special_targets(ability, character) -> Array:
	var saved_flags := []
	var chars = all_characters()
	for c in chars:
		saved_flags.append(c.targeted)
		c.targeted = false
	ability.target(character, self)
	var result: Array = []
	for i in range(chars.size()):
		if chars[i].targeted:
			result.append(_canonical_index(chars[i]))
	# Diagnostic: log what the server computed for this ability so we can
	# trace invulnerability / isolation issues on the wire.
	var invuln_names := []
	for c in chars:
		if c.is_invuln(ability):
			invuln_names.append(c.path_name)
	for i in range(chars.size()):
		chars[i].targeted = saved_flags[i]
	return result


func _serialize_wire_effect(effect) -> Dictionary:
	var source_basename := ""
	var source_ability_name := ""
	var is_physical := false
	if effect.source != null:
		source_basename = effect.source.get_script().resource_path.get_file().get_basename()
		source_ability_name = effect.source.ability_name
		if "classes" in effect.source and effect.source.classes is Dictionary:
			is_physical = bool(effect.source.classes.get("Physical", false))
	var user_path := ""
	if effect.user != null:
		user_path = effect.user.path_name
	var visibility := "all"
	if effect.invisible:
		if effect.user != null and effect.user.enemy:
			visibility = "enemy_hidden"
		else:
			visibility = "user_only"
	# Resolve the description text once on the server. Description Callables
	# read live mag/duration/etc. off the effect, so we have to bake here
	# rather than passing the lambda over the wire (which is impossible).
	var description_text := ""
	if effect.description is Callable:
		description_text = str(effect.description.call(effect))
	elif effect.description is String:
		description_text = effect.description
	var icon_path := ""
	if effect.tooltip != null and effect.tooltip is Resource:
		icon_path = effect.tooltip.resource_path
	# effect.mag is the main offender — abilities store arbitrary state in it
	# (koro1 sets mag = Array of class names, megumi5 sets mag = String class
	# label, erza_armor_effect sets mag = String armor name). int(Array) /
	# int(Dictionary) crashes with "Nonexistent 'int' constructor", so sanitize
	# to numeric via _safe_int. Effects whose mag isn't a number aren't
	# displayed as a number on the client anyway — display_mag is only set true
	# for effects that really do track an integer, so defaulting to 0 is safe
	# on the wire. duration / unique_render_id / stacks are ints by convention
	# but go through the same safety net for cheap insurance.
	return {
		# effect_type is part of the id so that abilities which spawn multiple
		# different effects from the same source (e.g. midoriya4: damage_reduction
		# + damage_mod + ignore_effect + trigger, all with set_source(self))
		# produce distinct wire ids. Without it add_display_effect's id dedupe
		# collapses them and only the first effect survives on the passive client.
		"id": str(effect.effect_name()) + "@" + user_path + "@" + source_basename + "@" + str(int(effect.effect_type)),
		"name": str(effect.effect_name()),
		"display_name": str(effect.effect_name()),
		"user": _canonical_index(effect.user) if effect.user != null else -1,
		"source": source_basename,
		"source_ability_name": source_ability_name,
		"effect_type": int(effect.effect_type),
		"duration": _safe_int(effect.duration),
		"mag": _safe_int(effect.mag),
		"stack_count": _safe_int(effect.stack_count()),
		"display_mag": bool(effect.display_mag),
		"display_stacks": bool(effect.display_stacks),
		"unique_render_id": _safe_int(effect.unique_render_id),
		"description": description_text,
		"is_physical": is_physical,
		"system": bool(effect.system),
		"display_system": bool(effect.display_system),
		"invisible": bool(effect.invisible),
		"visibility": visibility,
		"icon_path": icon_path,
	}


# Coerce a possibly-non-numeric value to int for wire serialization. Returns 0
# for anything that int() would refuse (Array, Dictionary, Object, Callable,
# Vector, null). Used for effect fields where abilities overload the slot with
# string/array state (see koro1.mag, megumi5.mag, erza_armor_effect.mag).
func _safe_int(v) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v)
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_STRING:
			return int(v)
		_:
			return 0


# ===========================================================================
# PHASE 6 — passive-mode event consumption
# ===========================================================================

# Highest snapshot.current_turn we have seen, used to discard out-of-order
# RPC delivery on reconnect (MATCH_PROTOCOL.md § 6.3).
var _highest_seen_turn: int = -1


## Server is broadcasting the result of a turn. Replay each event into local
## state, then reconcile against the trailing snapshot.
##
## Phase 7: `passive` is set to true in start_battle for any non-bot match,
## so this is the live state-update path on a multiplayer client. Bot matches
## leave passive at false and continue to run the local sim, so the early
## return preserves the bot path.
func apply_turn_result(events: Array, snapshot: Dictionary) -> void:
	if not passive:
		return
	# Discard stale payloads. The client tracks the highest current_turn it
	# has seen; an apply with a smaller turn is from before a reconnect race.
	var snap_turn: int = int(snapshot.get("current_turn", -1))
	if snap_turn != -1 and snap_turn < _highest_seen_turn:
		push_warning("[PROTOCOL] Discarding stale apply_turn_result snap_turn=", snap_turn,
			" highest_seen=", _highest_seen_turn)
		return
	_highest_seen_turn = max(_highest_seen_turn, snap_turn)

	await _apply_events_paced(events)
	_reconcile_to_snapshot(snapshot)


# Plays the wire-event stream with the same per-action pacing as active mode.
# Events are grouped: each ABILITY_USED owns all following events until the
# next ABILITY_USED. Preamble (before first ABILITY_USED) and trailing events
# (e.g., end-of-turn ticks) form non-ability groups.
func _apply_events_paced(events: Array) -> void:
	_set_in_playback(true)
	_start_playback_watchdog()
	var groups := _group_events_by_action(events)
	for group in groups:
		await _apply_event_group(group)
		if check_match_over():
			_clear_playback_watchdog()
			_set_in_playback(false)
			return
	_clear_playback_watchdog()
	_set_in_playback(false)


func _group_events_by_action(events: Array) -> Array:
	var groups: Array = []
	var current: Array = []
	var current_is_ability := false
	for event in events:
		var t = event.get("type", "")
		if t == "ABILITY_USED":
			if current.size() > 0:
				groups.append({"events": current, "is_ability": current_is_ability})
			current = [event]
			current_is_ability = true
		else:
			current.append(event)
	if current.size() > 0:
		groups.append({"events": current, "is_ability": current_is_ability})
	return groups


var _currently_applying_ticking: bool = false


func _apply_event_group(group: Dictionary) -> void:
	var group_events: Array = group["events"]

	# Resolve the actor + ability for ability groups BEFORE applying any
	# events. A trailing TURN_STARTED for the next player can land in the
	# last action's group, and its handler calls character.refresh() which
	# nulls used_ability — so reading after the loop would lose the ability
	# reference for the final action's overlay.
	var actor = null
	var ability = null
	if group["is_ability"]:
		var first: Dictionary = group_events[0]
		actor = _char_at(int(first["char_idx"]))
		if actor != null:
			var abilities = actor.moveset.get_active_abilities(actor)
			var ability_idx := int(first["ability_idx"])
			if ability_idx >= 0 and ability_idx < abilities.size():
				ability = abilities[ability_idx]

	# Non-ability groups in the wire stream are ticking effects (or other
	# bookkeeping). DAMAGE/HEALING events within them should surface as
	# ticking floats, not ability hits — set the flag so _apply_event can
	# tag the signal emit correctly.
	_currently_applying_ticking = not group["is_ability"]
	for event in group_events:
		_apply_event(event)
	_currently_applying_ticking = false

	if group["is_ability"]:
		# Opponent-invisible abilities skip both the animation emit and the
		# pacing pause so attentive players can't detect them from a hitch
		# in the playback rhythm. The owning player still sees their own
		# invisible-skill animations and pacing — invisibility is only
		# hidden from the OTHER side.
		if _should_show_action(actor, ability):
			if actor != null and is_instance_valid(actor) and not actor.dead and not actor.banished:
				actor.acted_animation_requested.emit(ability)
			await _await_pacing(ACTED_ANIM_HOLD + POST_ACTED_GAP + FEEDBACK_HOLD)
	else:
		if _group_has_visible_feedback(group_events):
			await _await_pacing(TICKING_BATCH_HOLD)


func _group_has_visible_feedback(events: Array) -> bool:
	for event in events:
		var t = event.get("type", "")
		if t == "DAMAGE" or t == "HEALING" or t == "EFFECT_ADDED" or t == "DIED" or t == "BANISHED":
			return true
	return false


# Single-event dispatcher. Each branch mutates local state and re-emits the
# existing manager signals so existing UI handlers (animations, message
# popups, etc.) fire as if the local sim had produced the event.
func _apply_event(event: Dictionary) -> void:
	var event_type = event.get("type", "")
	match event_type:
		"TURN_STARTED":
			current_turn_number = int(event["turn_number"])
			log_turn_header(current_turn_number)
			var acting_role: String = event["acting_role"]
			var is_player_turn: bool = (acting_role == "p1" and _role(player) == 0) or (acting_role == "p2" and _role(player) == 1)
			waiting_for_turn = not is_player_turn
			gamestate = Gamestate.OPEN if is_player_turn else Gamestate.CLOSED
			# Mirror start_new_turn's per-character reset — the shadow does
			# this inside its own start_new_turn / wait_for_turn, but passive
			# clients skip those paths so used_ability / acted / was_countered
			# stay latched from last turn unless we refresh here. Without this
			# a second use of the same skill is blocked by validation.
			for character in all_characters():
				character.was_countered = false
				character.refresh()
				character.targeted = false
				character.update.emit()
			turn_started.emit(is_player_turn)
			if not is_player_turn:
				waiting_for_opponent.emit()
			else:
				refreshing.emit()

		"TURN_ENDED":
			pass

		"ENERGY_GAINED":
			var side_team = _team_for_side(event["side"])
			if side_team != null:
				for energy_type in event["energy_list"]:
					side_team.change_energy(int(energy_type), 1)

		"ENERGY_SPENT":
			var spent_team = _team_for_side(event["side"])
			# Skip replay for the local acting side — the client already drained
			# its pool via random_panel.get_total_offer / pay_for_ability before
			# submitting the turn package. Replaying would double-drain and push
			# the display tracker to negative. The opponent's side still needs
			# the replay because nothing local touched it.
			if spent_team != null and spent_team != player.team:
				var spent_dict: Dictionary = event["spent"]
				for energy_type in spent_dict.keys():
					spent_team.energy.change_energy(int(energy_type), -int(spent_dict[energy_type]))

		"ENERGY_EXCHANGED":
			var ex_team = _team_for_side(event["side"])
			if ex_team != null:
				var offer: Dictionary = event["offer"]
				for energy_type in offer.keys():
					ex_team.energy.change_energy(int(energy_type), -int(offer[energy_type]))
				ex_team.energy.change_energy(int(event["request"]), 1)
				for character in ex_team.characters:
					character.update.emit()
				exchange_processed.emit()

		"ABILITY_USED":
			var actor = _char_at(event["char_idx"])
			if actor != null:
				var ability = actor.moveset.get_active_abilities(actor)[int(event["ability_idx"])]
				actor.targeter.clear_targets()
				for target_idx in event["targets"]:
					var t = _char_at(int(target_idx))
					if t != null:
						actor.targeter.add_target(t)
				actor.used_ability = ability
				log_ability_use(actor, ability)
				ability_will_execute.emit(actor, ability)

		"DAMAGE":
			var dmg_target = _char_at(event["target"])
			if dmg_target != null:
				var dmg_amount := int(event["amount"])
				dmg_target.health.modify_hp(-dmg_amount, null, null)
				dmg_target.update.emit()
				var dealer = null
				if event.get("from") != null:
					dealer = _char_at(int(event["from"]))
				var src_ability = _resolve_wire_ability(dealer, str(event.get("source", "")))
				log_damage(dealer, dmg_target, dmg_amount, -1, src_ability, null)
				if dmg_amount > 0:
					var dtype := int(event.get("damage_class", -1))
					dmg_target.damage_received.emit(dmg_amount, src_ability, dealer, _currently_applying_ticking, dtype)

		"HEALING":
			var heal_target = _char_at(event["target"])
			if heal_target != null:
				var heal_amount := int(event["amount"])
				heal_target.health.modify_hp(heal_amount, null, null)
				heal_target.update.emit()
				var healer = null
				if event.get("from") != null:
					healer = _char_at(int(event["from"]))
				var heal_src = _resolve_wire_ability(healer, str(event.get("source", "")))
				log_healing(healer, heal_target, heal_amount, heal_src, null)
				if heal_amount > 0:
					heal_target.healing_received.emit(heal_amount, heal_src, healer, _currently_applying_ticking)

		"SHIELDED":
			# No client-side state for shields beyond the source effect, which
			# arrives via EFFECT_ADDED. The event is informational.
			pass

		"EFFECT_ADDED":
			# Build a DisplayEffect from the wire payload and attach it to the
			# target character's storage. Runtime Effects can't be rebuilt
			# (Callables / triggers / mission hooks), so passive clients use
			# the simpler display-only type for tooltip rendering.
			var ea_target = _char_at(int(event["target"]))
			if ea_target != null:
				var payload: Dictionary = event["effect"]
				var owner_user = _char_at(int(payload.get("user", -1)))
				var de = DisplayEffect.from_payload(payload, owner_user)
				ea_target.effects.add_display_effect(de)
				ea_target.update.emit()
				log_effect_applied(owner_user, ea_target, de)

		"EFFECT_REMOVED":
			var er_target = _char_at(int(event["target"]))
			if er_target != null:
				er_target.effects.remove_display_effect_by_id(event["effect_id"])
				er_target.update.emit()

		"EFFECT_TICK":
			# Optional protocol event — not currently emitted by the recorder.
			# When it lands, update mag/duration on the existing display effect
			# without rebuilding it so animation state isn't disturbed.
			var et_target = _char_at(int(event["target"]))
			if et_target != null:
				var de_existing = et_target.effects.get_display_effect_by_id(event["effect_id"])
				if de_existing != null and event.has("payload"):
					de_existing.apply_payload(event["payload"], de_existing.user)
					et_target.update.emit()

		"COOLDOWN_SET":
			var cd_char = _char_at(event["char_idx"])
			if cd_char != null:
				var cd_ability = cd_char.moveset.get_active_abilities(cd_char)[int(event["ability_idx"])]
				cd_ability.cooldown_remaining = int(event["value"])
				cd_char.update.emit()

		"DIED":
			var dead_char = _char_at(event["char_idx"])
			if dead_char != null:
				dead_char.dead = true
				dead_char.health.set_health(0)
				dead_char.update.emit()
				log_death(dead_char)

		"BANISHED":
			var banished_char = _char_at(event["char_idx"])
			if banished_char != null:
				banished_char.banished = true
				banished_char.update.emit()

		"REVIVED":
			var rev_char = _char_at(event["char_idx"])
			if rev_char != null:
				rev_char.dead = false
				rev_char.health.set_health(int(event["hp"]))
				rev_char.update.emit()

		"MESSAGE":
			if bool(event.get("demand", false)):
				message_demand.emit(event["text"])
			else:
				message_request.emit(event["text"])

		"MATCH_ENDED":
			var winner_role: String = event["winner_role"]
			var won: bool = (winner_role == "p1" and _role(player) == 0) or (winner_role == "p2" and _role(player) == 1)
			match_over = true
			match_ended.emit(won)

		_:
			push_warning("[PROTOCOL] Unknown event type: ", event_type)


## Force local state to match the server snapshot. Any mismatch is a bug
## (in the server's emit logic, the client's apply logic, or the protocol)
## and is logged loudly.
func _reconcile_to_snapshot(snapshot: Dictionary) -> void:
	match_over = bool(snapshot.get("match_over", false))
	current_turn_number = int(snapshot.get("current_turn", current_turn_number))

	var sides: Array = snapshot.get("sides", [])
	for side_dict in sides:
		var side_role: String = side_dict.get("role", "")
		var side_team = _team_for_side(side_role)
		if side_team == null:
			continue
		_reconcile_energy(side_team, side_dict.get("energy", {}))
		_reconcile_team(side_team, side_dict.get("team", []))


func _reconcile_energy(team, energy_dict: Dictionary) -> void:
	var pool: Dictionary = energy_dict.get("pool", {})
	var corrected := false
	for key in pool.keys():
		var energy_type := int(key)
		var expected := int(pool[key])
		if team.energy.pool.get(energy_type, 0) != expected:
			push_warning("[RECONCILE] Energy drift type=", energy_type,
				" local=", team.energy.pool.get(energy_type, 0), " snap=", expected)
			team.energy.pool[energy_type] = expected
			corrected = true
	# Direct pool[key] = expected above bypasses the display tracker update in
	# EnergyPool.change_energy, so after any correction push the current true
	# pool into the display so the UI doesn't drift from authoritative state.
	if corrected and team.energy.display != null:
		var true_pool = team.energy.true_pool()
		for energy_type in true_pool.keys():
			team.energy.display.change_energy(int(energy_type), int(true_pool[energy_type]))
		team.energy.display.update_random_count(team.energy.total_available())


func _reconcile_team(team, team_arr: Array) -> void:
	for i in range(min(team.characters.size(), team_arr.size())):
		var character = team.characters[i]
		var snap_char: Dictionary = team_arr[i]
		var snap_hp := int(snap_char.get("hp", character.health.hp))
		if character.health.hp != snap_hp:
			push_warning("[RECONCILE] HP drift ", character.path_name,
				" local=", character.health.hp, " snap=", snap_hp)
			character.health.set_health(snap_hp)
		var snap_dead := bool(snap_char.get("dead", character.dead))
		if character.dead != snap_dead:
			push_warning("[RECONCILE] dead-flag drift ", character.path_name,
				" local=", character.dead, " snap=", snap_dead)
			character.dead = snap_dead
		var snap_banished := bool(snap_char.get("banished", character.banished))
		if character.banished != snap_banished:
			push_warning("[RECONCILE] banished-flag drift ", character.path_name,
				" local=", character.banished, " snap=", snap_banished)
			character.banished = snap_banished
		var snap_abilities: Array = snap_char.get("abilities", [])
		# Build the server-authoritative active ability list from the snapshot.
		# The server resolves ABILITY_SWAP / SKILL_COPY effects (which walk
		# _effects, empty on passive clients) and ships the resulting ability
		# names. We look each one up in base_abilities and set the override
		# array on the moveset so display_abilities() returns the correct
		# abilities without mutating the base moveset.
		var resolved: Array = []
		for j in range(snap_abilities.size()):
			var snap_name = snap_abilities[j].get("ability_name", "")
			var snap_basename: String = snap_abilities[j].get("source_basename", "")
			var found = null
			for base_ab in character.moveset.base_abilities:
				if base_ab.ability_name == snap_name:
					found = base_ab
					break
			# SKILL_COPY override: the active ability isn't in the recipient's
			# own base_abilities (it was copied from another character's kit,
			# e.g. Mavis bestowing Fairy Glitter onto an ally). Reconstruct
			# the same fresh instance the server made via Effect.copy_effect()
			# by reading source_basename and calling Ability.from_database().
			# Bind user to the recipient so cost() / image / description all
			# resolve from the recipient's perspective.
			if found == null and snap_basename != "":
				found = Ability.from_database(snap_basename)
				if found != null:
					found.user = character
			if found != null:
				resolved.append(found)
			elif j < character.moveset.abilities.size():
				resolved.append(character.moveset.abilities[j])
		if resolved.size() == 4:
			character.moveset.server_active_abilities = resolved
		# Now apply per-ability overrides onto the resolved abilities.
		var local_abilities = character.moveset.get_active_abilities(character)
		for j in range(min(local_abilities.size(), snap_abilities.size())):
			var snap_cd := int(snap_abilities[j].get("cooldown_remaining", 0))
			if local_abilities[j].cooldown_remaining != snap_cd:
				push_warning("[RECONCILE] cooldown drift ", character.path_name,
					" ability=", local_abilities[j].ability_name,
					" local=", local_abilities[j].cooldown_remaining, " snap=", snap_cd)
				local_abilities[j].cooldown_remaining = snap_cd
			# Pull the server-resolved cost into the ability so ability.cost()
			# returns the right value on passive clients. The snapshot may have
			# been JSON-round-tripped on the reconnect path, turning int keys
			# into strings, so re-key via int() here. An absent "cost" field
			# leaves server_cost_set false and cost() falls back to base _cost —
			# this keeps mixed-version servers safe during rollout.
			var snap_cost_raw = snap_abilities[j].get("cost", null)
			if snap_cost_raw is Dictionary:
				var rebuilt_cost := {}
				for k in snap_cost_raw.keys():
					rebuilt_cost[int(k)] = int(snap_cost_raw[k])
				local_abilities[j].server_cost = rebuilt_cost
				local_abilities[j].server_cost_set = true
			# Same treatment for the server-resolved usable() state: the passive
			# client has no runtime _effects and can't see stun/delay/banish, so
			# usable() reads this field instead. Absent "usable" leaves
			# server_usable_set false and usable() runs its normal branch.
			if snap_abilities[j].has("usable"):
				local_abilities[j].server_usable = bool(snap_abilities[j]["usable"])
				local_abilities[j].server_usable_set = true
			# Server-resolved targeting. The snapshot carries the valid target
			# set and target_type for every ability so the passive client
			# doesn't need to call target() locally (which would miss
			# invulnerability, isolation, marks, and other effect-dependent
			# conditions). Copy into the ability so
			# receive_ability_use_request / target_type() use them directly.
			if snap_abilities[j].has("special_targets"):
				var raw_targets = snap_abilities[j]["special_targets"]
				var rebuilt_targets: Array = []
				for t in raw_targets:
					rebuilt_targets.append(int(t))
				local_abilities[j].server_targets = rebuilt_targets
				local_abilities[j].server_targets_set = true
			if snap_abilities[j].has("target_type"):
				local_abilities[j].server_target_type = int(snap_abilities[j]["target_type"])
				local_abilities[j].server_target_type_set = true
		# Pull the server-resolved portrait choice onto the character so
		# active_portrait() can use it without walking the empty local
		# _effects list. We always honor the field when present (even at -1 /
		# "") so that when PORTRAIT_CHANGE / DISGUISE effects end, the passive
		# client reverts to the base portrait on the next snapshot.
		if snap_char.has("portrait_alt"):
			character.server_portrait_alt = int(snap_char["portrait_alt"])
			character.server_portrait_set = true
		if snap_char.has("portrait_disguise"):
			character.server_portrait_disguise = str(snap_char["portrait_disguise"])
			character.server_portrait_set = true
		_reconcile_display_effects(character, snap_char.get("effects", []))
		character.update.emit()


# Sync the character's display-effect list to a wire snapshot. Adds any id in
# the snapshot but missing locally, removes any local id absent from the
# snapshot, and updates mag/duration/etc. on entries that are in both. Only
# touches _display_effects, never _effects, so on a non-passive client (where
# _display_effects is always empty and the snapshot effects array would also
# be empty for that side) this is a no-op.
func _reconcile_display_effects(character, snap_effects: Array) -> void:
	var snap_by_id: Dictionary = {}
	for payload in snap_effects:
		snap_by_id[payload.get("id", "")] = payload

	var local_ids: Dictionary = {}
	for de in character.effects._display_effects:
		local_ids[de.id] = de

	for id in local_ids.keys():
		if not snap_by_id.has(id):
			character.effects.remove_display_effect_by_id(id)

	for id in snap_by_id.keys():
		var payload: Dictionary = snap_by_id[id]
		if local_ids.has(id):
			var existing = local_ids[id]
			existing.apply_payload(payload, existing.user)
		else:
			var owner_user = _char_at(int(payload.get("user", -1)))
			character.effects.add_display_effect(DisplayEffect.from_payload(payload, owner_user))


# ===========================================================================
# PHASE 6.5 — non-mutating snapshot consistency check
#
# Compares a server-broadcast wire snapshot to the live manager state without
# touching anything. Surfaces wire-protocol drift via push_warning so we can
# verify the server's serializer end-to-end before flipping `passive` in
# Phase 7. Returns the count of mismatches found.
# ===========================================================================
func validate_snapshot(snapshot: Dictionary) -> int:
	var drift := 0

	var snap_match_over := bool(snapshot.get("match_over", false))
	if match_over != snap_match_over:
		push_warning("[SNAPSHOT DRIFT] match_over local=", match_over, " snap=", snap_match_over)
		drift += 1

	var snap_turn := int(snapshot.get("current_turn", -1))
	if snap_turn != -1 and current_turn_number != snap_turn:
		push_warning("[SNAPSHOT DRIFT] current_turn local=", current_turn_number, " snap=", snap_turn)
		drift += 1

	var live_acting_role := "p1" if (_role(player) if not waiting_for_turn else _role(enemy)) == 0 else "p2"
	var snap_acting_role: String = snapshot.get("acting_role", "")
	if snap_acting_role != "" and live_acting_role != snap_acting_role:
		push_warning("[SNAPSHOT DRIFT] acting_role local=", live_acting_role, " snap=", snap_acting_role)
		drift += 1

	var sides: Array = snapshot.get("sides", [])
	for side_dict in sides:
		var side_role: String = side_dict.get("role", "")
		var side_team = _team_for_side(side_role)
		if side_team == null:
			push_warning("[SNAPSHOT DRIFT] no local team for side ", side_role)
			drift += 1
			continue
		drift += _validate_energy(side_role, side_team, side_dict.get("energy", {}))
		drift += _validate_team(side_role, side_team, side_dict.get("team", []))

	return drift


func _validate_energy(side_role: String, team, energy_dict: Dictionary) -> int:
	var drift := 0
	var pool: Dictionary = energy_dict.get("pool", {})
	for key in pool.keys():
		var energy_type := int(key)
		var expected := int(pool[key])
		var actual := int(team.energy.pool.get(energy_type, 0))
		if actual != expected:
			push_warning("[SNAPSHOT DRIFT] ", side_role, " energy.pool[", energy_type, "] local=", actual, " snap=", expected)
			drift += 1
	var promised: Dictionary = energy_dict.get("promised_pool", {})
	for key in promised.keys():
		var energy_type := int(key)
		var expected := int(promised[key])
		var actual := int(team.energy.promised_pool.get(energy_type, 0))
		if actual != expected:
			push_warning("[SNAPSHOT DRIFT] ", side_role, " energy.promised_pool[", energy_type, "] local=", actual, " snap=", expected)
			drift += 1
	return drift


func _validate_team(side_role: String, team, team_arr: Array) -> int:
	var drift := 0
	if team.characters.size() != team_arr.size():
		push_warning("[SNAPSHOT DRIFT] ", side_role, " team.size local=", team.characters.size(), " snap=", team_arr.size())
		drift += 1
	var n: int = min(team.characters.size(), team_arr.size())
	for i in range(n):
		var character = team.characters[i]
		var snap_char: Dictionary = team_arr[i]
		var prefix := "[SNAPSHOT DRIFT] " + side_role + ".char[" + str(i) + "] " + str(character.path_name)

		var snap_path_name: String = snap_char.get("path_name", "")
		if str(character.path_name) != snap_path_name:
			push_warning(prefix, " path_name local=", character.path_name, " snap=", snap_path_name)
			drift += 1

		var snap_hp := int(snap_char.get("hp", -1))
		if int(character.health.hp) != snap_hp:
			push_warning(prefix, " hp local=", character.health.hp, " snap=", snap_hp)
			drift += 1

		var snap_max_hp := int(snap_char.get("max_hp", -1))
		var live_max := int(character.get_modified_max_hp())
		if live_max != snap_max_hp:
			push_warning(prefix, " max_hp local=", live_max, " snap=", snap_max_hp)
			drift += 1

		var snap_dead := bool(snap_char.get("dead", false))
		if character.dead != snap_dead:
			push_warning(prefix, " dead local=", character.dead, " snap=", snap_dead)
			drift += 1

		var snap_banished := bool(snap_char.get("banished", false))
		if character.banished != snap_banished:
			push_warning(prefix, " banished local=", character.banished, " snap=", snap_banished)
			drift += 1

		var snap_acted := bool(snap_char.get("acted", false))
		if character.acted != snap_acted:
			push_warning(prefix, " acted local=", character.acted, " snap=", snap_acted)
			drift += 1

		var snap_abilities: Array = snap_char.get("abilities", [])
		var live_abilities = character.moveset.get_active_abilities(character)
		if live_abilities.size() != snap_abilities.size():
			push_warning(prefix, " abilities.size local=", live_abilities.size(), " snap=", snap_abilities.size())
			drift += 1
		var ability_n: int = min(live_abilities.size(), snap_abilities.size())
		for j in range(ability_n):
			var live_ab = live_abilities[j]
			var snap_ab: Dictionary = snap_abilities[j]
			var snap_ab_name: String = snap_ab.get("ability_name", "")
			if str(live_ab.ability_name) != snap_ab_name:
				push_warning(prefix, " ability[", j, "].name local=", live_ab.ability_name, " snap=", snap_ab_name)
				drift += 1
			var snap_cd := int(snap_ab.get("cooldown_remaining", -1))
			if int(live_ab.cooldown_remaining) != snap_cd:
				push_warning(prefix, " ability[", j, "].cd local=", live_ab.cooldown_remaining, " snap=", snap_cd)
				drift += 1

		var snap_effects: Array = snap_char.get("effects", [])
		var snap_effect_ids := {}
		for snap_eff in snap_effects:
			snap_effect_ids[String(snap_eff.get("id", ""))] = true
		var live_effect_ids := {}
		for live_eff in character.effects._effects:
			# Must mirror the wire loop exactly - a display_system effect IS serialized, so skipping
			# it here would report it as "missing in live" on every single turn.
			if live_eff.system and not live_eff.display_system:
				continue
			live_effect_ids[_effect_id_for_validation(live_eff)] = true
		for live_id in live_effect_ids.keys():
			if not (live_id in snap_effect_ids):
				push_warning(prefix, " effect missing in snap: ", live_id)
				drift += 1
		for snap_id in snap_effect_ids.keys():
			if not (snap_id in live_effect_ids):
				push_warning(prefix, " effect missing in live: ", snap_id)
				drift += 1
	return drift


func _effect_id_for_validation(effect) -> String:
	var source_basename := ""
	if effect.source != null:
		source_basename = effect.source.get_script().resource_path.get_file().get_basename()
	var user_path := ""
	if effect.user != null:
		user_path = effect.user.path_name
	return effect.effect_name() + "@" + user_path + "@" + source_basename + "@" + str(int(effect.effect_type))


# ===========================================================================
# PHASE 6 — helpers for apply_turn_result
# ===========================================================================

# Returns the local team object for a canonical side string ("p1" / "p2").
# On the local manager, the local user is always `player`, so we use the
# user's own role to map sides to teams.
func _team_for_side(side: String):
	var local_role := _role(player)
	if side == "p1":
		return player.team if local_role == 0 else enemy.team
	elif side == "p2":
		return player.team if local_role == 1 else enemy.team
	return null


# Returns the local Character object for a canonical character index.
# Inverse of `_canonical_index`: applies the same XOR-by-3 swap when the
# local user is p2.
func _char_at(canonical_idx: int):
	var local_role := _role(player)
	var local_idx := canonical_idx
	if local_role == 1:
		if canonical_idx < 3:
			local_idx = canonical_idx + 3
		else:
			local_idx = canonical_idx - 3
	var chars = all_characters()
	if local_idx < 0 or local_idx >= chars.size():
		return null
	return chars[local_idx]


## Called by the display layer when the bot fake timer fires.
func bot_fake_timer_timeout():
	if match_over:
		return
	generate_team_energy(enemy.team, went_second)
	went_second = false
	# Live bot turns route through the trained contextual model (side 1 =
	# enemy). The model is loaded lazily on first use and shared across all
	# matches in the process. If the model file is missing or empty,
	# perform_turn_contextual falls back to roughly-uniform play because
	# every (char, ability) entry returns score 0.
	paced_bot_actions = true
	# Bot turn covers the whole perform_turn_contextual → start_round_loop
	# chain. If perform_turn_contextual bails before start_round_loop (and
	# thus before _execution_loop_step_async's own watchdog kicks in), this
	# outer guard still catches it. The inner watchdog overrides this one
	# when start_round_loop is reached (each start bumps the id), so we
	# don't get two competing timers.
	_start_playback_watchdog()
	# v3 policy when promoted (same fallback rule as the server bot driver).
	var v3_policy = _get_live_bot_policy()
	if v3_policy != null:
		await enemy.perform_turn_v3(self, v3_policy, null,
			_live_tier_temperature(), _get_live_bot_tuning(), false, true)
	else:
		await enemy.perform_turn_contextual(self, _get_live_bot_model(), 1)
	_clear_playback_watchdog()
	paced_bot_actions = false


## Called by the display layer when the bot crash timer fires.
func bot_crash_timer_timeout():
	start_round_loop()
