extends Node
# Runtime checks for the 2026-08-12 balance batch (Escanor / Android 17 / Byakuya / Tsubasa / Machinedramon).
#   godot --headless --path <repo> res://training/tests/balance_batch_probe.tscn

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

func _cnt(c, type) -> int:
	return c.effects.get_effects_by_type(type).size()

func _ready():
	print("=== BALANCE BATCH probe ===")

	# ============ Battle A: Escanor / Android 17 / Byakuya ============
	var s = _fresh(["escanor", "seventeen", "byakuya"], ["eren", "misaka", "sakura"])
	var m = s["m"]
	var esc = s["allies"][0]; var a17 = s["allies"][1]; var bya = s["allies"][2]
	var foes = s["foes"]

	# --- Escanor: Cruel Sun rework ---
	var cruel = esc.moveset.base_abilities[1]
	var sun_before = _sun(esc)
	_cast(esc, cruel, foes, m)
	_check(_cnt(foes[0], EffectType.Type.DAMAGE_MOD) == 0, "Cruel Sun: no -5 damage debuff on enemies (removed)")
	_check(foes[0].get_effects_by_type(EffectType.Type.DAMAGE).size() >= 1, "Cruel Sun: still applies the Affliction DoT")
	var htrig = esc.has_effect("Cruel Sun", EffectType.Type.HARMFUL_USE_TRIGGER, esc)
	_check(htrig != null, "Cruel Sun: installs a HARMFUL_USE_TRIGGER on Escanor")
	_check(htrig != null and htrig.waiting == true, "Cruel Sun: trigger.waiting=true (Cruel Sun's own cast grants no stack)")
	_check(_sun(esc) == sun_before, "Cruel Sun: cast itself does NOT grant a Sunshine stack")
	# Fire the harmful-use callback the way a LATER Harmful skill would -> +1 Sunshine.
	if htrig != null:
		var ctx = QueryContext.from_effect_end(htrig)
		cruel.cruel_sun_harmful(ctx)
		_check(_sun(esc) == sun_before + 1, "Cruel Sun: a later Harmful skill grants +1 Sunshine")

	# --- Escanor: Sunshine is now cleansable ---
	esc.moveset.base_abilities[4].gain_stacks(3)
	_check(_sun(esc) >= 1, "Sunshine present before cleanse")
	esc.effects.cleanse_all_ally_effects(esc, foes[0])   # buff-strip (Iron Reaver idiom)
	_check(esc.has_effect("Sunshine", EffectType.Type.MARK, esc) == null, "Sunshine: now removed by a cleanse (cleansable)")

	# --- Android 17: S3 damage 15 + single hit at default cost; S4 shield 25 ---
	var s3 = a17.moveset.base_abilities[2]
	var hp0 = int(foes[1].health.hp)
	_cast(a17, s3, [foes[1]], m)
	_check(hp0 - int(foes[1].health.hp) == 15, "Android 17 S3: cast-turn damage is exactly 15 (no double hit at default cost)")
	_check(_cnt(foes[1], EffectType.Type.COST_MOD) >= 1, "Android 17 S3: applies the cost tax")
	var s3dot = foes[1].has_effect("Android Assault", EffectType.Type.DAMAGE, a17)
	_check(s3dot != null and s3dot.duration == 1, "Android 17 S3: DoT dur=1 at default (2N-1, N=1 -> 0 extra ticks)")
	var s4 = a17.moveset.base_abilities[3]
	_cast(a17, s4, [a17], m)
	var shield = a17.has_effect("Barrier", EffectType.Type.SHIELD, a17)
	_check(shield != null and shield.mag == 25, "Android 17 S4: Shield is 25")

	# --- Byakuya: Senka is instant (15 Piercing + permanent -5 damage) ---
	var senka = bya.moveset.base_abilities[2]
	var bhp = int(foes[2].health.hp)
	_cast(bya, senka, [foes[2]], m)
	_check(bhp - int(foes[2].health.hp) == 15, "Byakuya Senka: deals 15 immediately (instant)")
	var wk = foes[2].has_effect("Senka", EffectType.Type.DAMAGE_MOD, bya)
	_check(wk != null and wk.duration < 0, "Byakuya Senka: permanent -5 damage debuff on the enemy")

	# ============ Battle B: Tsubasa / Machinedramon ============
	var s2 = _fresh(["tsubasa", "machinedramon", "naruto"], ["eren", "misaka", "sakura"])
	var m2 = s2["m"]
	var tsu = s2["allies"][0]; var mac = s2["allies"][1]
	var foes2 = s2["foes"]

	# --- Tsubasa: Burning Wrath Whirl is a Channeled AOE DoT that swaps to Blade on the final tick ---
	var whirl = tsu.moveset.base_abilities[2]
	var fhp = int(foes2[0].health.hp)
	_cast(tsu, whirl, foes2, m2)
	var dmgtrig = tsu.has_effect("Burning Wrath Whirl", EffectType.Type.TICKING_TRIGGER, tsu)
	_check(dmgtrig != null and dmgtrig.channel == true, "Tsubasa: Channeled TICKING_TRIGGER installed")
	_check(_cnt(tsu, EffectType.Type.CHANNEL_CANCEL) >= 1, "Tsubasa: CHANNEL_CANCEL master installed (stun/new-skill breaks it)")
	_check(fhp - int(foes2[0].health.hp) == 10, "Tsubasa: first tick deals 10 Affliction AOE on the cast turn")
	_check(dmgtrig != null and dmgtrig.mag == 1, "Tsubasa: tick counter at 1 after cast")
	# --- first-turn non-Strategic stun on every enemy (manual, since a ticking effect won't fire turn 0) ---
	var stun0 = foes2[0].has_effect("Burning Wrath Whirl", EffectType.Type.STUN, tsu)
	_check(stun0 != null, "Tsubasa: first turn applies a STUN to enemies")
	_check(stun0 != null and ("Strategic" in stun0.exclusion_targets), "Tsubasa: the stun EXCLUDES Strategic (stuns non-Strategic skills)")
	var all_stunned = true
	for f in foes2:
		if f.has_effect("Burning Wrath Whirl", EffectType.Type.STUN, tsu) == null:
			all_stunned = false
	_check(all_stunned, "Tsubasa: first-turn stun is AOE (hits every enemy)")
	var stun_n_before = foes2[0].effects.get_effects_by_type(EffectType.Type.STUN).size()
	# Fire the tick to the final one -> the ability_swap to Burning Wrath Blade is installed.
	if dmgtrig != null:
		var c2 = QueryContext.from_effect_end(dmgtrig)
		whirl.wrath_tick(c2)  # mag 2
		whirl.wrath_tick(c2)  # mag 3 -> swap
		_check(tsu.has_effect("Burning Wrath Whirl", EffectType.Type.ABILITY_SWAP, tsu) != null, "Tsubasa: final tick installs the swap to Burning Wrath Blade")
		_check(foes2[0].effects.get_effects_by_type(EffectType.Type.STUN).size() == stun_n_before, "Tsubasa: later ticks do NOT re-apply the stun (first-turn only)")

	# --- Machinedramon EMP Wave: gains 1 Blue energy, still becomes invulnerable ---
	var blue_before = int(mac.team.energy.pool.get(Energy.Type.BLUE, 0))
	var emp = mac.moveset.base_abilities[3]
	_cast(mac, emp, [mac], m2)
	_check(_cnt(mac, EffectType.Type.INVULN) >= 1, "Machinedramon EMP Wave: still becomes invulnerable")
	_check(int(mac.team.energy.pool.get(Energy.Type.BLUE, 0)) == blue_before + 1, "Machinedramon EMP Wave: gains 1 Blue energy")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()

func _sun(c) -> int:
	var e = c.has_effect("Sunshine", EffectType.Type.MARK, c)
	return e.stack_count() if e else 0
