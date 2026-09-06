extends Node

# PHANTOM DEFEAT — REGRESSION GUARD.
#
# The bug this file exists to keep dead. Player objects are PERSISTENT per account (owned by the
# session map, not by the match). Match.from_players() rebuilds a match by calling
# player.team.clear_characters() on that persistent object, and TeamComponent.characters is the SAME
# array a live match's BattleManager reads. So building a second match for a player who already held
# a live one reached into the LIVE board and emptied it. Three engine reads then went wrong at once,
# and two of them were vacuous loops — they never tested "is this team dead", they iterated the array
# and fell through when there was nothing to iterate:
#   check_lose_condition()  -> empty array => returns TRUE  => instant Defeat at full health
#   check_win_condition()   -> empty array => returns TRUE  => phantom Victory for the opponent
#   _serialize_wire_team()  -> builds its output BY iterating => `team: []` => the client's
#                              `mySide.team.map(charCard)` renders ZERO character panels
# check_match_over() tests LOSE before WIN, so the player who was WINNING ate the loss. A live player
# reported exactly that pair: full-health team, two enemies already dead, instant Defeat, own three
# panels gone. HP was never involved in any of it.
#
# TWO guards now stand between that report and the engine, and this probe pins BOTH:
#
#   GUARD 1 — THE SINK (components/match.gd, from_players).
#     from_players REFUSES to build (returns null) when either seat still holds a live match, or when
#     the same Player object is seated twice. The refusal is emitted BEFORE the first
#     clear_characters() call, and that ordering is the entire point — blocks [D] and [E] assert the
#     live board is still there, same Character instances, same HP, after the refusal.
#
#   GUARD 2 — THE ENGINE (new multiplayer/battle_manager.gd).
#     An EMPTY roster is a CORRUPTED BOARD, not a wiped-out team. check_lose_condition and
#     check_win_condition now return FALSE on an empty array and raise a one-shot [EMPTY-ROSTER]
#     alarm, so a corrupted board can no longer FABRICATE a recorded result. Block [B] pins the
#     player side, [B2] the enemy mirror.
#
# !! READ BEFORE "FIXING" A FAILURE HERE !!
# Block [F] is the counterweight to Guard 1 and the highest-stakes block in the file: a player whose
# previous match has ENDED (decided / cancelled / freed / torn down) MUST still be able to start a
# new one. If [F] goes red, EVERY player is locked out of the game after their first match. Do not
# "fix" [F] by relaxing its shapes — fix the liveness predicate.
#   godot --headless --path <repo> res://training/tests/phantom_defeat_probe.tscn

var fails := 0
var _outcome := ""
var _outcome_mirror := ""
# GDScript lambdas capture locals BY VALUE — a closure writing to a local `var` updates a copy and the
# outer value never moves. Signal sinks must therefore be MEMBER vars, or the assertion reads "" forever
# and silently passes/fails on nothing. (Cost me two red lines writing block [G].)
var _outcome_g := ""
var _outcome_g2 := ""

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build_player(u, names):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	var is_enemy = (u == "ZZ_Foe")
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _wire_team(m, role_idx: int) -> Array:
	return m.serialize_wire_snapshot()["sides"][role_idx]["team"]

func _new_manager(nm: String) -> BattleManager:
	var b := BattleManager.new()
	b.name = nm
	b.shadow_mode = true
	add_child(b)
	return b

# A bare Match node, not started. Guard 1 reads liveness off the MATCH, so these stand in for the
# real thing without needing a server session.
func _new_match_node() -> Match:
	return load("res://components/match.tscn").instantiate() as Match

# Identity fingerprint of a team array: get_instance_id() per member. A rebuild that clears AND
# re-recruits leaves the SIZE at 3 but swaps in brand-new Character instances, so size alone cannot
# tell "guard refused" from "guard ran too late" — this can.
func _fingerprint(p) -> Array:
	var out: Array = []
	for c in p.team.characters:
		out.append(c.get_instance_id())
	return out

# Calls the liveness predicate DIRECTLY, so a failure names the predicate instead of only the
# from_players call that consumed it. Returns a STRING so a wrong answer prints as true/false rather
# than as an opaque assertion.
#
# KNOWN BLIND SPOT, recorded so nobody mistakes it for coverage: the `m == null or not
# is_instance_valid(m)` short-circuit inside _holds_live_match is a CRASH guard, not a decision
# guard, and no assertion in this file can catch its removal. Drop it and the predicate errors on a
# freed/null match — but a GDScript runtime error only aborts the erroring frame, the declared
# `-> bool` return coerces the aborted result to FALSE, and false is the correct answer for a dead
# match anyway. The build proceeds either way; the only difference is a stderr error per call (and,
# in a non-debug build, an actual read through a dangling pointer). Verified empirically, not
# assumed. Watch the run's stderr, not just the failure count.
func _liveness(p) -> String:
	var v = Match._holds_live_match(p)
	if not (v is bool):
		return "CRASHED(" + str(v) + ")"
	return "true" if v else "false"

func _hp_of(p) -> Array:
	var out: Array = []
	for c in p.team.characters:
		out.append(c.health.hp)
	return out

const TEAM_A := ["naruto", "gon", "gray"]
const TEAM_B := ["killua", "misaka", "byakuya"]

func _ready():
	print("=== phantom defeat probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("ZZ_Victim", TEAM_A)
	var p2 = _build_player("ZZ_Foe", TEAM_B)
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.QUICK)

	# ==================================================================================
	# A — BASELINE. The exact board from the report: victim healthy, enemy nearly wiped.
	# ==================================================================================
	for c in p1.team.characters:
		c.health.hp = int(c.health.max_hp * 0.75)
	p2.team.characters[0].dead = true
	p2.team.characters[0].health.hp = 0
	p2.team.characters[1].dead = true
	p2.team.characters[1].health.hp = 0
	p2.team.characters[2].health.hp = 15

	_check(not m.check_lose_condition(), "[A] healthy team at 75% is NOT a loss")
	_check(m.check_win_condition() == false, "[A] enemy with one survivor is not yet a win")
	_check(_wire_team(m, 0).size() == 3, "[A] victim's wire team carries 3 characters (board renders)")

	# ==================================================================================
	# B — GUARD 2, PLAYER SIDE. An empty roster is UNDECIDED, not a wipe. This is the
	#     exact corrupted board the report produced (clear_characters() on a live team).
	#     The panels still vanish — `team: []` is a faithful serialization of a broken
	#     board and is asserted below — but it no longer COSTS the player the match.
	# ==================================================================================
	p1.team.clear_characters()
	_check(p1.team.characters.size() == 0, "[B] clear_characters() empties the LIVE match's team array")
	_check(not m.check_lose_condition(), "[B] empty team is UNDECIDED, NOT a loss (no phantom Defeat)")
	_check(not m.check_lose_condition(), "[B] ...and stays undecided on re-entry (one-shot alarm doesn't flip it)")
	_check(_wire_team(m, 0).size() == 0, "[B] empty team still serializes as [] (the panels genuinely are gone)")
	# check_match_over tests LOSE before WIN. With the loss suppressed and the enemy still holding a
	# survivor, nothing may fire: the corrupted match stays live and surrenderable instead of being
	# recorded as a defeat for a player who was ahead.
	m.match_ended.connect(func (won): _outcome = "win" if won else "loss")
	_check(not m.check_match_over(), "[B] check_match_over() does NOT fire on a corrupted board")
	_check(_outcome == "", "[B] ...and no result is recorded for the victim, who was ahead")

	# ==================================================================================
	# B2 — GUARD 2, ENEMY MIRROR. The same corruption seen from the other side of the
	#      board. If only check_lose_condition were hardened, the OPPONENT of a corrupted
	#      player would still be handed a free Victory over a team that never lost.
	# ==================================================================================
	var m3 := _new_manager("BattleManager3")
	var r1 = _build_player("ZZ_Mirror", TEAM_A)
	var r2 = _build_player("ZZ_MirrorFoe", TEAM_B)
	m3.start_battle(r1, r2, true, 99, BattleManager.MatchType.QUICK)
	for c in r1.team.characters:
		c.health.hp = int(c.health.max_hp * 0.75)
	r2.team.clear_characters()

	_check(r2.team.characters.size() == 0, "[B2] the ENEMY team array is the one emptied this time")
	_check(not m3.check_win_condition(), "[B2] empty enemy team is UNDECIDED, NOT a win (no phantom Victory)")
	_check(not m3.check_lose_condition(), "[B2] the still-healthy player side is not a loss either")
	m3.match_ended.connect(func (won): _outcome_mirror = "win" if won else "loss")
	_check(not m3.check_match_over(), "[B2] check_match_over() does NOT fire on the mirror")
	_check(_outcome_mirror == "", "[B2] ...and no free Victory is handed out")
	_check(_wire_team(m3, 1).size() == 0, "[B2] the enemy's wire team serializes as []")

	# ==================================================================================
	# C — CONTROL: a rebuild that clears AND re-recruits (the non-draft from_players body).
	#     If this ALSO vanished the board, any second match would do it. It does not — the
	#     board comes back with fresh FULL-HP characters. So the report's vanished panels
	#     point at a clear-without-recruit, not at every rebuild. Kept because it is what
	#     rules out "every rebuild is fatal" and pins the silent HP reset.
	# ==================================================================================
	var m2 := BattleManager.new()
	m2.name = "BattleManager2"
	m2.shadow_mode = true
	add_child(m2)
	var q1 = _build_player("ZZ_Victim2", TEAM_A)
	var q2 = _build_player("ZZ_Foe2", TEAM_B)
	m2.start_battle(q1, q2, true, 99, BattleManager.MatchType.QUICK)
	for c in q1.team.characters:
		c.health.hp = int(c.health.max_hp * 0.75)

	# Mirror from_players' non-draft body exactly.
	q1.team.clear_characters()
	q1.equipped_characters.clear()
	for n in TEAM_A:
		q1.recruit_character(Character.from_character_name(n))

	_check(q1.team.characters.size() == 3, "[C] re-recruiting rebuild refills the team")
	_check(not m2.check_lose_condition(), "[C] refilled team is NOT a phantom loss")
	_check(_wire_team(m2, 0).size() == 3, "[C] refilled team still renders 3 panels")
	var all_full := true
	for c in q1.team.characters:
		if c.health.hp != c.health.max_hp:
			all_full = false
	_check(all_full, "[C] but the mid-match damage is GONE — the board silently resets to full HP")

	# ==================================================================================
	# D — GUARD 1: from_players REFUSES a rebuild for a seat that still holds a live match,
	#     and — the load-bearing half — refuses it BEFORE touching anybody's team. Size
	#     alone proves nothing here (the non-draft path clears and re-recruits back to 3),
	#     so every case checks instance IDs and mid-match HP too.
	# ==================================================================================
	var dm := _new_manager("BattleManagerLive")
	var d_victim = _build_player("ZZ_Live", TEAM_A)
	var d_opp = _build_player("ZZ_LiveFoe", TEAM_B)
	dm.start_battle(d_victim, d_opp, true, 99, BattleManager.MatchType.QUICK)
	for c in d_victim.team.characters:
		c.health.hp = int(c.health.max_hp * 0.4)
	var live_match := _new_match_node()
	add_child(live_match)
	live_match.manager = dm            # manager present and match_over false => LIVE
	d_victim.current_match = live_match

	var d_fresh = _build_player("ZZ_Challenger", TEAM_B)
	var victim_ids := _fingerprint(d_victim)
	var victim_hp := _hp_of(d_victim)

	_check(_liveness(d_victim) == "true", "[D0] the liveness predicate says a started, undecided match IS live")
	_check(_liveness(d_fresh) == "false", "[D0] ...and says a player with no match is free")

	# D1 — the busy account is seat 1.
	var refused_1 = Match.from_players(101, d_victim, TEAM_A, 102, d_fresh, TEAM_B, 99, BattleManager.MatchType.QUICK)
	_check(refused_1 == null, "[D1] from_players REFUSES to rebuild a player who holds a live match")
	_check(d_victim.team.characters.size() == 3, "[D1] the live board still has all 3 characters")
	_check(_fingerprint(d_victim) == victim_ids, "[D1] and they are the SAME Character instances (never cleared)")
	_check(_hp_of(d_victim) == victim_hp, "[D1] and their mid-match HP survived (no silent full-heal)")
	_check(d_victim.current_match == live_match, "[D1] the live match pointer was not repointed")
	_check(not dm.check_lose_condition(), "[D1] the live match is still not a loss (root cause never fires)")
	_check(_wire_team(dm, 0).size() == 3, "[D1] the live board still renders 3 panels")

	# D2 — the busy account is seat 2. The refusal must happen before p1's clear_characters(),
	#      or an innocent third party's board is wiped on the way out.
	var d_fresh_ids := _fingerprint(d_fresh)
	var refused_2 = Match.from_players(103, d_fresh, TEAM_B, 104, d_victim, TEAM_A, 99, BattleManager.MatchType.QUICK)
	_check(refused_2 == null, "[D2] a live match on SEAT 2 refuses the build too")
	_check(_fingerprint(d_fresh) == d_fresh_ids, "[D2] the innocent seat-1 player's team was NOT cleared on the way out")
	_check(d_fresh.current_match == null, "[D2] and the innocent player was not bound to a match that does not exist")
	_check(_fingerprint(d_victim) == victim_ids, "[D2] the live board is still untouched")

	# ==================================================================================
	# E — GUARD 1: the same Player object seated twice. Upstream only ever compares PEER
	#     IDS, so one account on two peer ids can reach from_players seated against itself
	#     — and the two clear_characters() calls would wipe that single team twice.
	# ==================================================================================
	var e_self = _build_player("ZZ_SelfSeat", TEAM_A)
	for c in e_self.team.characters:
		c.health.hp = int(c.health.max_hp * 0.6)
	var e_ids := _fingerprint(e_self)
	var e_hp := _hp_of(e_self)
	var refused_self = Match.from_players(201, e_self, TEAM_A, 202, e_self, TEAM_B, 99, BattleManager.MatchType.QUICK)
	_check(refused_self == null, "[E] from_players REFUSES the same Player object on both seats")
	_check(_fingerprint(e_self) == e_ids, "[E] the self-seated player's team was not cleared (same instances)")
	_check(_hp_of(e_self) == e_hp, "[E] and its HP was not reset")

	# ==================================================================================
	# F — THE LOCKOUT GUARD. Highest-stakes block in the file.
	#
	#     Guard 1 blocks on LIVENESS, and liveness has to come off the MATCH object:
	#     Player.current_match is only ever WRITTEN, never cleared, so a naive
	#     `current_match != null` predicate would be a permanently stale pointer to that
	#     account's LAST match and would lock EVERY returning player out of their second
	#     game forever. Each shape below is a real way a match stops being live on the
	#     server. If any of these goes red, the game is unplayable past match one.
	# ==================================================================================

	# F1 — DECIDED: the shadow manager reported match_over (the normal win/loss path).
	var f1a = _build_player("ZZ_Done1", TEAM_A)
	var f1b = _build_player("ZZ_Done2", TEAM_B)
	var decided := _new_match_node()
	add_child(decided)
	var decided_mgr := BattleManager.new()
	decided_mgr.name = "BattleManagerDecided"
	decided_mgr.shadow_mode = true
	decided.add_child(decided_mgr)
	decided.manager = decided_mgr
	decided_mgr.match_over = true
	f1a.current_match = decided
	_check(_liveness(f1a) == "false", "[F1] the liveness predicate returns a hard false on a DECIDED match")
	var built_1 = Match.from_players(301, f1a, TEAM_A, 302, f1b, TEAM_B, 99, BattleManager.MatchType.QUICK)
	_check(built_1 != null, "[F1] LOCKOUT GUARD: a DECIDED match must NOT block the next one")
	if built_1 != null:
		_check(built_1.players.size() == 2, "[F1] ...and the rebuilt match seats both players")
		_check(f1a.team.characters.size() == 3, "[F1] ...with a full team recruited")
		built_1.queue_free()

	# F2 — CANCELLING: cancel_match()/_forfeit_afk_player() has committed to ending it.
	var f2a = _build_player("ZZ_Cancel1", TEAM_A)
	var f2b = _build_player("ZZ_Cancel2", TEAM_B)
	var cancelled := _new_match_node()
	add_child(cancelled)
	cancelled.cancelling = true
	f2a.current_match = cancelled
	_check(_liveness(f2a) == "false", "[F2] the liveness predicate returns a hard false on a CANCELLING match")
	var built_2 = Match.from_players(311, f2a, TEAM_A, 312, f2b, TEAM_B, 99, BattleManager.MatchType.QUICK)
	_check(built_2 != null, "[F2] LOCKOUT GUARD: a CANCELLING match must NOT block the next one")
	if built_2 != null:
		built_2.queue_free()

	# F3 — FREED: the server already tore the match down; current_match is a dangling reference.
	#      is_instance_valid MUST short-circuit before any member access or this is a crash, not a
	#      lockout.
	var f3a = _build_player("ZZ_Freed1", TEAM_A)
	var f3b = _build_player("ZZ_Freed2", TEAM_B)
	var doomed := _new_match_node()
	f3a.current_match = doomed
	doomed.free()
	_check(not is_instance_valid(f3a.current_match), "[F3] the freed match really is a dangling reference")
	# Catches a predicate that BLOCKS on a dead pointer (the lockout shape). It cannot catch a
	# predicate that ERRORS on one — see the blind spot documented on _liveness above.
	_check(_liveness(f3a) == "false", "[F3] the liveness predicate answers false on a freed match")
	var built_3 = Match.from_players(321, f3a, TEAM_A, 322, f3b, TEAM_B, 99, BattleManager.MatchType.QUICK)
	_check(built_3 != null, "[F3] LOCKOUT GUARD: a FREED match must NOT block the next one")
	if built_3 != null:
		built_3.queue_free()

	# F4 — QUEUED FOR DELETION: queue_free is deferred to the end of the frame, so the node is
	#      still is_instance_valid right now but is already gone as far as the server is concerned.
	var f4a = _build_player("ZZ_Queued1", TEAM_A)
	var f4b = _build_player("ZZ_Queued2", TEAM_B)
	var dying := _new_match_node()
	add_child(dying)
	f4a.current_match = dying
	dying.queue_free()
	_check(is_instance_valid(f4a.current_match) and f4a.current_match.is_queued_for_deletion(), "[F4] the dying match is still valid but queued for deletion")
	_check(_liveness(f4a) == "false", "[F4] the liveness predicate returns a hard false on a queued-for-deletion match")
	var built_4 = Match.from_players(331, f4a, TEAM_A, 332, f4b, TEAM_B, 99, BattleManager.MatchType.QUICK)
	_check(built_4 != null, "[F4] LOCKOUT GUARD: a match QUEUED FOR DELETION must NOT block the next one")
	if built_4 != null:
		built_4.queue_free()

	# F5 — NEVER PLAYED: a brand-new account with current_match still null.
	var f5a = _build_player("ZZ_New1", TEAM_A)
	var f5b = _build_player("ZZ_New2", TEAM_B)
	_check(_liveness(f5a) == "false", "[F5] the liveness predicate returns a hard false on a null current_match")
	_check(_liveness(null) == "false", "[F5] ...and on a null Player, without erroring")
	var built_5 = Match.from_players(341, f5a, TEAM_A, 342, f5b, TEAM_B, 99, BattleManager.MatchType.QUICK)
	_check(built_5 != null, "[F5] LOCKOUT GUARD: a player who has never played is obviously allowed")
	if built_5 != null:
		built_5.queue_free()

	# F6 — the DRAFT phase (manager still null) IS live and MUST keep blocking. This is the one
	#      shape in [F] that goes the other way, and it is here so a future "fix" for a false
	#      lockout cannot quietly reopen the hole by treating manager == null as finished.
	var f6a = _build_player("ZZ_Draft1", TEAM_A)
	var f6b = _build_player("ZZ_Draft2", TEAM_B)
	var drafting := _new_match_node()
	add_child(drafting)
	drafting.draft_active = true      # manager stays null for the whole draft
	f6a.current_match = drafting
	var f6a_ids := _fingerprint(f6a)
	_check(_liveness(f6a) == "true", "[F6] the liveness predicate says a manager-less DRAFT match IS live")
	var refused_draft = Match.from_players(351, f6a, TEAM_A, 352, f6b, TEAM_B, 99, BattleManager.MatchType.QUICK)
	_check(refused_draft == null, "[F6] a match still in the DRAFT phase DOES block a rebuild")
	_check(_fingerprint(f6a) == f6a_ids, "[F6] ...and the drafting player's team is untouched")

	# ==================================================================================
	# G — THE COUNTERWEIGHT TO GUARD 2, and the reason it is last: everything above proves
	#     the engine REFUSES to end a match. None of it proves the engine still CAN. Guard 2
	#     added an early return to both win/lose predicates, and an over-broad version of it
	#     would make matches unlosable and unwinnable — every game running until the AFK
	#     forfeit. A genuine wipe is a POPULATED roster whose members are all dead, which is
	#     a different array shape from the empty one, and it must still resolve normally.
	# ==================================================================================
	var m4 := _new_manager("BattleManager4")
	var w1 = _build_player("ZZ_Wiped", TEAM_A)
	var w2 = _build_player("ZZ_Winner", TEAM_B)
	m4.start_battle(w1, w2, true, 99, BattleManager.MatchType.QUICK)
	for c in w1.team.characters:
		c.dead = true
		c.health.hp = 0
	_check(w1.team.characters.size() == 3, "[G] a genuine wipe keeps all 3 characters in the array")
	_check(m4.check_lose_condition(), "[G] a REAL wipe is STILL a loss (matches remain losable)")
	m4.match_ended.connect(func (won): _outcome_g = "win" if won else "loss")
	_check(m4.check_match_over(), "[G] check_match_over() DOES fire on a real wipe")
	_check(_outcome_g == "loss", "[G] ...and records the loss, exactly as before the guard")

	# G2 — the winning mirror. Banished counts as eliminated alongside dead, so cover both.
	var m5 := _new_manager("BattleManager5")
	var v1 = _build_player("ZZ_Victor", TEAM_A)
	var v2 = _build_player("ZZ_Fallen", TEAM_B)
	m5.start_battle(v1, v2, true, 99, BattleManager.MatchType.QUICK)
	v2.team.characters[0].dead = true
	v2.team.characters[0].health.hp = 0
	v2.team.characters[1].dead = true
	v2.team.characters[1].health.hp = 0
	v2.team.characters[2].banished = true
	_check(m5.check_win_condition(), "[G2] a REAL enemy wipe (2 dead + 1 banished) is STILL a win")
	m5.match_ended.connect(func (won): _outcome_g2 = "win" if won else "loss")
	_check(m5.check_match_over(), "[G2] check_match_over() DOES fire on a real enemy wipe")
	_check(_outcome_g2 == "win", "[G2] ...and records the win, exactly as before the guard")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
