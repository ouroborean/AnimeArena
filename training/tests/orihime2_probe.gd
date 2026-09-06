extends Node

# Probe: Orihime S2 — DEFAULT = 30 heal, EMPOWERED = HP rewind to 2 turns prior.
# Run: godot --headless --path <repo> res://training/tests/orihime2_probe.tscn

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

func _ready():
	print("=== Orihime S2 swap probe ===")
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["orihime", "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 77, BattleManager.MatchType.BOT)

	var orihime = p1.team.characters[0]
	var ally = p1.team.characters[1]
	var s2 = orihime.moveset.base_abilities[1]
	orihime.used_ability = s2   # the engine sets this before execute(); resolve_healing reads it

	# --- DEFAULT (not empowered): 30 heal ---
	ally.health.hp = 40
	ally.hp_last_last_turn = 90   # would be a bigger swing IF rewind fired — it must NOT
	orihime.targeter.targets = [ally]
	s2.execute(orihime, m)
	_check(ally.health.hp == 70, "default heals 30: 40 -> %d (expect 70, NOT rewind-to-90)" % ally.health.hp)

	# --- EMPOWERED: rewind to hp_last_last_turn (higher than current) ---
	var ctx = QueryContext.from_game_state(orihime, m)
	var mark = Effect.mark(-1, "Six Princess Shielding Flowers")
	mark.set_source(orihime.moveset.base_abilities[3])
	Character.add_allied_effect(ctx, orihime, orihime, mark)
	_check(orihime.marked_by("Six Princess Shielding Flowers") != null, "setup: empowered mark applied")
	ally.health.hp = 30
	ally.hp_last_last_turn = 85
	s2.execute(orihime, m)
	_check(ally.health.hp == 85, "empowered rewinds to 2-turns-prior: 30 -> %d (expect 85)" % ally.health.hp)

	# --- EMPOWERED, no HP change -> gain energy (rewind's sub-outcome moved with it) ---
	ally.health.hp = 50
	ally.hp_last_last_turn = 50
	var e_before = p1.team.energy.total_available()
	s2.execute(orihime, m)
	_check(ally.health.hp == 50, "empowered + equal HP: no rewind change (stays 50)")
	_check(p1.team.energy.total_available() > e_before, "empowered + equal HP grants energy (%d -> %d)" % [e_before, p1.team.energy.total_available()])

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
