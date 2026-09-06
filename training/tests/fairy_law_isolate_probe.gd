extends Node

# FAIRY LAW RESOLVES EVEN WHEN MAVIS IS ISOLATED.
#
# Bug: Astolfo's La Black Luna Isolates Mavis; when her channeled Fairy Law reaches its resolution
# turn, nothing happens — no enemy damage, no stun, no ally heal. Root cause was in
# battle_manager.execute_ticking_effect: the TICKING_TRIGGER gate `if effect.target.is_isolated()`
# short-circuited the WHOLE trigger. Fairy Law's ticker is SELF-applied (user == target == Mavis), so
# an isolated Mavis tripped a gate meant only for ally->ally delivery. Fix: exempt self-applied tickers
# (`... and not (effect.target == effect.user)`).
#
# This probe fires the ticker THROUGH execute_ticking_effect (the gate under test) with Mavis isolated,
# and asserts the hostile AOE still lands. It also confirms the heal clause still respects isolation.
#   godot --headless --path <repo> res://training/tests/fairy_law_isolate_probe.tscn

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

func _fairy_ticker(mavis):
	for t in mavis.get_ticking_triggers():
		return t
	return null

func _stun_count(c):
	return c.effects.get_effects_by_type(EffectType.Type.STUN).size()

func _ready():
	print("=== fairy law + isolate probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Mavis", ["mavis", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["killua", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var mavis = p1.team.characters[0]
	var ally = p1.team.characters[1]     # gon — a non-isolated teammate
	var foe = p2.team.characters[0]

	# --- Cast Fairy Law (self-channel) ---
	var fairy = mavis.moveset.base_abilities[0]
	mavis.targeter.targets = [mavis]
	mavis.targeter.main_target = mavis
	mavis.used_ability = fairy
	fairy.execute(mavis, m)
	var ticker = _fairy_ticker(mavis)
	_check(ticker != null, "[setup] Fairy Law installs a self-applied ticking trigger")
	if ticker == null:
		print("=== probe done: %d failure(s) ===" % fails); get_tree().quit(1); return
	_check(ticker.user == mavis and ticker.target == mavis, "[setup] ticker is SELF-applied (user == target == Mavis)")

	# --- Isolate Mavis, the way La Black Luna does ---
	var qc = QueryContext.from_game_state(foe, m)
	var iso = Effect.isolate(4)
	iso.set_source(foe.moveset.base_abilities[0])
	Character.add_hostile_effect(qc, foe, mavis, iso)
	_check(mavis.is_isolated(), "[setup] Mavis is Isolated")

	# Wound Mavis (isolated) and the ally (not isolated) so the heal clause is observable.
	mavis.health.hp = maxi(1, mavis.health.hp - 40)
	ally.health.hp = maxi(1, ally.health.hp - 40)
	var foe_hp0 = foe.health.hp
	var foe_stun0 = _stun_count(foe)
	var mavis_hp0 = mavis.health.hp
	var ally_hp0 = ally.health.hp

	# --- Resolve at the end of the channel, THROUGH the gate under test ---
	ticker.duration = 1
	m.execute_ticking_effect(ticker)
	await get_tree().process_frame

	# THE FIX: the hostile AOE lands despite Mavis being Isolated.
	_check(foe.health.hp < foe_hp0,
		"[FIX] isolated Mavis's Fairy Law still damages enemies (%d -> %d, dealt %d)" % [foe_hp0, foe.health.hp, foe_hp0 - foe.health.hp])
	_check(_stun_count(foe) > foe_stun0, "[FIX] ...and still Stuns them")

	# The heal clause still respects isolation: the non-isolated ally heals, the isolated Mavis does not.
	_check(ally.health.hp > ally_hp0,
		"[heal] a non-Isolated ally still heals (%d -> %d)" % [ally_hp0, ally.health.hp])
	_check(mavis.health.hp == mavis_hp0,
		"[heal] the Isolated Mavis does NOT heal (%d -> %d)" % [mavis_hp0, mavis.health.hp])

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
