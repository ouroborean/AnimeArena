extends Node

# Cooldown / Paralyze regression probe.
#
# THE BUG THIS LOCKS: start_cooldown() writes `cooldown + 1`, and advance_cooldowns() takes that +1
# back at the end of the acting team's turn. Paralyze freezes advance_cooldowns. The old code tried
# to pre-compensate (`if user.paralyzed(): start_mod = 0`), but that decision is made at
# battle_manager.gd:1190 — BEFORE check_ability_use_triggers at :1206, which is where reactive
# Paralyze sources (Yoruichi's Shunko: Gather, Rimuru's Gluttony counter) actually land. So any skill
# used into a mid-action Paralyze settled on cooldown + 1: a cooldown-0 skill came back UNUSABLE.
#
# The fix stamps the turn in start_cooldown and decides in advance_cooldowns, so the +1 is exempt
# from the freeze while genuine countdown progress is still frozen. These checks cover all four
# quadrants (paralyze before / during / absent, used / not used this turn).
#   godot --headless --path <repo> res://training/tests/cooldown_paralyze_probe.tscn

var fails := 0

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
	var is_enemy = (u == "BotEnemy")
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

# The REAL use path, in battle_manager's order: start_cooldown() first, then execute, then the
# character's own ACTION_USE_TRIGGERs. Getting that order right is the entire point of this probe.
func _use(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.used_ability = ab
	ab.start_cooldown()
	ab.execute(caster, m)
	caster.check_ability_use_triggers(m, ab)
	return ab

func _pass_turn(m):
	m.end_of_turn_effect_handling()

func _to_side(m, want_enemy: bool):
	for _i in range(4):
		if m.waiting_for_turn == want_enemy:
			return
		m.end_of_turn_effect_handling()

func _revive(p):
	for c in p.team.characters:
		c.dead = false
		c.banished = false
		c.health.hp = c.health.max_hp

func _paralyze(m, target, dur := 2):
	var eff = Effect.paralyze_effect(dur)
	eff.set_source(target.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(target, m), target, target, eff)

func _ready():
	print("=== cooldown / paralyze probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["yoruichi", "naruto", "gon"])
	var p2 = _build_player("BotEnemy", ["killua", "misaka", "gray"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	var y = p1.team.characters[0]
	var foe = p2.team.characters[0]
	# A SEPARATE character for the control sweep: it uses every skill in the kit, and Killua Hide
	# grants Invulnerability, which would then block Gather's Paralyze from landing on the subject.
	var ctrl = p2.team.characters[1]

	# ==================================================================================
	# CONTROL: no Paralyze anywhere. Every cooldown must settle on exactly its printed value.
	# ==================================================================================
	_to_side(m, true)
	for idx in range(4):
		var ab = ctrl.moveset.base_abilities[idx]
		var printed: int = int(ab.cooldown)
		_use(m, ctrl, idx, [ctrl] if ab.target_type() == TargetType.Type.SELF else [y])
		_check(int(ab.cooldown_remaining) == printed + 1,
			"[control] %s is stamped at printed+1 during the turn (%d, printed %d)" % [ab.ability_name, int(ab.cooldown_remaining), printed])
	_pass_turn(m)
	for idx in range(4):
		var ab = ctrl.moveset.base_abilities[idx]
		_check(int(ab.cooldown_remaining) == int(ab.cooldown),
			"[control] %s settles on its printed cooldown %d (got %d)" % [ab.ability_name, int(ab.cooldown), int(ab.cooldown_remaining)])

	# ==================================================================================
	# CASE B — the reported bug: Paralyze applied DURING the action, after start_cooldown.
	# Yoruichi's Shunko: Gather is the live source; its watcher fires from check_ability_use_triggers.
	# ==================================================================================
	_to_side(m, false)
	_revive(p2)
	for ab in foe.moveset.base_abilities:
		ab.cooldown_remaining = 0
	var yy = y.moveset.base_abilities[0]
	yy.execute(y, m)                                   # install Gather's per-enemy watchers
	_to_side(m, true)
	_revive(p2)

	var zero_cd = null
	var some_cd = null
	for ab in foe.moveset.base_abilities:
		if int(ab.cooldown) == 0 and zero_cd == null:
			zero_cd = ab
		elif int(ab.cooldown) > 0 and some_cd == null:
			some_cd = ab
	_check(zero_cd != null, "the enemy has a cooldown-0 skill to test with")

	var zero_idx: int = foe.moveset.base_abilities.find(zero_cd)
	_check(not foe.paralyzed(), "[case B] the enemy is NOT paralyzed before acting")
	_use(m, foe, zero_idx, [y] if zero_cd.target_type() != TargetType.Type.SELF else [foe])
	_check(foe.paralyzed(), "[case B] Shunko: Gather paralyzed them DURING the action")
	_check(int(zero_cd.cooldown_remaining) == 1, "[case B] mid-turn the cooldown-0 skill reads 1 (the bookkeeping +1)")
	_pass_turn(m)
	_check(int(zero_cd.cooldown_remaining) == 0,
		"[case B] a cooldown-0 skill used into a mid-action Paralyze settles on 0, NOT 1 (got %d)" % int(zero_cd.cooldown_remaining))

	# A skill they did NOT use this turn must still be frozen — that is what Paralyze is for.
	if some_cd != null:
		_to_side(m, true)
		_revive(p2)
		_paralyze(m, foe, 6)              # Gather's own 2-duration Paralyze has expired by now
		some_cd.cooldown_remaining = 3
		_check(foe.paralyzed(), "[freeze] the enemy is paralyzed and uses NOTHING this turn")
		_pass_turn(m)
		_check(int(some_cd.cooldown_remaining) == 3,
			"[freeze] an UNUSED skill's cooldown is still frozen by Paralyze (got %d)" % int(some_cd.cooldown_remaining))
		for eff in foe.effects.get_effects_by_type(EffectType.Type.PARALYZE):
			foe.effects.erase_effect(eff)

	# ==================================================================================
	# CASE A — Paralyze already present BEFORE the turn. The old code got this right; it must stay right.
	# ==================================================================================
	_to_side(m, true)
	_revive(p2)
	for ab in foe.moveset.base_abilities:
		ab.cooldown_remaining = 0
	# Strip Gather's watchers so only the pre-applied Paralyze is in play.
	for eff in foe.effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER):
		foe.effects.erase_effect(eff)
	_paralyze(m, foe, 4)
	_check(foe.paralyzed(), "[case A] the enemy is paralyzed BEFORE acting")
	var a_idx: int = foe.moveset.base_abilities.find(zero_cd)
	_use(m, foe, a_idx, [y] if zero_cd.target_type() != TargetType.Type.SELF else [foe])
	_pass_turn(m)
	_check(int(zero_cd.cooldown_remaining) == 0,
		"[case A] pre-applied Paralyze also settles a cooldown-0 skill on 0 (got %d)" % int(zero_cd.cooldown_remaining))

	if some_cd != null:
		_to_side(m, true)
		_revive(p2)
		some_cd.cooldown_remaining = 0
		var printed_b: int = int(some_cd.cooldown)
		var b_idx: int = foe.moveset.base_abilities.find(some_cd)
		_check(foe.paralyzed(), "[case A] still paralyzed for the nonzero-cooldown check")
		_use(m, foe, b_idx, [y] if some_cd.target_type() != TargetType.Type.SELF else [foe])
		_pass_turn(m)
		_check(int(some_cd.cooldown_remaining) == printed_b,
			"[case A] a cooldown-%d skill settles on %d under Paralyze (got %d)" % [printed_b, printed_b, int(some_cd.cooldown_remaining)])

	print("=== %s ===" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	get_tree().quit(0 if fails == 0 else 1)
