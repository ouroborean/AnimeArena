extends Node
class_name Match
static var next_match_id := 1
var match_id: int
# Durable per-match id (format: <YYYYMMDD>_<match_id>_<randi>). Unlike the volatile static match_id
# (resets on server restart), this is minted once per real match and everything durable (replay file,
# match record, history entry) keys off it. The match_id segment guarantees intra-run uniqueness; the
# randi segment guarantees cross-run uniqueness (freshly seeded each server start). Minted lazily in
# begin_match() via _ensure_match_uid().
var match_uid: String = ""
var players = {}
var bans = {}
var picks = {}
var timed_out = false
# --- Ranked draft state (ban 60s simultaneous, then 1-2-2-1 picks, 30s each) ---
var draft_active := false
var draft_phase := "NONE"            # NONE | BAN | PICK | COMPLETE
var draft_step := 0                  # pick step 0..3 with quotas 1-2-2-1
var draft_picks_this_step := 0
var draft_pool: Array = []           # every path_name (bannable); picks gated by unlocks
var draft_first_picker = null        # peer_id who picks first (seed coin-flip)
var draft_ban_locked := {}           # peer_id -> bool
var draft_hover := {}                # peer_id -> path_name (latest highlight; feeds timeout auto-pick)
var draft_deadline_unix := 0.0
const DRAFT_BAN_SECONDS := 60.0
const DRAFT_PICK_SECONDS := 30.0
const DRAFT_MAX_BANS := 3
const DRAFT_PICK_QUOTA := [1, 2, 2, 1]
var seed
var default_match_timer = 120.0
# Anti-AFK. Each turn a player lets TIME OUT shaves AFK_PENALTY_STEP off their turn timer (cumulative,
# floored at AFK_MIN_TIMER); finishing a turn MANUALLY resets it. Missing AFK_FORFEIT_MISSES turns in a
# ROW auto-forfeits the match for that player. `afk_misses` is peer_id -> consecutive missed turns.
const AFK_PENALTY_STEP := 30.0
const AFK_MIN_TIMER := 30.0
const AFK_FORFEIT_MISSES := 3
var afk_misses := {}
var acting_player
var match_type: BattleManager.MatchType
# Explicit "Bot Match" queue games (the practice button) are match_type BOT but flagged here so the
# result awards NO win/loss to the player's record and only a small amount of AP. A Quick-queue game
# that falls back to a bot opponent is NOT practice — it keeps normal win/loss + AP.
var practice_match := false
var campaign_encounter := ""   # CAMPAIGN matches: the encounter id being fought (gates campaign progression on win)
var campaign_activation := ""  # CAMPAIGN matches: the activation (beat) the encounter belongs to — scopes the win
var cancelling = false
var starting_player
var missing_players = []
var manager: BattleManager = null
var spectators: Dictionary = {}
var replay_log: MatchReplayLog = null
# Server-side recorder that subscribes to the shadow manager's protocol-facing
# signals and accumulates wire-format event dictionaries. Drained by
# ServerConnection._broadcast_turn_result and shipped to both clients via
# apply_turn_result after every input, timeout, and match-end.
var event_recorder: MatchEventRecorder = null
# Phase 2 shadow validation: server-side turn counter and the state hash the
# server's BattleManager produced after each processed turn package. Clients
# report their own hash via report_state_hash for comparison.
var current_turn_number: int = 0
var server_state_hashes: Dictionary = {}
# Maps peer_id -> username for all players who have ever been in this match.
# Used to verify that a peer_id still belongs to the expected player before
# sending RPCs, preventing misrouted packets after peer-id reuse.
var peer_username_map = {}

signal timeout_current_player(nmatch, events, snapshot)
signal match_over(nmatch)
signal server_match_ended(nmatch, winner_peer_id)
signal clean_up(nmatch)
signal draft_state_changed(nmatch)
signal draft_completed(nmatch)

# True when this Player is still busy with a match that has not been decided.
#
# Deliberately derived from the MATCH OBJECT rather than from a flag on the Player: Player.current_match
# is only ever WRITTEN (from_players below and check_in_player) and never cleared — match_ended clears
# the SESSION's pointer, not the Player's — so `player.current_match != null` is a permanently stale
# pointer to that account's LAST match and would lock every returning player out of their second game
# forever. Liveness therefore has to come off the match itself:
#   freed / queued for deletion -> the server already tore it down
#   cancelling                  -> cancel_match()/_forfeit_afk_player() has committed to ending it
#   manager.match_over          -> the shadow decided it (match_over is monotonic false->true on the
#                                  server, and zombie matches that skip teardown land here)
#   manager == null             -> the DRAFT phase, which IS live: the player is banning/picking
static func _holds_live_match(player) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var m = player.current_match
	# is_instance_valid MUST short-circuit before any member access on a freed Match.
	if m == null or not is_instance_valid(m):
		return false
	if m.is_queued_for_deletion():
		return false   # queue_free is deferred to the end of the frame; it is already gone
	if m.cancelling:
		return false
	if m.manager != null and is_instance_valid(m.manager) and m.manager.match_over:
		return false
	return true


static func from_players(peer_id1, player1, player1_characters, peer_id2, player2, player2_characters, mseed, match_type, draft_mode := false):
	# --- SINK GUARD ---------------------------------------------------------------------------
	# from_players is DESTRUCTIVE: it calls team.clear_characters() on the PERSISTENT, session-owned
	# Player objects below, and those arrays are the very arrays a live BattleManager reads. Building
	# a second match for a player who still holds one therefore empties the LIVE board:
	# check_lose_condition/check_win_condition then iterate an empty array, fall through, and fabricate
	# an instant Defeat (or a phantom Victory for the opponent) at full health, while
	# _serialize_wire_team ships `team: []` and the client renders zero character panels.
	# Refuse to build instead. Runs BEFORE the match node is instantiated so a rejection leaks nothing.
	if player1 == player2:
		# Upstream only ever compares PEER IDS (receive_quick_match_queue's `player1_id == peer_id`),
		# so one account connected on two peer ids can reach here seated against itself — and the two
		# clear_characters() calls below would wipe that single team twice.
		var self_name = str(player1.username) if player1 != null and is_instance_valid(player1) else "<invalid>"
		push_error("[MATCH-GUARD] REFUSED match build — same Player object on both seats: " + self_name)
		print("[MATCH-GUARD] REFUSED match build — same Player object on both seats: ", self_name, " (peers ", peer_id1, " / ", peer_id2, ")")
		return null
	if _holds_live_match(player1) or _holds_live_match(player2):
		var n1 = str(player1.username) if player1 != null and is_instance_valid(player1) else "<invalid>"
		var n2 = str(player2.username) if player2 != null and is_instance_valid(player2) else "<invalid>"
		var who = "p1=" + n1 + (" LIVE" if _holds_live_match(player1) else " free") + ", p2=" + n2 + (" LIVE" if _holds_live_match(player2) else " free")
		push_error("[MATCH-GUARD] REFUSED match build — a seat already holds a live match (" + who + ")")
		print("[MATCH-GUARD] REFUSED match build — a seat already holds a live match (", who, ", peers ", peer_id1, " / ", peer_id2, ", type=", match_type, ")")
		return null
	# ------------------------------------------------------------------------------------------
	var new_match = load("res://components/match.tscn").instantiate()
	new_match.match_id = next_match_id
	next_match_id += 1
	# Mint the durable uid at construction (not lazily in begin_match): ranked-draft matches set a
	# session's current_match before begin_match runs, so a match-channel chat during the draft would
	# otherwise key on an empty match_uid (a shared "" bucket across drafts). match_id is set above.
	new_match._ensure_match_uid()
	new_match.seed = mseed
	new_match.match_type = match_type
	# Belt-and-suspenders against the queue-payload-too-short bug: server-side
	# validation in receive_*_match_queue should already block this, but if a
	# short list slips through anyway, fall back to the player's last-saved
	# team rather than starting the match with a partial roster.
	# In draft mode both teams are intentionally empty (built later by accept_pick),
	# so skip the short-payload fallback that would otherwise backfill the saved team.
	if not draft_mode:
		if player1_characters.size() < 3 and player1.equipped_characters.size() >= 3:
			print("[MATCH] Short queue payload for ", player1.username, " (", player1_characters.size(), ") — using equipped_characters")
			player1_characters = player1.equipped_characters.duplicate()
		if player2_characters.size() < 3 and player2.equipped_characters.size() >= 3:
			print("[MATCH] Short queue payload for ", player2.username, " (", player2_characters.size(), ") — using equipped_characters")
			player2_characters = player2.equipped_characters.duplicate()
	# Clear stale per-match state on the server's persistent Player objects
	# before re-recruiting. team.add_character refuses inserts past
	# max_members, so without this the second match for any user would run
	# the shadow with leftover Character instances from the first match.
	var first_player = player1
	first_player.team.clear_characters()   # frees the previous match's Character subtrees (plain .clear() leaked them)
	first_player.equipped_characters.clear()
	if not draft_mode:
		for character_name in player1_characters.slice(0, 3):
			first_player.recruit_character(Character.from_character_name(character_name))
		_apply_disguise(first_player, player1_characters)
		_apply_jinwoo_form(first_player, player1_characters)
	first_player.current_match = new_match
	new_match.bans[peer_id1] = []
	new_match.picks[peer_id1] = []
	new_match.players[peer_id1] = first_player
	new_match.peer_username_map[peer_id1] = player1.username
	var second_player = player2
	second_player.team.clear_characters()
	second_player.equipped_characters.clear()
	if not draft_mode:
		for character_name in player2_characters.slice(0, 3):
			second_player.recruit_character(Character.from_character_name(character_name))
		_apply_disguise(second_player, player2_characters)
		_apply_jinwoo_form(second_player, player2_characters)
	second_player.current_match = new_match
	new_match.bans[peer_id2] = []
	new_match.picks[peer_id2] = []
	new_match.players[peer_id2] = second_player
	new_match.peer_username_map[peer_id2] = player2.username
	# Decide who goes first deterministically from the match seed so the
	# server-side BattleManager and both clients agree without an extra RPC.
	var coin_rng = RandomNumberGenerator.new()
	coin_rng.set_seed(mseed)
	var p1_first = coin_rng.randi_range(0, 1) == 1
	if p1_first:
		new_match.acting_player = peer_id1
		new_match.starting_player = player1.username
	else:
		new_match.acting_player = peer_id2
		new_match.starting_player = player2.username
	# In draft mode, acting_player is the first PICKER for now (seed coin-flip);
	# the battle turn order (second picker acts first) is set in _complete_draft().
	if draft_mode:
		new_match.draft_first_picker = new_match.acting_player
	return new_match

# Toga's chosen disguise rides along as an optional 4th element in the queue payload
# (see server_connection.queue_*_match and the web client's queueQuick/queuePrivate).
# The recruit loop above stops at 3 members — team.add_character caps at max_members —
# so this 4th element would otherwise be silently dropped. Apply it to the recruited
# toga here so her passive (toga5.gd execute) starts the battle disguised.
static func _apply_disguise(player, character_names) -> void:
	if character_names.size() <= 3:
		return
	var disguise := str(character_names[3])
	if disguise == "" or disguise == "toga":
		return
	if disguise.begins_with("form:"):
		return  # Jin-woo's "form:<color>" token can sit at index 3 when no disguise is set — not a disguise.
	for character in player.team.characters:
		if character.path_name == "toga":
			character.disguise_name = disguise
			return

# Sung Jin-woo's chosen summon rides the queue payload as a "form:<color>" token appended after the
# team (and after any Toga disguise — see the web client's queueTeamPayload). Scan the extras (index
# 3+) for it and stamp the recruited jinwoo, so initialize(true) builds that form's kit. The token is
# never recruited (the recruit loop stops at 3), so it can't be mistaken for a team member.
static func _apply_jinwoo_form(player, character_names) -> void:
	if character_names.size() <= 3:
		return
	var form := ""
	for i in range(3, character_names.size()):
		var token := str(character_names[i])
		if token.begins_with("form:"):
			form = token.substr(5)
			break
	if not form in ["red", "green", "white", "blue"]:
		return
	for character in player.team.characters:
		if character.path_name == "jinwoo":
			character.summon_form = form
			return

func accept_ban(id, character):
	bans[id].append(character)

func player_goes_first(peer_id) -> bool:
	return acting_player != null and peer_id == acting_player

func _ensure_match_uid() -> void:
	if match_uid == "":
		var d = Time.get_datetime_dict_from_system(true)
		# Zero-padded date so the id matches its documented <YYYYMMDD> format and is unambiguous;
		# match_id (unique within a server run) + randi (unique across runs) make the full id collision-proof.
		match_uid = "%04d%02d%02d_%d_%d" % [int(d.get("year", 0)), int(d.get("month", 0)), int(d.get("day", 0)), match_id, randi()]

func begin_match() -> void:
	if manager != null:
		return
	if DisplayServer.get_name() != "headless":
		return
	if len(players) < 2:
		return
	var p1_peer = players.keys()[0]
	var p2_peer = players.keys()[1]
	var p1 = players[p1_peer]
	var p2 = players[p2_peer]
	manager = BattleManager.new()
	manager.name = "BattleManager"
	manager.shadow_mode = true
	add_child(manager)
	# Attach the event recorder before start_battle so the very first turn's
	# setup events (TURN_STARTED for the opening turn, ENERGY_GAINED from the
	# first-turn random energy roll) are captured in the initial flush.
	event_recorder = MatchEventRecorder.new()
	event_recorder.attach(manager)
	# Hook the manager's natural match-end so server-side bookkeeping (rank,
	# AP, stats, saves, post-match player updates) runs exactly once when the
	# shadow ends the match. The MATCH_ENDED wire event is captured separately
	# by the recorder and broadcast via the next apply_turn_result.
	manager.match_ended.connect(_on_manager_match_ended)
	_ensure_match_uid()
	replay_log = MatchReplayLog.begin(self)
	var first_for_manager = (acting_player == p1_peer)
	print("[SHADOW] Match ", match_id, " starting BattleManager (", p1.username, " vs ", p2.username, ", first=", first_for_manager, ")")
	manager.start_battle(p1, p2, first_for_manager, seed, match_type)
	replay_log.record_initial_snapshot(manager.serialize_wire_snapshot())

# `won` is from the manager.player perspective. The shadow always builds with
# manager.player == canonical p1 (players.keys()[0]), so the winner peer is
# unambiguous regardless of which side acted first.
func _on_manager_match_ended(won: bool) -> void:
	# The battle is decided — kill the turn timer immediately. Previously only cancel_match() and
	# _forfeit_afk_player() ever stopped it, so a NORMALLY-ended match kept a live one-shot timer that
	# could later fire handle_turn_timeout on a finished match.
	$Timer.stop()
	var keys = players.keys()
	if len(keys) < 2:
		return
	var winner_peer_id = keys[0] if won else keys[1]
	server_match_ended.emit(self, winner_peer_id)

func release_player_objects() -> void:
	# Player objects are owned by sessions/global state, not by this match.
	# Detach them from the BattleManager so the cascade-free of the match
	# scene tree doesn't take them with it. Must be called BEFORE queue_free.
	if manager == null:
		return
	for player in players.values():
		if is_instance_valid(player) and player.get_parent() == manager:
			manager.remove_child(player)
			# Synthetic EPHEMERAL bot players are owned by the match (not a session), so the detach above
			# would orphan them — free them here instead. An ULTRA bot is owned by its ServerSession + the
			# players cache (like a human) and MUST survive teardown, so it is only detached, never freed.
			if player.is_ephemeral_bot():
				player.queue_free()

func accept_pick(id, character):
	picks[id].append(character)
	players[id].recruit_character(Character.from_character_name(character))

# ---------------------------------------------------------------------------
# Ranked draft state machine. Reuses bans/picks/accept_ban/accept_pick above and
# the single $Timer (routed here from handle_turn_timeout while draft_active).
# ---------------------------------------------------------------------------

# Sets up the BAN phase and arms the 60s timer. Does NOT emit — the caller sends
# `draft_start` first, then relies on draft_state_changed for later updates.
func start_draft() -> void:
	draft_active = true
	draft_phase = "BAN"
	draft_step = 0
	draft_picks_this_step = 0
	draft_pool = CharacterDatabase.char_name_list()
	draft_first_picker = acting_player
	for pid in players.keys():
		draft_ban_locked[pid] = false
	_arm_draft_timer(DRAFT_BAN_SECONDS)

func _arm_draft_timer(seconds: float) -> void:
	draft_deadline_unix = Time.get_unix_time_from_system() + seconds
	$Timer.stop()
	$Timer.wait_time = seconds
	$Timer.start()

func draft_seconds_left() -> float:
	return max(0.0, draft_deadline_unix - Time.get_unix_time_from_system())

# Returns "" on success, else a human-readable rejection reason.
func submit_draft_ban(peer_id, character, confirm := false) -> String:
	if not draft_active or draft_phase != "BAN":
		return "Not in the ban phase"
	if not (peer_id in players):
		return "Not in this match"
	if draft_ban_locked.get(peer_id, false):
		return "Your bans are already locked"
	if not (character in draft_pool):
		return "Unknown character"
	if character in bans[peer_id]:
		return "You already banned that character"
	if bans[peer_id].size() >= DRAFT_MAX_BANS:
		return "Ban limit reached"
	accept_ban(peer_id, character)
	if confirm or bans[peer_id].size() >= DRAFT_MAX_BANS:
		draft_ban_locked[peer_id] = true
	_maybe_end_ban_phase()
	draft_state_changed.emit(self)
	return ""

func lock_draft_bans(peer_id) -> String:
	if not draft_active or draft_phase != "BAN":
		return "Not in the ban phase"
	if not (peer_id in players):
		return "Not in this match"
	draft_ban_locked[peer_id] = true
	_maybe_end_ban_phase()
	draft_state_changed.emit(self)
	return ""

func _maybe_end_ban_phase() -> void:
	for pid in players.keys():
		if not draft_ban_locked.get(pid, false):
			return
	_end_ban_phase()

func _end_ban_phase() -> void:
	draft_phase = "PICK"
	draft_step = 0
	draft_picks_this_step = 0
	_arm_draft_timer(DRAFT_PICK_SECONDS)

func _pick_actor_for_step(step: int):
	# Steps 0,2 -> first picker; steps 1,3 -> second picker (1-2-2-1).
	if step == 0 or step == 2:
		return draft_first_picker
	return get_opponent(draft_first_picker)

func draft_current_actor():
	if draft_phase != "PICK":
		return null
	return _pick_actor_for_step(draft_step)

func submit_draft_pick(peer_id, character) -> String:
	if not draft_active or draft_phase != "PICK":
		return "Not in the pick phase"
	if peer_id != _pick_actor_for_step(draft_step):
		return "It is not your turn to pick"
	if not (character in draft_pool):
		return "Unknown character"
	var keys = players.keys()
	if character in bans[keys[0]] or character in bans[keys[1]]:
		return "That character is banned"
	if character in picks[keys[0]] or character in picks[keys[1]]:
		return "That character is already picked"
	if not _can_pick(players[peer_id], character):
		return "You have not unlocked that character"
	accept_pick(peer_id, character)
	_advance_pick()
	draft_state_changed.emit(self)
	return ""

func _advance_pick() -> void:
	draft_picks_this_step += 1
	if draft_picks_this_step >= DRAFT_PICK_QUOTA[draft_step]:
		draft_step += 1
		draft_picks_this_step = 0
	if draft_step > 3:
		_complete_draft()
	else:
		_arm_draft_timer(DRAFT_PICK_SECONDS)

func _can_pick(player, path) -> bool:
	if path in CharacterDatabase.starter_squads():
		return true
	if (path + "_unlock") in player.unlocks:
		return true
	if "all_unlock" in player.unlocks:
		return true
	return false

func set_draft_hover(peer_id, character) -> void:
	if peer_id in players:
		draft_hover[peer_id] = character

func _available_picks_for(peer_id) -> Array:
	var keys = players.keys()
	var taken: Array = bans[keys[0]] + bans[keys[1]] + picks[keys[0]] + picks[keys[1]]
	var out: Array = []
	for path in draft_pool:
		if path in taken:
			continue
		if _can_pick(players[peer_id], path):
			out.append(path)
	return out

func _handle_draft_timeout() -> void:
	if draft_phase == "BAN":
		for pid in players.keys():
			draft_ban_locked[pid] = true
		_end_ban_phase()
		draft_state_changed.emit(self)
	elif draft_phase == "PICK":
		var actor = _pick_actor_for_step(draft_step)
		var available := _available_picks_for(actor)
		var choice = null
		var hovered = draft_hover.get(actor, null)
		if hovered != null and hovered in available:
			choice = hovered
		elif available.size() > 0:
			choice = available[randi() % available.size()]
		if choice != null:
			accept_pick(actor, choice)
		_advance_pick()
		draft_state_changed.emit(self)

func _complete_draft() -> void:
	$Timer.stop()
	draft_phase = "COMPLETE"
	draft_active = false
	# The player who picked SECOND takes the first battle turn.
	acting_player = get_opponent(draft_first_picker)
	if acting_player in players:
		starting_player = players[acting_player].username
	draft_completed.emit(self)

func draft_role_of(peer_id) -> int:
	var keys = players.keys()
	if keys.size() >= 1 and peer_id == keys[0]:
		return 0
	return 1

# Per-peer draft snapshot for the client. Opponent bans stay hidden until the ban
# phase ends (revealed once draft_phase != "BAN").
func draft_state_for(peer_id) -> Dictionary:
	var keys = players.keys()
	var p1 = keys[0]
	var p2 = keys[1]
	var revealed := draft_phase != "BAN"
	var actor = draft_current_actor()
	var d := {
		"phase": draft_phase,
		"step": draft_step,
		"acting_role": (draft_role_of(actor) if actor != null else -1),
		"picks": {"p1": picks[p1].duplicate(), "p2": picks[p2].duplicate()},
		"bans_revealed": revealed,
		"my_role": draft_role_of(peer_id),
		"my_bans": bans[peer_id].duplicate() if peer_id in bans else [],
		"my_bans_locked": draft_ban_locked.get(peer_id, false),
		"deadline_unix": draft_deadline_unix,
		"seconds": draft_seconds_left(),
	}
	if revealed:
		d["bans"] = {"p1": bans[p1].duplicate(), "p2": bans[p2].duplicate()}
	else:
		var opp = get_opponent(peer_id)
		d["opp_ban_count"] = bans[opp].size() if (opp != null and opp in bans) else 0
	return d

# ---------------------------------------------------------------------------
# Phase 7.3 — server-authoritative input validation and application
#
# `validate_input` cross-checks a canonical-frame input package (per
# MATCH_PROTOCOL.md section 2.2) against the live shadow BattleManager. It
# enforces the integrity rules from section 2.3 — sender is the acting
# player, every action references a live character on their team, every
# ability index is in range, every target is a real character, and the
# energy_allocation actually pays for the chosen abilities.
#
# `apply_input` translates the canonical input back into the legacy
# local-frame package shape that BattleManager.process_turn_package already
# knows how to consume, then drives the shadow with it. It also rotates
# the timer and updates acting_player/afk_misses so the rest of
# the match-state machine stays consistent.
# ---------------------------------------------------------------------------

# Returns true if input is structurally valid AND the proposed actions are
# legal in the live shadow's state. The shadow manager is the authoritative
# source of truth — what it says is dead/banished/usable wins. On rejection
# a push_warning is emitted naming the specific gate that failed so turn
# rejections are debuggable from server logs.
func validate_input(input, peer_id, exchange_unapplied = false) -> bool:
	if manager == null:
		push_warning("[VALIDATE] reject: manager null")
		return false
	if not input is Dictionary:
		push_warning("[VALIDATE] reject: input not a Dictionary")
		return false
	if peer_id != acting_player:
		push_warning("[VALIDATE] reject: peer_id ", peer_id, " != acting_player ", acting_player)
		return false
	if not (input.has("actions") and input.has("execution_order") and input.has("energy_allocation")):
		push_warning("[VALIDATE] reject: missing required keys, got ", input.keys())
		return false

	var sender_role := _peer_canonical_role(peer_id)
	if sender_role < 0:
		push_warning("[VALIDATE] reject: sender not in match")
		return false

	# Pre-populate the shadow's acting-team energy pool for the p2-first /
	# waiting_for_turn case, where process_turn_package would otherwise be the
	# first thing to call generate_team_energy. Without this the pool is empty
	# at validation time and every action looks unaffordable.
	manager.prepare_acting_energy_if_needed()

	# Sender's seat in the shadow: the shadow always builds with player == p1,
	# so sender_role 0 → manager.player.team, sender_role 1 → manager.enemy.team.
	var sender_team = manager.player.team if sender_role == 0 else manager.enemy.team
	var team_base := sender_role * 3

	var actions: Array = input.get("actions", [])
	var total_cost := {}
	for action in actions:
		if not action is Dictionary:
			push_warning("[VALIDATE] reject: action not a Dictionary")
			return false
		var canonical_char_idx := int(action.get("char_idx", -1))
		if canonical_char_idx < team_base or canonical_char_idx >= team_base + 3:
			push_warning("[VALIDATE] reject: char_idx ", canonical_char_idx, " outside sender range (base=", team_base, ")")
			return false
		var local_char_idx := canonical_char_idx - team_base
		if local_char_idx < 0 or local_char_idx >= sender_team.characters.size():
			return false
		var character = sender_team.characters[local_char_idx]
		if character.dead or character.banished:
			push_warning("[VALIDATE] reject: ", character.path_name, " dead/banished")
			return false
		var actives = character.moveset.get_active_abilities(character)
		var ability_idx := int(action.get("ability_idx", -1))
		if ability_idx < 0 or ability_idx >= actives.size():
			push_warning("[VALIDATE] reject: ", character.path_name, " ability_idx ", ability_idx, " out of range (size=", actives.size(), ")")
			return false
		var ability = actives[ability_idx]
		if ability.cooldown_remaining > 0:
			push_warning("[VALIDATE] reject: ", character.path_name, " ability ", ability.ability_name, " on cooldown ", ability.cooldown_remaining)
			return false
		if character.is_stunned(ability):
			push_warning("[VALIDATE] reject: ", character.path_name, " stunned for ", ability.ability_name)
			return false
		for energy_type in ability.cost().keys():
			total_cost[energy_type] = total_cost.get(energy_type, 0) + ability.cost()[energy_type]
		var target_idxs: Array = action.get("target_idxs", [])
		var all_chars = manager.all_characters()
		for canonical_target in target_idxs:
			var ct := int(canonical_target)
			if ct < 0 or ct >= all_chars.size():
				push_warning("[VALIDATE] reject: target ", ct, " out of bounds")
				return false

	# Total cost must be affordable from the sender team's energy pool.
	# can_afford handles RANDOM-energy substitution (where Energy.Type.RANDOM in
	# a cost can be paid with any color from the pool) which the prior raw-pool
	# check got wrong, causing first-turn rejections for any RANDOM-cost action.
	# A pending exchange bundled in the input (web clients) hasn't been applied to the pool yet
	# — apply_input applies it later — so check affordability against the POST-exchange pool, or
	# a legitimate same-turn exchange-to-fund is wrongly rejected. Godot clients instead apply
	# the exchange up front via submit_energy_exchange (pool already converted), so the caller
	# passes exchange_unapplied=true only for the web/JSON path (whatever the sender's seat).
	var exchange_payload = input.get("exchange", null)
	var affordable
	if exchange_payload != null and exchange_unapplied:
		var offer_dict = {}
		for et in exchange_payload.get("offer", {}).keys():
			offer_dict[int(et)] = int(exchange_payload["offer"][et])
		affordable = sender_team.energy.can_afford_after_exchange(total_cost, offer_dict, int(exchange_payload.get("request", 0)))
	else:
		affordable = sender_team.energy.can_afford(total_cost)
	if not affordable:
		push_warning("[VALIDATE] reject: cannot afford ", total_cost, " from pool ", sender_team.energy.pool, " (exchange ", exchange_payload, ")")
		return false
	return true

# Translates the canonical-frame input package into the legacy local-frame
# turn package shape and feeds it to the shadow manager. Bumps the turn
# timer / acting_player bookkeeping the same way receive_turn_package did.
func apply_input(input, peer_id) -> void:
	if manager == null:
		return
	var sender_role := _peer_canonical_role(peer_id)
	if sender_role < 0:
		return
	var package := _canonical_input_to_legacy_package(input, sender_role)
	afk_misses.erase(peer_id)   # a manual turn resets this player's AFK miss streak
	acting_player = get_opponent(peer_id)
	manager.receive_turn_package(package)
	current_turn_number += 1
	start_turn_timer()

# Returns 0 if peer is the canonical p1 (first key in players), 1 for p2,
# -1 if peer isn't in the match.
func _peer_canonical_role(peer_id) -> int:
	if not peer_id in players:
		return -1
	var keys = players.keys()
	if peer_id == keys[0]:
		return 0
	if len(keys) > 1 and peer_id == keys[1]:
		return 1
	return -1

# Reverses the canonical encoding from BattleManager.build_turn_input back
# to the legacy local-frame shape consumed by process_turn_package. The
# shadow's `player` is always canonical p1, so the legacy frame's "team"
# (the receiving side) is the shadow's player.team and team_mod alternates
# based on whether the sender is canonically p1 or p2.
func _canonical_input_to_legacy_package(input, sender_role: int) -> Dictionary:
	var character_actions: Array = []
	for action in input.get("actions", []):
		var canonical_char := int(action.get("char_idx", 0))
		var local_team_idx := canonical_char - sender_role * 3
		var ability_idx := int(action.get("ability_idx", 0))
		var canonical_targets: Array = action.get("target_idxs", [])
		var legacy_targets: Array = []
		for ct in canonical_targets:
			var canonical_t := int(ct)
			# Legacy targets are in the SENDER's local frame (0..2 = sender
			# team, 3..5 = opposing team). For p1 sender that's identity; for
			# p2 sender we swap the two halves (the same +3/-3 swap that
			# process_turn_package applies when team_mod == 3).
			if sender_role == 0:
				legacy_targets.append(canonical_t)
			else:
				legacy_targets.append(canonical_t + 3 if canonical_t < 3 else canonical_t - 3)
		character_actions.append([local_team_idx, ability_idx, legacy_targets])

	# execution_order: 0..5 = canonical character index, >= 6 = wire ticking ID.
	# Translate character entries back to sender-team local index 0..2 and
	# subtract the +3 ticking offset so the manager sees its native counter ids.
	var legacy_exec_order: Array = []
	for entry in input.get("execution_order", []):
		# JSON-parsed numbers arrive as float (web clients) while Godot RPC sends
		# int; coerce so the canonical->legacy translation works on both transports.
		if entry is int or entry is float:
			var e := int(entry)
			if e >= 0 and e < 6:
				legacy_exec_order.append(e - sender_role * 3)
			elif e >= 6:
				legacy_exec_order.append(e - 3)
			else:
				legacy_exec_order.append(e)
		else:
			legacy_exec_order.append(entry)

	var legacy_exchange = null
	var exchange_payload = input.get("exchange", null)
	if exchange_payload != null:
		var offer_dict := {}
		for energy_type in exchange_payload.get("offer", {}).keys():
			offer_dict[int(energy_type)] = int(exchange_payload["offer"][energy_type])
		legacy_exchange = [offer_dict, int(exchange_payload.get("request", 0))]

	return {
		"random_history": input.get("energy_allocation", []),
		"character_actions": character_actions,
		"execution_order": legacy_exec_order,
		"timeout": false,
		"exchange": legacy_exchange,
	}

# Seconds a given peer gets for their turn: the normal match timer minus AFK_PENALTY_STEP for each
# consecutive turn they've let time out (floored at AFK_MIN_TIMER). Reset by a manual turn.
func _timer_seconds_for(peer) -> float:
	var misses: int = int(afk_misses.get(peer, 0))
	return maxf(AFK_MIN_TIMER, default_match_timer - AFK_PENALTY_STEP * misses)

func start_turn_timer():
	$Timer.stop()
	$Timer.wait_time = _timer_seconds_for(acting_player)
	$Timer.start()
	# The turn may have just rotated TO a player who is currently disconnected — hold the clock for them
	# instead of running a fresh full timer they cannot possibly answer.
	_refresh_timer_pause()

# The turn timer must be paused EXACTLY while the player who owes us an action is disconnected.
# Deriving it from live state (rather than toggling only at the disconnect/reconnect instants) fixes
# three separate unfair-forfeit bugs:
#   * a player who dropped while it was NOT their turn got no protection once the turn rotated to them,
#     so start_turn_timer armed a full unpaused timer and ran them down to an auto-forfeit while offline;
#   * ANY player reconnecting used to blanket-clear the pause, cancelling protection that was being held
#     for the OTHER, still-offline acting player;
#   * the draft shares this $Timer, and one player's disconnect must not freeze the ban/pick deadline
#     for both — the draft clock always runs.
func _refresh_timer_pause() -> void:
	if draft_active:
		$Timer.paused = false
		return
	$Timer.paused = _peer_is_missing(acting_player)

func _peer_is_missing(peer_id) -> bool:
	if peer_id == null or not peer_id in players:
		return false
	return players[peer_id].username in missing_players

func cancel_match():
	if cancelling:
		return
	cancelling = true
	$Timer.stop()
	match_over.emit(self)

# Ends the match with the AFK player as the LOSER, via the same shadow path a surrender uses:
# manager.end_match records the MATCH_ENDED event, then fires server_match_ended (W/L + AP + broadcast
# to both clients) and match_ended (teardown). Guarded against re-entry like cancel_match.
func _forfeit_afk_player(loser_peer) -> void:
	if cancelling:
		return
	cancelling = true
	$Timer.stop()
	if manager == null or players.size() < 2:
		match_over.emit(self)   # can't resolve a winner — fall back to a plain abort
		return
	var winner_peer = get_opponent(loser_peer)
	var p1_peer = players.keys()[0]
	manager.end_match(winner_peer == p1_peer)   # `won` is from p1's (players.keys()[0]) perspective

func handle_turn_timeout():
	if cancelling:
		return
	# During the draft phase the single $Timer drives ban/pick deadlines, not the
	# battle turn timer. Route it before the battle path dereferences the (null) manager.
	if draft_active:
		_handle_draft_timeout()
		return
	if manager == null:
		return
	# The battle is already decided. A finished match can still be holding a LIVE one-shot $Timer:
	# the normal-win path (_on_manager_match_ended) historically never stopped it, and some end paths
	# skip teardown entirely. Without this guard the dead match keeps charging AFK misses, broadcasting
	# phantom timeouts to a player who has already moved on to ANOTHER match (desyncing their client so
	# their real turns stop resolving), driving its bot seat, and eventually force-forfeiting them for
	# a recorded loss — re-arming itself every time. Stop the timer so a zombie can never re-arm.
	if manager.match_over:
		$Timer.stop()
		return
	afk_misses[acting_player] = int(afk_misses.get(acting_player, 0)) + 1
	# Missed AFK_FORFEIT_MISSES turns in a ROW -> auto-forfeit the match for this player.
	if int(afk_misses[acting_player]) >= AFK_FORFEIT_MISSES:
		_forfeit_afk_player(acting_player)
		return
	timed_out = true

	# Drain any stale events the recorder may be holding before applying the
	# timeout package, so the broadcast contains only this timeout's events.
	if event_recorder != null:
		event_recorder.clear()

	# Feed the shadow a timeout package the same way apply_input feeds a real
	# input package — the shadow handles per-team energy generation, ticking
	# effects, and used_ability cleanup the same as it does for real turns.
	var package := {
		"random_history": [],
		"character_actions": [],
		"execution_order": [],
		"timeout": true,
		"exchange": null,
	}
	manager.receive_turn_package(package)
	current_turn_number += 1
	# The timeout resolution itself can END the match (e.g. a DoT ticking during the timeout kills the
	# last character). The end path has already broadcast the finale and torn this match down, so bail
	# before we double-broadcast it and re-arm the timer on an already-freed Match.
	if manager.match_over:
		$Timer.stop()
		return

	var events_payload: Array = []
	if event_recorder != null:
		events_payload = event_recorder.events.duplicate()
		event_recorder.clear()
	var snapshot_payload = manager.serialize_wire_snapshot()
	# The turn passes to the opponent next; tell the client THEIR turn duration (acting_player is
	# still the timed-out player here — it flips just below, after the broadcast).
	snapshot_payload["turn_timer"] = _timer_seconds_for(get_opponent(acting_player))

	timeout_current_player.emit(self, events_payload, snapshot_payload)
	acting_player = get_opponent(acting_player)
	timed_out = false
	start_turn_timer()

func get_player_by_username(username):
	for player in players.values():
		if player.username == username:
			return player

func check_in_player(peer_id, player):
	missing_players.erase(player.username)
	var missing_player = get_player_by_username(player.username)
	for character in missing_player.team.characters:
		player.recruit_character(Character.from_character_name(character.path_name))
	var old_peer_id = players.find_key(missing_player)
	# Rebuild players / peer_username_map preserving the old key order. p1 is
	# players.keys()[0] and p2 is [1] everywhere (canonical seat indexing, role
	# mapping in get_reconnection_info, p1_peer/p2_peer in from_match_manager,
	# get_opponent, server_connection match-end lookups). A naive erase+insert
	# would drop the reconnecting peer to the end and silently flip roles.
	var rebuilt := {}
	var rebuilt_username_map := {}
	for key in players.keys():
		if key == old_peer_id:
			rebuilt[peer_id] = player
			rebuilt_username_map[peer_id] = player.username
		else:
			rebuilt[key] = players[key]
			rebuilt_username_map[key] = peer_username_map[key]
	players = rebuilt
	peer_username_map = rebuilt_username_map
	player.current_match = self
	# acting_player is keyed by peer_id. If the reconnecting player was the one
	# whose turn it is, the stored peer_id is now stale, so validate_input
	# would reject their moves. Bump it to the new peer_id.
	if acting_player == old_peer_id:
		acting_player = peer_id
	# afk_misses is keyed by peer_id too — carry the AFK miss streak across the reconnect so it can't
	# be shed simply by reconnecting.
	if afk_misses.has(old_peer_id):
		afk_misses[peer_id] = afk_misses[old_peer_id]
		afk_misses.erase(old_peer_id)
	# Re-derive the pause. Must NOT blanket-clear it: if the OTHER player is the acting one and is still
	# offline, the clock has to stay held for them.
	_refresh_timer_pause()


func get_reconnection_info(peer_id):
	# Phase 8.1: reconnection is now snapshot-based. The server ships the live
	# wire snapshot (same shape as apply_turn_result's trailing payload) and the
	# client rebuilds its passive manager directly from it — no seed, no history
	# replay, no per-turn re-execution. The reconnection payload is O(1) in turn
	# count, which is the whole point of the phase.
	var player = players[peer_id]
	var opponent = players[get_opponent(peer_id)]
	var player_characters = []
	var enemy_characters = []
	for character in player.team.characters:
		player_characters.append(character.path_name)
	for character in opponent.team.characters:
		enemy_characters.append(character.path_name)
	var enemy_display_info = opponent.display_package()
	# Canonical role of THIS peer: peer_id1 (players.keys()[0]) is always p1,
	# peer_id2 is always p2, matching the seat assignment in from_players.
	var peer_keys = players.keys()
	var canonical_role := 0 if peer_id == peer_keys[0] else 1

	# The authoritative state lives on the shadow. serialize_wire_snapshot is
	# index-stable (sides[0] = p1, sides[1] = p2) and includes energy pools and
	# effect payloads, so the client can walk it with the same _reconcile_*
	# helpers that process regular apply_turn_result payloads.
	var snapshot = {}
	if manager != null:
		snapshot = manager.serialize_wire_snapshot()
	# Ship the REMAINING time, not the full turn length. The server keeps running the SAME $Timer across a
	# reconnect, so handing the client the full duration made its bar restart at 100% and the turn then
	# "ended suddenly" with the bar still nearly full — and that unfair timeout charged an AFK miss, which
	# shortened every subsequent turn (compounding into a forfeit). Falls back to the full duration when
	# no timer is running.
	snapshot["turn_timer"] = $Timer.time_left if not $Timer.is_stopped() else _timer_seconds_for(acting_player)

	var reconnection_package = {
		"enemy": enemy_display_info,
		"player_characters": player_characters,
		"enemy_characters": enemy_characters,
		"snapshot": snapshot,
		"current_timer": $Timer.time_left,
		"match_type": match_type,
		"practice": practice_match,   # so a reconnect into an explicit bot match still shows "Bot Match" + 50/0 AP
		"vs_bot": _has_bot_seat(),    # a RANKED bot game pays 250/50, not 500/50 — the modal needs to know
		"canonical_role": canonical_role,
	}
	return JSON.stringify(reconnection_package)

# True when either seat is an EPHEMERAL server bot. Ranked can seat one (the 30s ranked fallback), and
# its rewards differ from a human game, so a reconnecting client has to be told. An ULTRA bot game pays
# full human rewards, so it must NOT flag here — the reconnecting human sees the normal reward display.
func _has_bot_seat() -> bool:
	for peer_id in players:
		if players[peer_id].is_ephemeral_bot():
			return true
	return false

func check_out_player(peer_id):
	if not peer_id in players:
		return
	missing_players.append(players[peer_id].username)
	# Derive the pause from live state (see _refresh_timer_pause) rather than toggling it only at this
	# instant — a player who drops while it is NOT their turn still needs protection once the turn
	# rotates to them.
	_refresh_timer_pause()

func get_opponent(peer_id):
	if len(players.keys()) < 2:
		return null
	if peer_id == players.keys()[0]:
		return players.keys()[1]
	else:
		return players.keys()[0]

# Returns the username that this peer_id was originally assigned to in this match.
# Used by the server to cross-check that a peer_id still belongs to the same player
# before sending RPCs, preventing misrouted packets after Godot reuses a peer_id.
func get_expected_username(peer_id):
	if peer_id in peer_username_map:
		return peer_username_map[peer_id]
	return null

func get_opponent_username(peer_id):
	var opponent_id = get_opponent(peer_id)
	if opponent_id == null:
		return null
	return get_expected_username(opponent_id)

func get_player_usernames() -> Array:
	var usernames = []
	for player in players.values():
		usernames.append(player.username)
	return usernames

func add_spectator(peer_id: int) -> void:
	spectators[peer_id] = true
	print("[SPECTATOR] Peer ", peer_id, " spectating match ", match_id)

func remove_spectator(peer_id: int) -> void:
	spectators.erase(peer_id)

func get_spectator_init() -> String:
	var keys = players.keys()
	if keys.size() < 2:
		return ""
	var p1 = players[keys[0]]
	var p2 = players[keys[1]]
	var p1_chars := []
	var p2_chars := []
	for character in p1.team.characters:
		p1_chars.append(character.path_name)
	for character in p2.team.characters:
		p2_chars.append(character.path_name)
	var snapshot := {}
	if manager != null:
		snapshot = manager.serialize_wire_snapshot()
	# Remaining time, not the full turn length — same reconnect reasoning as get_reconnection_info above.
	snapshot["turn_timer"] = $Timer.time_left if not $Timer.is_stopped() else _timer_seconds_for(acting_player)
	var package := {
		"p1": p1.display_package(),
		"p2": p2.display_package(),
		"p1_characters": p1_chars,
		"p2_characters": p2_chars,
		"snapshot": snapshot,
		"match_type": match_type,
		"current_timer": $Timer.time_left,
	}
	return JSON.stringify(package)
