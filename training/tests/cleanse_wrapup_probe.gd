extends Node

# ============================================================================
# Regression probe: cleansing an effect must run its teardown (wrapup_func +
# shield/barrier break hooks), not silently drop it.
#
# Scenario A (the reported bug): Mash casts "A Knight That Protects" — an ally
# becomes permanently invuln + reflect, Mash gains a Shield, her S4 swaps to
# Shield of White Walls. Inuyasha's Iron Reaver cleanses Mash's own effects.
# Before the fix: the Shield vanished but break_vow never fired, so the ally
# stayed permanently invulnerable and Mash's kit never reset. After: the vow
# fully breaks.
#
# Scenario B: a generic wrapup_func on a cleansable non-shield effect fires on
# cleanse.
#
# Run:  godot --headless --path <repo> res://training/tests/cleanse_wrapup_probe.tscn
# Exit code = failed assertions (0 = pass).
# ============================================================================

var fails := 0

func _check(cond: bool, label: String):
	if cond:
		print("  PASS  " + label)
	else:
		fails += 1
		print("  FAIL  " + label)

func _build_player(username: String, char_names: Array) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = username
	p.set_username(username)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	var is_enemy := (username == "BotEnemy")
	for cn in char_names:
		p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _ready():
	print("=== cleanse wrapup teardown probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	# p1 = Mash + an ally to protect; p2 = Inuyasha (the cleanser).
	var p1 := _build_player("BotPlayer", ["mash", "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["inuyasha", "eren", "misaka"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var mash = p1.team.characters[0]
	var ally = p1.team.characters[1]
	var inuyasha = p2.team.characters[0]

	# --- Cast "A Knight That Protects" (mash4) targeting the ally ---
	var mash4 = mash.moveset.base_abilities[3]
	mash.targeter.targets = [ally]
	mash.targeter.main_target = ally
	mash4.execute(mash, m)

	var knight := "A Knight That Protects"
	_check(ally.is_invuln(null) or ally.get_effects_by_type(EffectType.Type.INVULN).size() > 0,
		"setup: protected ally is invulnerable")
	_check(mash.get_shield_effects().size() > 0, "setup: Mash has the Shield")
	_check(mash.effects.has_effect(knight, EffectType.Type.SHIELD, mash) != null,
		"setup: Shield is the Knight shield")
	var swapped_before = mash.moveset.get_active_abilities(mash)[3].ability_name
	_check(swapped_before == "Shield of White Walls",
		"setup: Mash S4 swapped to Shield of White Walls (was '%s')" % swapped_before)

	# --- Inuyasha cleanses Mash's own effects (Iron Reaver, mash-as-target) ---
	mash.effects.cleanse_all_ally_effects(mash, inuyasha)

	# --- Assert the vow fully tore down ---
	_check(mash.get_shield_effects().size() == 0, "Shield removed by the cleanse")
	_check(mash.effects.has_effect(knight, EffectType.Type.SHIELD, mash) == null,
		"Knight shield gone from Mash")
	var ally_invuln = ally.get_effects_by_type(EffectType.Type.INVULN).size()
	var ally_reflect = ally.get_effects_by_type(EffectType.Type.REFLECT_RECEIVE).size()
	_check(ally_invuln == 0, "break_vow FIRED: ally is no longer invulnerable (had %d invuln)" % ally_invuln)
	_check(ally_reflect == 0, "break_vow FIRED: ally reflect removed (had %d)" % ally_reflect)
	# break_vow marks the breaker (Inuyasha) with the Around Round Axe punish.
	var punished = inuyasha.effects.get_all_effects_by_name(knight, mash).size() > 0 \
		or inuyasha.marked_by("Around Round Axe") != null \
		or inuyasha.effects._effects.any(func(e): return "Around Round Axe" in str(e.description))
	_check(punished, "break_vow attributed the break to Inuyasha (breaker threaded)")

	# --- Scenario B: generic wrapup on a cleansable non-shield effect ---
	var ctx = QueryContext.from_game_state(mash, m)
	var flag := {"fired": false}
	var probe = Effect.trigger_effect(Trigger.always(func(_c): pass),
		EffectType.Type.DAMAGE_RECEIVE_TRIGGER, 3, "probe")   # dur>=0 -> cleansable
	probe.set_source(mash4)
	probe.wrapup_func = func(_c): flag["fired"] = true
	# Place it as a hostile effect on eren so a self-cleanse strips it.
	var eren = p2.team.characters[1]
	Character.add_hostile_effect(ctx, mash, eren, probe)
	_check(eren.effects._effects.has(probe), "setup B: probe effect on eren")
	eren.effects.cleanse_all_enemy_effects(eren, eren)
	_check(flag["fired"], "generic wrapup_func fired on cleanse (was silently skipped before)")
	_check(not eren.effects._effects.has(probe), "probe effect removed by cleanse")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
