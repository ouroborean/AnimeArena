extends Node

# Verifies the anti-reward-hacking property of the potential-based shaping term
# EMPIRICALLY, rather than trusting the citation.
#
# The owner's concern was precise: a bonus for applying debuffs would teach the bot
# to farm debuffs forever instead of finishing the game. The defence is that shaping
# of the form F = gamma*PHI(s') - PHI(s) is policy-invariant, so no weighting of PHI
# can make farming optimal. These checks pin the properties that argument depends on:
#
#   1. A CYCLE pays <= 0. Apply a debuff, let it lapse, repeat: the accumulated
#      shaping must not be positive, or farming is profitable.
#   2. The TERMINAL transition uses PHI(s')=0, or the last step of every match
#      carries a real non-invariant bonus.
#   3. phi_scale = 0 reproduces the OLD reward bit-for-bit (the A/B control).
#   4. PHI responds to the things the owner named: control, weakness/vulnerability,
#      counters, and enemy mitigation (negative).
#
# Every one of those is measured by CALLING _shaped_reward / _potential against a real
# battle with real effects on it. An earlier version re-simulated the arithmetic on two
# probe-local floats, which reduced the whole section to "gamma <= 1" — it stayed green
# with the shaping term deleted, inverted, or replaced by a naive apply-bonus.

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func ckf(label: String, got: float, want: float, tol := 1e-9) -> void:
	ck("%s (got %.6f, want %.6f)" % [label, got, want], absf(got - want) <= tol)

func _build_player(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	return p

# A real STUN, through the real hostile-effect pipeline — PHI_CONTROL_TYPES includes STUN.
func _stun(m, attacker, victim) -> void:
	var st = Effect.stun_effect(4)
	st.set_source(attacker.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(attacker, m), attacker, victim, st)

func _unstun(victim) -> void:
	for e in victim.effects.get_effects_by_type(EffectType.Type.STUN):
		e.end_effect()

func _ready() -> void:
	print("=== potential-based shaping probe ===")
	# NOT add_child(): BotTrainerV3._ready() would launch a real training run.
	var T = load("res://training/bot_trainer.gd").new()

	# A real battle to measure against. _potential / _state_snapshot read manager.player /
	# manager.enemy directly, so without one the potential is 0 no matter what the code does and
	# every check below would be measuring an empty room.
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["naruto", "sasuke", "sakura"], false)
	var p2 = _build_player("BotEnemy", ["gon", "killua", "gray"], true)
	m.start_battle(p1, p2, true, 7, BattleManager.MatchType.BOT)
	T.manager = m
	var attacker = p1.team.characters[0]
	var enemy = p2.team.characters[0]

	# --- 1. CYCLE PROFITABILITY: the whole point ----------------------------
	# Apply a debuff (PHI 0 -> p) then let it lapse (p -> 0), repeatedly. Shaping-only
	# accumulation must never be positive.
	var g: float = T.gamma
	_unstun(enemy)
	ck("(setup) the potential is 0 with nothing applied", T._potential(0) == 0.0)
	_stun(m, attacker, enemy)
	var p: float = T._potential(0)
	ck("(setup) a real stun on an enemy raises the real potential (%.4f)" % p, p > 0.0)
	_unstun(enemy)
	ck("(setup) ...and lapsing takes it straight back to 0", T._potential(0) == 0.0)

	var total := 0.0
	for i in range(50):
		var s0: Dictionary = T._state_snapshot(0)      # PHI = 0
		_stun(m, attacker, enemy)
		total += T._shaped_reward(0, s0)               # the debuff lands
		var s1: Dictionary = T._state_snapshot(0)      # PHI = p
		_unstun(enemy)
		total += T._shaped_reward(0, s1)               # it lapses
	ck("50 real apply/lapse cycles accumulate <= 0 (farming is unprofitable): %.4f" % total, total <= 0.0)
	ckf("one real cycle equals -(1-gamma)*PHI exactly", total / 50.0, -(1.0 - g) * p, 1e-9)
	ck("(teardown) the cycle left nothing behind", T._potential(0) == 0.0)
	# For scale: the same 50 applications under a naive "bonus on apply" scheme would pay
	# 50*PHI, which is the failure mode being avoided.
	print("       (a naive apply-bonus over the same 50 applications would have paid %.2f)" % (50.0 * p))

	# --- 2. HOLDING a debuff is not free either -----------------------------
	# Keeping PHI high across turns pays gamma*PHI - PHI < 0 per turn, so parking in a
	# stun-lock state without progressing is mildly penalised, not rewarded. Measured over a
	# state that did not change at all, so the HP/kill terms are provably out of the way.
	_stun(m, attacker, enemy)
	var held: Dictionary = T._state_snapshot(0)
	var hold: float = T._shaped_reward(0, held)
	ck("holding a high-potential state costs a little per turn (%.4f < 0)" % hold, hold < 0.0)
	ckf("...and it costs exactly -(1-gamma)*PHI", hold, -(1.0 - g) * p, 1e-9)

	# The TERMINAL transition must force PHI(s')=0, or the last step of every match carries a
	# real (non-invariant) bonus. Same unchanged state, terminal=true.
	var term: float = T._shaped_reward(0, held, true)
	ckf("terminal shaping is -PHI(s), not gamma*PHI(s')-PHI(s)", term, -p, 1e-9)
	_unstun(enemy)

	# --- 3. PROGRESS still dominates ----------------------------------------
	# A kill is worth kill_bonus (0.5); the largest single PHI swing must be smaller,
	# or shaping could out-compete actually winning.
	var max_phi_swing: float = T.PHI_CONTROL + T.PHI_AMPLIFY + T.PHI_REACTIVE
	ck("max single-character PHI swing (%.3f) < kill_bonus (%.3f)" % [max_phi_swing, T.kill_bonus],
		max_phi_swing < T.kill_bonus)
	ck("...and far below win_bonus", max_phi_swing < T.win_bonus)

	# --- 4. phi_scale = 0 is the exact old reward ---------------------------
	# Asserted with a LIVE stun on the board, so the potential is genuinely non-zero going in:
	# switching the scale off against an empty battle would have passed with the guard deleted.
	_stun(m, attacker, enemy)
	ck("(setup) the potential is non-zero before the A/B switch (%.4f)" % T._potential(0), T._potential(0) > 0.0)
	T.phi_scale = 0.0
	ck("phi_scale=0 disables the potential entirely (A/B control is exact)",
		T._potential(0) == 0.0 and T._potential(1) == 0.0)
	T.phi_scale = 1.0
	_unstun(enemy)

	# --- 5. the potential covers what was actually asked for ----------------
	var ctrl: Array = T.PHI_CONTROL_TYPES
	ck("control covers STUN", EffectType.Type.STUN in ctrl)
	ck("control covers SILENCE", EffectType.Type.SILENCE in ctrl)
	ck("control covers PARALYZE/BLIND/TAUNT/ISOLATE",
		EffectType.Type.PARALYZE in ctrl and EffectType.Type.BLIND in ctrl \
		and EffectType.Type.TAUNT in ctrl and EffectType.Type.ISOLATE in ctrl)
	var amp: Array = T.PHI_AMPLIFY_TYPES
	ck("weakness/vulnerability covered (VULNERABILITY + DEF_NEGATE)",
		EffectType.Type.VULNERABILITY in amp and EffectType.Type.DEF_NEGATE in amp)
	var react: Array = T.PHI_REACTIVE_TYPES
	ck("counters covered (COUNTER_USE/RECEIVE + REFLECT_USE/RECEIVE)",
		EffectType.Type.COUNTER_USE in react and EffectType.Type.COUNTER_RECEIVE in react \
		and EffectType.Type.REFLECT_USE in react and EffectType.Type.REFLECT_RECEIVE in react)
	# The owner asked for interference to be worth LESS than hard control.
	ck("counters weighted below control (%.3f < %.3f)" % [T.PHI_REACTIVE, T.PHI_CONTROL],
		T.PHI_REACTIVE < T.PHI_CONTROL)
	ck("weakness weighted below control (%.3f < %.3f)" % [T.PHI_AMPLIFY, T.PHI_CONTROL],
		T.PHI_AMPLIFY < T.PHI_CONTROL)
	# MEASURED, not read off the constant's sign: the subtraction is `phi -= PHI_ENEMY_GUARD * ...`
	# inside _potential, and flipping that to `+=` leaves a positive constant positive.
	var base_phi: float = T._potential(0)
	var shield = Effect.shield_effect(30, 4)
	shield.set_source(enemy.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(enemy, m), enemy, enemy, shield)
	var guarded_phi: float = T._potential(0)
	ck("enemy mitigation SUBTRACTS from the potential (%.4f -> %.4f)" % [base_phi, guarded_phi],
		guarded_phi < base_phi and T.PHI_ENEMY_GUARD > 0.0)
	shield.end_effect()

	T.free()
	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
