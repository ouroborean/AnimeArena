extends Node

# Runtime smoke test for the new Escanor / Hibiki kits. Builds a real BattleManager battle, runs the
# passives, and drives each ability through the real execute path, asserting the headline mechanics.
#   godot --headless --path <repo> res://training/tests/escanor_hibiki_probe.tscn

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

func _st(c, name, type):
	var e = c.has_effect(name, type, c)
	return e.stack_count() if e else -1

func _ready():
	print("=== ESCANOR / HIBIKI runtime smoke test ===")
	var s = _fresh(["escanor", "hibiki", "naruto"], ["eren", "misaka", "sakura"])
	var m = s["m"]
	var esc = s["allies"][0]; var hib = s["allies"][1]; var ally = s["allies"][2]
	var foes = s["foes"]

	# --- passives installed at start ---
	_check(esc.has_effect("Sunshine", EffectType.Type.TICKING_TRIGGER, esc) != null, "Escanor: Sunshine passive ticker installed")
	_check(esc.has_effect("Rhitta Smash", EffectType.Type.TICKING_TRIGGER, esc) != null, "Escanor: Divine Spear swap watcher installed on slot 0")
	_check(hib.has_effect("Gungnir", EffectType.Type.MARK, hib) != null, "Hibiki: Gungnir counter installed")
	_check(hib.get_effects_by_type(EffectType.Type.DAMAGE_RECEIVE_TRIGGER).size() >= 1, "Hibiki: Gungnir team watchers installed")

	# --- Sunshine gain + heal + cap ---
	esc.health.hp = 50
	esc.moveset.base_abilities[4].gain_stacks(3)
	_check(_st(esc, "Sunshine", EffectType.Type.MARK) == 3, "Sunshine: gain_stacks(3) -> 3 stacks (got %d)" % _st(esc, "Sunshine", EffectType.Type.MARK))
	_check(esc.health.hp == 65, "Sunshine: healed 5 per stack (50 -> %d, expect 65)" % int(esc.health.hp))
	esc.moveset.base_abilities[4].gain_stacks(20)   # push to the cap
	_check(_st(esc, "Sunshine", EffectType.Type.MARK) == 12, "Sunshine: capped at 12 (got %d)" % _st(esc, "Sunshine", EffectType.Type.MARK))

	# --- Divine Spear swap at 12 Sunshine ---
	var active = esc.moveset.get_active_abilities(esc)
	_check(active[0].ability_name == "Divine Spear: Escanor", "Swap: display slot 0 becomes Divine Spear at 12 Sunshine (got %s)" % active[0].ability_name)

	# --- Divine Spear consumes all Sunshine + reverts ---
	var hp0 = int(foes[0].health.hp)
	_cast(esc, esc.moveset.base_abilities[5], [foes[0]], m)
	_check(int(foes[0].health.hp) < hp0, "Divine Spear: dealt Piercing damage (%d -> %d)" % [hp0, int(foes[0].health.hp)])
	_check(_st(esc, "Sunshine", EffectType.Type.MARK) <= 0, "Divine Spear: consumed all Sunshine (got %d)" % _st(esc, "Sunshine", EffectType.Type.MARK))
	_check(esc.moveset.get_active_abilities(esc)[0].ability_name == "Rhitta Smash", "Swap: reverts to Rhitta Smash after consume")

	# --- Rhitta Smash damage + stun scaling ---
	esc.moveset.base_abilities[4].gain_stacks(4)   # 4 stacks -> +20 dmg and non-Strategic stun
	var hp1 = int(foes[1].health.hp)
	_cast(esc, esc.moveset.base_abilities[0], [foes[1]], m)
	_check(int(foes[1].health.hp) == hp1 - 30, "Rhitta Smash: 10 + 5*4 = 30 damage (%d -> %d)" % [hp1, int(foes[1].health.hp)])
	_check(foes[1].get_effects_by_type(EffectType.Type.STUN).size() >= 1, "Rhitta Smash: 4+ Sunshine applies a stun")

	# --- Cruel Sun (all enemies): DoT + weaken (check a LIVE foe; foes[0] was killed by Divine Spear above) ---
	var sun_before = _st(esc, "Sunshine", EffectType.Type.MARK)
	_cast(esc, esc.moveset.base_abilities[1], foes, m)
	_check(_st(esc, "Sunshine", EffectType.Type.MARK) == sun_before + 1, "Cruel Sun: grants a Sunshine stack immediately on cast (manual first instance) — %d -> %d" % [sun_before, _st(esc, "Sunshine", EffectType.Type.MARK)])
	_check(foes[1].get_effects_by_type(EffectType.Type.DAMAGE).size() >= 1, "Cruel Sun: applied an Affliction DoT to a live enemy")
	_check(foes[1].get_effects_by_type(EffectType.Type.DAMAGE_MOD).size() >= 1, "Cruel Sun: applied the -5 damage debuff to a live enemy")

	# --- Pride Flare: Affliction + Taunt + watcher ---
	_cast(esc, esc.moveset.base_abilities[2], [foes[2]], m)
	_check(foes[2].get_effects_by_type(EffectType.Type.TAUNT).size() >= 1, "Pride Flare: Taunts the target")
	_check(esc.get_effects_by_type(EffectType.Type.HARMFUL_RECEIVE_TRIGGER).size() >= 1, "Pride Flare: planted the counter-stack watcher on Escanor")

	# --- Flame of Pride: shield below 5, invuln at 5+ ---
	# reset sunshine low then cast -> shield
	esc.effects.remove_effect("Sunshine", EffectType.Type.MARK, esc)
	esc.moveset.base_abilities[4].gain_stacks(2)   # -> 2 (post-gain 3 after +1 in skill)
	_cast(esc, esc.moveset.base_abilities[3], [esc], m)
	_check(esc.get_effects_by_type(EffectType.Type.SHIELD).size() >= 1, "Flame of Pride: grants a Shield below 5 Sunshine")

	# --- Revive safety: Escanor's permanent machinery survives a death-cleanse ---
	esc.cleanse_death_effects()
	_check(esc.has_effect("Sunshine", EffectType.Type.TICKING_TRIGGER, esc) != null, "Revive-safety: Sunshine ticker survives Escanor's death-cleanse")
	_check(esc.has_effect("Rhitta Smash", EffectType.Type.TICKING_TRIGGER, esc) != null, "Revive-safety: Divine Spear watcher survives Escanor's death-cleanse")
	_check(esc.has_effect("Sunshine", EffectType.Type.MARK, esc) == null, "Revive-safety: Sunshine stacks reset on death (visible mark stays cleansable; the surviving ticker rebuilds them after revive) — intended")

	# --- Hibiki Ex-Drive / Berserk mutual exclusion ---
	_cast(hib, hib.moveset.base_abilities[2], [hib], m)   # Ex-Drive
	_check(hib.has_effect("Ex-Drive", EffectType.Type.MARK, hib) != null, "Ex-Drive: stance marker present")
	_check(hib.get_effects_by_type(EffectType.Type.SHIELD).size() >= 1, "Ex-Drive: +25 Shield")
	_check(not hib.moveset.base_abilities[2].extra_usable(hib), "Ex-Drive: not usable while active")
	_cast(hib, hib.moveset.base_abilities[3], [hib], m)   # Berserk Mode strips Ex-Drive
	_check(hib.has_effect("Berserk Mode", EffectType.Type.MARK, hib) != null, "Berserk Mode: stance marker present")
	_check(hib.has_effect("Ex-Drive", EffectType.Type.MARK, hib) == null, "Mutual exclusion: Berserk removed Ex-Drive")
	_check(hib.get_effects_by_type(EffectType.Type.IGNORE_EFFECT).size() >= 1, "Berserk Mode: stun-immunity (IGNORE_EFFECT) present")
	_check(hib.get_effects_by_type(EffectType.Type.IGNORE_COUNTER).size() >= 1, "Berserk Mode: ignore-counter present")

	# --- Amalgam mark (fresh battle so Hibiki isn't Berserk) ---
	var s2 = _fresh(["hibiki", "naruto", "gon"], ["eren", "misaka", "sakura"])
	var m2 = s2["m"]; var hib2 = s2["allies"][0]; var a2 = s2["allies"][1]; var foes2 = s2["foes"]
	_cast(hib2, hib2.moveset.base_abilities[0], [foes2[0]], m2)   # Amalgam
	_check(foes2[0].get_effects_by_type(EffectType.Type.DAMAGE_RECEIVE_TRIGGER).size() >= 1, "Amalgam: placed the reward window on the enemy")
	# an ally damages the marked enemy -> ally should heal 10
	a2.health.hp = 50
	var actx = QueryContext.from_game_state(a2, m2)
	a2.used_ability = a2.moveset.base_abilities[0]
	Character.resolve_damage(actx, foes2[0], 15, DamageType.Type.NORMAL)
	a2.used_ability = null
	_check(a2.health.hp > 50, "Amalgam: an ally damaging the marked enemy healed (50 -> %d)" % int(a2.health.hp))

	# --- Gungnir: 50 team damage -> a strike-twice charge ---
	var fctx = QueryContext.from_game_state(foes2[0], m2)
	foes2[0].used_ability = foes2[0].moveset.base_abilities[0]
	Character.resolve_damage(fctx, a2, 50, DamageType.Type.NORMAL)
	foes2[0].used_ability = null
	_check(hib2.has_effect("Gungnir Charge", EffectType.Type.MARK, hib2) != null, "Gungnir: 50 team damage grants a strike-twice charge")
	var gcnt = hib2.has_effect("Gungnir", EffectType.Type.MARK, hib2)
	_check(gcnt != null and gcnt.display_system, "Gungnir: team-damage counter is visible to both players (display_system)")
	_check(gcnt != null and gcnt.unique_render_id == 1, "Gungnir: counter render id 1")
	var gch = hib2.has_effect("Gungnir Charge", EffectType.Type.MARK, hib2)
	_check(gch != null and gch.unique_render_id == 2, "Gungnir: charge render id 2 (distinct from counter)")

	# --- Revive safety: Gungnir counter + watchers survive Hibiki's death-cleanse ---
	hib2.cleanse_death_effects()
	_check(hib2.has_effect("Gungnir", EffectType.Type.MARK, hib2) != null, "Revive-safety: Gungnir counter survives Hibiki's death-cleanse")
	_check(hib2.get_effects_by_type(EffectType.Type.DAMAGE_RECEIVE_TRIGGER).size() >= 1, "Revive-safety: Gungnir watchers survive Hibiki's death-cleanse")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit(0 if fails == 0 else 1)
