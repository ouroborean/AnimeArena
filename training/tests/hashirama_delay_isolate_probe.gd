extends Node

# HASHIRAMA'S DELAYED SKILL FIRES EVEN WHEN HE IS ISOLATED.
#
# Parallel case to the Fairy Law fix. The DELAYED_SKILL branch of battle_manager.execute_ticking_effect
# carried the identical self-target gate bug: a delayed skill is SELF-applied (delay_execution ->
# add_allied_effect(context, user, user, ...)), so an isolated Hashirama tripped the ally->ally
# isolation gate and his delayed Deep Forest Bloom fizzled — no damage. Fix mirrors the ticking one:
# exempt self-applied delays (`... and not (effect.target == effect.user)`).
#   godot --headless --path <repo> res://training/tests/hashirama_delay_isolate_probe.tscn

var fails := 0

func _check(c, l, detail := ""):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l + ("  (" + detail + ")" if detail != "" else ""))

func _build(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _ready():
	print("=== hashirama delayed-skill + isolate probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Hashi", ["hashirama", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["killua", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var hashi = p1.team.characters[0]
	var foe = p2.team.characters[0]
	var pollen = hashi.moveset.base_abilities[0]     # hashirama1 = Deep Forest Bloom: Pollen

	# --- Plant a delayed Pollen aimed at one enemy (self-applied DELAYED_SKILL, dur 1) ---
	hashi.targeter.targets = [foe]
	hashi.targeter.main_target = foe
	hashi.used_ability = pollen
	pollen.delay_execution(hashi, m, 0)
	var delayed = hashi.get_delayed_skills()
	_check(delayed.size() > 0, "[setup] a DELAYED_SKILL is planted on Hashirama")
	if delayed.is_empty():
		print("=== probe done: %d failure(s) ===" % fails); get_tree().quit(1); return
	var d = delayed[0]
	_check(d.user == hashi and d.target == hashi, "[setup] the delay is SELF-applied (user == target == Hashirama)")

	# --- Isolate Hashirama, the way La Black Luna does ---
	var qc = QueryContext.from_game_state(foe, m)
	var iso = Effect.isolate(4)
	iso.set_source(foe.moveset.base_abilities[0])
	Character.add_hostile_effect(qc, foe, hashi, iso)
	_check(hashi.is_isolated(), "[setup] Hashirama is Isolated")

	# --- Resolve the delay THROUGH the gate under test ---
	var foe_hp0 = foe.health.hp
	d.duration = 1
	m.execute_ticking_effect(d)
	await get_tree().process_frame

	_check(foe.health.hp < foe_hp0,
		"[FIX] isolated Hashirama's delayed Pollen still hits the enemy (%d -> %d, dealt %d)" % [foe_hp0, foe.health.hp, foe_hp0 - foe.health.hp])

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
