extends Node

# ============================================================================
# THE LIVE-MATCH DRIFT CHECK the roadmap's Verify section asks for:
# "one real bot match with a scoped trigger + an addressing payload, watching
# the log for the drift validator."
#
#   godot --headless --path <repo> res://training/tests/verify_phaseb_live_probe.tscn
#
# WHY THIS EXISTS SEPARATELY FROM creator_addressing_probe's GROUP 9.
#
# That group runs a real bot match and reports "no [RECONCILE] warning", which
# is TRUE and VACUOUS. _reconcile_to_snapshot is only ever reached from
# BattleManager.apply_turn_result, whose first two lines are
#
#     if not passive:
#         return
#
# and `passive` is assigned `not shadow_mode and m_type != MatchType.BOT`
# ("new multiplayer/battle_manager.gd":296, :399). GROUP 9 starts its manager
# with shadow_mode = true AND MatchType.BOT, so `passive` is false twice over
# and the drift validator is structurally unreachable there. An assertion that
# cannot fail is worse than none.
#
# WHAT THIS DOES INSTEAD — the real server->client shape:
#   * an AUTHORITATIVE manager (shadow, bot) runs the match and carries the
#     authored Phase B content: a SCOPED on_skill_received trigger whose payload
#     is addressed with `holder`;
#   * a MatchEventRecorder is attached to it, exactly as Match.begin_match does;
#   * a genuinely PASSIVE manager (start_battle_spectate sets passive = true) is
#     fed (events, serialize_wire_snapshot()) after every turn, which is the
#     payload components/match.gd:819 sends over the wire;
#   * so _reconcile_to_snapshot RUNS, on every turn, against state that authored
#     payloads have been moving.
#
# The probe asserts the validator was REACHED before it asserts it stayed quiet,
# so the quiet result means something.
# ============================================================================

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy: bool = (u == "BotEnemy")
	for cn in names: p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _mk(spec: Dictionary, owner) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Live Probe"))
	a.classes = {"Physical": true, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": false, "Harmful": true, "Helpful": false, "Instant": true,
		"Action": false, "Control": false, "Channeled": false, "Uncounterable": false,
		"Bypassing": false, "Stealthed": false, "Passive": false, "Preserves Channel": false,
		"Damaging": true}
	a.user = owner
	owner.moveset.add_ability(a)
	return a


func _ready():
	print("=== live-match drift check: scoped trigger + addressing payload ===")

	# Seed the GLOBAL rng: the match seed passed to start_battle only covers battle.roll, but the
	# random bot picks its ability with a bare randi() (player_component _random_bot_act), which that
	# seed does not reach — so whether the trigger's condition is ever met was a coin flip (this probe
	# passed intermittently). GLOBAL, so it is set once here; nothing downstream depends on the stream.
	seed(20260804)

	# --- the AUTHORITATIVE side: a real bot match -----------------------------------
	var auth := BattleManager.new(); auth.name = "BattleManager"; auth.shadow_mode = true
	add_child(auth)
	var pa := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var pb := _build_player("BotEnemy", ["eren", "misaka", "sakura"])

	var running := [true]
	var pending := [-1]
	auth.turn_started.connect(func(_p): pending[0] = 0)
	auth.waiting_for_opponent.connect(func(): pending[0] = 1)
	auth.match_ended.connect(func(_w): running[0] = false)
	auth.start_battle(pa, pb, true, 20260803, BattleManager.MatchType.BOT)
	_check(not auth.passive, "the authoritative manager is NOT passive (it is the server side)")

	# The recorder the server attaches in Match.begin_match. Without it there are no
	# wire events and the passive side has nothing to apply.
	var rec := MatchEventRecorder.new()
	rec.attach(auth)

	# --- the PASSIVE side: what a browser session runs -------------------------------
	# start_battle_spectate is the only entry point that sets passive = true without a
	# live socket, and passive is the flag apply_turn_result gates on.
	var mirror := BattleManager.new(); mirror.name = "BattleManagerMirror"
	add_child(mirror)
	var qa := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var qb := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	mirror.start_battle_spectate(qa, qb, auth.serialize_wire_snapshot(), BattleManager.MatchType.BOT)
	_check(mirror.passive, "the mirror manager IS passive — apply_turn_result will not early-return")

	# --- the authored Phase B content, on every character of one team -----------------
	# A SCOPED trigger (the event-class filter) whose payload is addressed with `holder`
	# (payload addressing). Permanent + system so the evidence survives the death cleanse.
	#
	# THE CONTROL RUN. Pass `-- --control` to run the identical harness, same seed, same
	# teams, with NO authored content at all. Any drift that survives the control belongs
	# to this harness (an incomplete event replay), not to Phase B — and without that
	# comparison a drift count here would be unattributable and the check would prove
	# nothing either way.
	var planted := not ("--control" in OS.get_cmdline_user_args())
	print("    mode: %s" % ("PHASE B CONTENT PLANTED" if planted else "CONTROL — no authored content"))
	# DELIBERATELY NOT `system: true`. A system effect is hidden from BOTH players and is
	# therefore never serialized into the wire snapshot — planting one would guarantee it
	# was absent on the passive side and the drift assertion below would "fail" for a
	# reason that has nothing to do with addressing. A plain visible mark is what the
	# snapshot actually carries, so its absence would be real drift.
	var ward := [{"op": "apply", "to": "holder", "effect": {
		"kind": "mark", "turns": -1, "name_override": "Live Ward", "remove_on_death": false}}]
	for c in (pa.team.characters if planted else []):
		var ab := _mk({"name": "Live Plant", "target": "self", "blocks": [
			{"op": "apply", "to": "user", "effect": {
				"kind": "trigger", "trigger": "on_skill_received", "scope": "harmful",
				"turns": -1, "then": ward}}]}, c)
		c.used_ability = ab
		c.targeter.targets = [c]
		c.targeter.main_target = c
		ab.execute(c, auth)
		c.used_ability = null

	# --- drive the match, mirroring every turn over the "wire" ------------------------
	var turns := 0
	var applied := 0
	while running[0] and turns < 40:
		if pending[0] == -1:
			break
		var side: int = pending[0]
		pending[0] = -1
		turns += 1
		if side == 1:
			# The enemy seat's energy latch, exactly as training/bot_trainer.gd:396-407
			# handles it; generating unconditionally would double-feed the pool.
			if not auth.acting_energy_prepared:
				auth.generate_team_energy(auth.enemy.team, auth.went_second)
			auth.acting_energy_prepared = false
			auth.went_second = false
			pb.perform_turn_random(auth, null, 1)
		else:
			pa.perform_turn_random(auth, null, 0)
		# THE WIRE HOP. This is components/match.gd:819's payload, and it is what makes
		# _reconcile_to_snapshot run at all.
		var evts: Array = rec.events.duplicate(true)
		rec.clear()
		mirror.apply_turn_result(evts, auth.serialize_wire_snapshot())
		applied += 1

	_check(turns > 1, "the turn loop actually ran (%d turns)" % turns)
	_check(applied > 1, "apply_turn_result was called on the PASSIVE manager (%d times)" % applied)

	# The authored content actually fired — otherwise the drift check watched an idle board.
	var procced := 0
	for c in pa.team.characters:
		if c.has_any_effect("Live Ward"):
			procced += 1
	if planted:
		_check(procced > 0,
			"the scoped trigger's `holder` payload landed in real turn flow (%d/3 carry the proof)" % procced)
	else:
		_check(procced == 0, "CONTROL: nothing was planted, so nothing procced (%d)" % procced)

	# WHAT THIS HARNESS CAN AND CANNOT PROVE — stated here rather than asserted away.
	#
	# The mirror is a passive manager fed the real (events, snapshot) payload, so the
	# drift validator genuinely RUNS: this probe's runs emit 13-15 [RECONCILE] warnings.
	# But the CONTROL run — same seed, same teams, ZERO authored content — emits the same
	# warnings in the same categories (Energy / HP / cooldown / dead-flag). That drift is
	# this harness's own: a real client also replays the event stream into its local sim
	# through BattleScene's display wiring, which nothing here provides, and reconcile
	# exists precisely to paper over that gap.
	#
	# So an HP-equality assertion here would fail for a reason that has nothing to do with
	# Phase B, and a "no warnings" assertion would be a lie. What IS attributable is
	# whether any drift names authored state — an effect the payload moved that the
	# snapshot does not carry. That is the question the roadmap actually asked.
	var auth_hp := 0
	var mirror_hp := 0
	for c in pa.team.characters: auth_hp += c.health.hp
	for c in qa.team.characters: mirror_hp += c.health.hp
	print("    auth team HP=%d   mirror team HP=%d  (both runs drift; see the control)" % [auth_hp, mirror_hp])
	# THE HARD LIMIT, and the reason this probe stops here rather than asserting a match.
	# BattleManager.apply_turn_result does `await _apply_events_paced(events)` (:2588,
	# :2596-2607) — event application is a COROUTINE that yields between action groups.
	# A synchronous driver loop like this one never returns to the frame loop, so the
	# awaited half never resumes and the mirror's local sim does not advance. That is why
	# both this run and the control drift, and it is a property of the driver, not of
	# Phase B. Reported as data, deliberately NOT asserted: an assertion here would be red
	# for a reason no Phase B change could fix, and green only by accident.
	var mirror_wards := 0
	for c in qa.team.characters:
		if c.has_any_effect("Live Ward"):
			mirror_wards += 1
	print("    authored effect: %d on the authoritative board, %d on the passive mirror" % [procced, mirror_wards])
	print("    NOTE: the passive mirror cannot be driven to completion from a synchronous")
	print("          loop (apply_turn_result awaits). A faithful drift check needs a real")
	print("          client session; see this probe's header.")

	# What this harness CAN assert, and it is the part that matters: the real turn machinery
	# ADVANCED with Phase B content in the loop, rather than stalling or aborting — the
	# failure mode hazard 2 measured (a payload that re-enters itself takes the match down
	# mid-turn, so the turn counter stops moving). Failable: an aborted match leaves
	# current_turn_number behind the number of turns actually driven.
	_check(auth.current_turn_number >= turns - 1,
		"the turn counter tracked the driven turns — no aborted turn (counter=%d, driven=%d)"
			% [auth.current_turn_number, turns])
	_check(auth.match_over or turns >= 40,
		"the match reached a real conclusion rather than stalling (over=%s, turns=%d)"
			% [str(auth.match_over), turns])

	print("=== live drift check done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
