extends Node

# Probe: Mayuri's permanent Drug-rotation marker must render as its OWN tooltip,
# not collapsed into the DR + heal-over-time he gets from self-casting
# Flesh-Healing Drug. All three share effect_name "Flesh-Healing Drug" (the
# cycler is deliberately sourced from kurotsuchi3), so separation depends on
# unique_render_id.
# Run: godot --headless --path <repo> res://training/tests/kurotsuchi_cluster_probe.tscn

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
	print("=== Kurotsuchi drug-tooltip clustering probe ===")
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["kurotsuchi", "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 404, BattleManager.MatchType.BOT)

	var mayuri = p1.team.characters[0]
	# The passive (kurotsuchi5) installs the cycler at startup.
	var cyclers = []
	for e in mayuri.effects._effects:
		if e.effect_name() == "Flesh-Healing Drug" and e.effect_type == EffectType.Type.TICKING_TRIGGER:
			cyclers.append(e)
	_check(cyclers.size() == 1, "passive installed the Drug cycler (found %d)" % cyclers.size())
	if cyclers.is_empty():
		print("=== probe done: %d failure(s) ===" % fails); get_tree().quit(fails); return
	_check(cyclers[0].unique_render_id != 0, "cycler has a non-default unique_render_id (%d)" % cyclers[0].unique_render_id)

	# Mayuri self-casts Flesh-Healing Drug (kurotsuchi3).
	var s3 = mayuri.moveset.base_abilities[2]
	mayuri.used_ability = s3
	mayuri.targeter.targets = [mayuri]
	mayuri.targeter.main_target = mayuri
	mayuri.health.hp = 60
	s3.execute(mayuri, m)

	var named = []
	for e in mayuri.effects._effects:
		if e.effect_name() == "Flesh-Healing Drug":
			named.append(e)
	_check(named.size() >= 3, "cycler + DR + heal-over-time all present (%d effects named Flesh-Healing Drug)" % named.size())

	# Cluster exactly as the engine/client do: (effect_name + unique_render_id, user).
	var clusters = mayuri.effects.get_effect_clusters(mayuri.effects._effects)
	var drug_clusters := 0
	for key in clusters.keys():
		if str(key[0]).begins_with("Flesh-Healing Drug"):
			drug_clusters += 1
	_check(drug_clusters == 2, "Flesh-Healing Drug renders as 2 separate tooltips (rotation vs. drug effects); got %d" % drug_clusters)

	# And the per-cast DR + heal still share ONE tooltip (default id 0).
	var cast_group := 0
	for key in clusters.keys():
		if str(key[0]) == "Flesh-Healing Drug0":
			cast_group = clusters[key].size()
	_check(cast_group >= 2, "the cast's DR + heal still group together in one tooltip (%d effects)" % cast_group)

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
