extends Node

# ============================================================================
# BotObservation honesty probe (bot-training v3, spec §9 step 3).
#
# Builds a real shadow-mode battle, plants invisible / system / revealable
# effects, and asserts the observation layer shows each seat EXACTLY what the
# web client would render for that seat — nothing more.
#
# Run:  godot --headless --path <repo> res://training/tests/observation_probe.tscn
# Exit code = number of failed assertions (0 = pass).
# ============================================================================

var fails := 0


func _check(cond: bool, label: String):
	if cond:
		print("  PASS  " + label)
	else:
		fails += 1
		print("  FAIL  " + label)


func _build_player(username: String, char_names: Array) -> Player:
	var player_node: Player = load("res://components/player_component.tscn").instantiate()
	player_node.username = username
	player_node.set_username(username)
	player_node.mission_reference = {}
	player_node.mission_data = {}
	player_node.bot_player = true
	player_node.bot_turn_delay = 0
	var is_enemy := (username == "BotEnemy")
	for char_name in char_names:
		var character = Character.from_character_name(char_name)
		player_node.recruit_character(character, is_enemy)
	for character in player_node.team.characters:
		character.bot_character = true
	return player_node


## First (character, ability) pair on `team` whose Physical class matches
## `want_physical` (source for the Toph-reveal cases). [null, null] if none.
func _find_ability(team, want_physical: bool) -> Array:
	for character in team.characters:
		for ability in character.moveset.base_abilities:
			if bool(ability.classes.get("Physical", false)) == want_physical:
				return [character, ability]
	return [null, null]


func _ready():
	print("=== BotObservation honesty probe ===")
	var manager := BattleManager.new()
	manager.name = "BattleManager"
	manager.shadow_mode = true
	add_child(manager)

	# Viewer team includes toph so the reveal cap is testable in both states.
	var p1 := _build_player("BotPlayer", ["toph", "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["hisoka", "eren", "misaka"])
	manager.start_battle(p1, p2, true, 12345, BattleManager.MatchType.BOT)

	var viewer_obs := BotObservation.for_player(manager, p1)
	var enemy_obs := BotObservation.for_player(manager, p2)

	var hisoka = p2.team.characters[0]
	var phys_pair := _find_ability(p2.team, true)
	var nonphys_pair := _find_ability(p2.team, false)
	var phys_src = phys_pair[1]
	var nonphys_holder = nonphys_pair[0]
	var nonphys_src = nonphys_pair[1]
	_check(phys_src != null and nonphys_src != null,
		"test setup: enemy team has both a Physical and a non-Physical ability")

	var ctx = QueryContext.from_game_state(hisoka, manager)
	var nonphys_ctx = QueryContext.from_game_state(nonphys_holder, manager)

	# --- 1. Invisible NON-Physical enemy effect: hidden from the viewer even
	#        with Toph present; visible to its caster's own side.
	var hidden_mark = Effect.mark(-1, "probe: invisible non-physical")
	hidden_mark.set_source(nonphys_src)
	hidden_mark.invisible = true
	Character.add_allied_effect(nonphys_ctx, nonphys_holder, hisoka, hidden_mark)
	_check(not viewer_obs.visible_effects(hisoka).has(hidden_mark),
		"invisible non-Physical enemy effect is HIDDEN from the opponent (Toph can't sense it)")
	_check(enemy_obs.visible_effects(hisoka).has(hidden_mark),
		"the caster's own side SEES its invisible effect")

	# --- 2. Invisible PHYSICAL enemy effect: Toph alive on the viewer team
	#        senses it; with Toph dead it goes dark again.
	var phys_mark = Effect.mark(-1, "probe: invisible physical")
	phys_mark.set_source(phys_src)
	phys_mark.invisible = true
	Character.add_allied_effect(ctx, hisoka, hisoka, phys_mark)
	_check(viewer_obs.visible_effects(hisoka).has(phys_mark),
		"living Toph on the viewer team senses an invisible Physical enemy effect")
	var toph = p1.team.characters[0]
	toph.dead = true
	var obs_toph_dead := BotObservation.for_player(manager, p1)
	_check(not obs_toph_dead.visible_effects(hisoka).has(phys_mark),
		"dead Toph senses nothing (client rule: alive + unbanished)")
	toph.dead = false

	# --- 3. System effects are invisible to everyone, including their own side.
	var sys_mark = Effect.mark(-1, "probe: system bookkeeping")
	sys_mark.set_source(nonphys_src)
	sys_mark.system = true
	Character.add_allied_effect(nonphys_ctx, nonphys_holder, hisoka, sys_mark)
	_check(not viewer_obs.visible_effects(hisoka).has(sys_mark),
		"system effect hidden from the opponent")
	_check(not enemy_obs.visible_effects(hisoka).has(sys_mark),
		"system effect hidden even from its own side (never rendered)")

	# --- 4. A VISIBLE enemy effect shows for both sides.
	var open_mark = Effect.mark(-1, "probe: visible")
	open_mark.set_source(nonphys_src)
	Character.add_allied_effect(nonphys_ctx, nonphys_holder, hisoka, open_mark)
	_check(viewer_obs.visible_effects(hisoka).has(open_mark),
		"ordinary visible enemy effect is shown to the opponent")

	# --- 5. Enemy kit surface: inspect-panel fields only — structurally
	#        impossible to read live cooldowns / usable / targets.
	var kit = viewer_obs.enemy_kit(hisoka)
	_check(kit.size() > 0, "enemy kit is inspectable")
	var kit_keys_ok := true
	for entry in kit:
		for key in entry.keys():
			if not key in ["ability_name", "cost", "base_cooldown", "damage_hint"]:
				kit_keys_ok = false
	_check(kit_keys_ok, "enemy kit exposes ONLY ability_name/cost/base_cooldown/damage_hint")

	# --- 6. Own action surface works: fresh character has usable candidates
	#        with legal targets, and target flags are restored after probing.
	var naruto = p1.team.characters[1]
	var flags_before: Array = []
	for c in manager.all_characters():
		flags_before.append(c.targeted)
	var cands = viewer_obs.own_candidates(naruto)
	var flags_after: Array = []
	for c in manager.all_characters():
		flags_after.append(c.targeted)
	_check(cands.size() > 0, "own character has usable candidates")
	var has_targets := cands.size() > 0
	for cand in cands:
		if cand["targets"].is_empty():
			has_targets = false
	_check(has_targets, "every candidate carries a non-empty legal target list")
	_check(flags_before == flags_after, "target probing restores all targeted flags")

	# --- 7. Energy: own pool readable; the API has no enemy-pool accessor.
	var pool = viewer_obs.own_energy()
	_check(pool is Dictionary and pool.size() == 4, "own energy pool readable (4 colors)")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
