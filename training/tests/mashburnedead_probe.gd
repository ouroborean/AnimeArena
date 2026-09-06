extends Node
# Mash Burnedead (Mashle) — enhance kit + immunity passive.
#   godot --headless --path <repo> res://training/tests/mashburnedead_probe.tscn

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

func _fresh(allies, foes) -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", allies)
	var p2 := _build_player("BotEnemy", foes)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _cast(caster, ab, targets, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _shield_total(c) -> int:
	var t := 0
	for s in c.get_shield_effects(): t += int(s.mag)
	return t

func _pool_sum(c) -> int:
	var t := 0
	for v in c.team.energy.pool.values(): t += int(v)
	return t

func _ready():
	print("=== Mash Burnedead probe ===")
	var s = _fresh(["mashburnedead", "naruto", "sakura"], ["eren", "misaka", "gray"])
	var m = s["m"]
	var mash = s["allies"][0]
	var bbd = mash.moveset.base_abilities[0]
	var ballista = mash.moveset.base_abilities[1]
	var hellfall = mash.moveset.base_abilities[2]
	var pwm = mash.moveset.base_abilities[3]

	# --- Passive: Muscle Magic (installed at startup) ---
	_check(mash.has_effect("Muscle Magic", EffectType.Type.MARK, mash) != null, "Passive: drain-immunity mark installed")
	_check(mash.has_effect("Muscle Magic", EffectType.Type.IGNORE_EFFECT, mash) != null, "Passive: BARRIER ignore installed")
	_check(mash.shrug_off_type(EffectType.Type.BARRIER), "Passive: Mash shrugs BARRIER (Nullify)")

	# --- Ballista Knuckle, NOT enhanced: flat 20 ---
	var foe = s["foes"][0]
	var h0 = int(foe.health.hp)
	_cast(mash, ballista, [foe], m)
	_check(h0 - int(foe.health.hp) == 20, "Ballista Knuckle (not enhanced): 20 damage")

	# --- Big Bang Dash: enhance + ignore-non-damage ---
	_cast(mash, bbd, [mash], m)
	_check(mash.has_effect("Big Bang Dash", EffectType.Type.MARK, mash) != null, "Big Bang Dash: Enhanced mark applied")
	_check(mash.effects.get_effects_by_type(EffectType.Type.IGNORE_NON_DAMAGE).size() >= 1, "Big Bang Dash: ignore-non-damage applied")

	# --- Ballista ENHANCED vs a shielded enemy: shatter + 20+10 = 30 ---
	var foe2 = s["foes"][1]
	var cf2 = QueryContext.from_game_state(foe2, m)
	var sh = Effect.shield_effect(15, -1); sh.set_source(bbd); Character.add_allied_effect(cf2, foe2, foe2, sh)
	var f2 = int(foe2.health.hp)
	_cast(mash, ballista, [foe2], m)
	_check(_shield_total(foe2) == 0, "Ballista (enhanced): all Shield shattered")
	_check(f2 - int(foe2.health.hp) == 30, "Ballista (enhanced, Shield removed): 20+10 = 30 damage")

	# --- Hell Fall ENHANCED vs shield + DR: shatter both, +10 each = 25+20 = 45 ---
	var foe3 = s["foes"][2]
	var cf3 = QueryContext.from_game_state(foe3, m)
	var sh3 = Effect.shield_effect(10, -1); sh3.set_source(bbd); Character.add_allied_effect(cf3, foe3, foe3, sh3)
	var dr3 = Effect.damage_reduction_effect(5, -1); dr3.set_source(bbd); Character.add_allied_effect(cf3, foe3, foe3, dr3)
	var f3 = int(foe3.health.hp)
	_cast(mash, hellfall, [foe3], m)
	_check(foe3.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION).is_empty(), "Hell Fall (enhanced): all Damage Reduction removed")
	_check(_shield_total(foe3) == 0, "Hell Fall (enhanced): all Shield shattered")
	_check(f3 - int(foe3.health.hp) == 45, "Hell Fall (enhanced, Shield+DR removed): 25+10+10 = 45 damage")

	# --- Playing With Magic: invulnerable ---
	_cast(mash, pwm, [mash], m)
	_check(mash.effects.get_effects_by_type(EffectType.Type.INVULN).size() >= 1, "Playing With Magic: invulnerable")

	# --- Passive: energy drain immunity ---
	for i in 3: mash.gain_bonus_energy(Energy.Type.GREEN)
	var pool0 = _pool_sum(mash)
	mash.lose_energy(foe, 1)                       # ENEMY drainer -> blocked
	_check(_pool_sum(mash) == pool0, "Passive: an enemy cannot drain Mash's energy")
	mash.lose_energy(mash, 1)                      # friendly source -> still works
	_check(_pool_sum(mash) < pool0, "Passive: a friendly source can still spend energy")

	# --- Passive: hostile Nullify (BARRIER) is shrugged off ---
	var cf = QueryContext.from_game_state(foe, m)
	var nul = Effect.barrier_effect(20, 3); nul.set_source(bbd)
	Character.add_hostile_effect(cf, foe, mash, nul)
	_check(mash.effects.get_effects_by_type(EffectType.Type.BARRIER).is_empty(), "Passive: hostile Nullify does not apply to Mash")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
