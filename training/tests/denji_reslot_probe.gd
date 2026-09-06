extends Node

# ============================================================================
# Probe for the Denji reslot + Reckless Charge bleed + Bloodshed redesign.
#
#  1. Denji's kit order: S1 Rip and Tear, S2 Reckless Charge, S3 Devil
#     Transformation (locked slots gate on the transform mark).
#  2. Devil Transformation swaps ITS OWN slot (2) to Ripcord Pull.
#  3. Reckless Charge: 20 now + 20 next turn + ONE continuous 10 Bleed that
#     ticks on the target's following two turns (total 60 over the window).
#  4. Bloodshed: sums per-turn Bleed instances on the target — INCLUDING one
#     expiring this very turn (the old copy approach lost it) — and deals the
#     total to a random living ally next turn as a fresh delayed Bleed.
#  5. Bloodshed targeting: only bleeding enemies are legal.
#
# Run:  godot --headless --path <repo> res://training/tests/denji_reslot_probe.tscn
# Exit code = failures (0 = pass).
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


## Execute `ability` from `character` at `primary` (engine idiom from
## _contextual_bot_act steps 5/6/8, minus energy).
func _cast(manager, character, ability, primary):
	character.targeter.targets = [primary]
	character.targeter.main_target = primary
	character.used_ability = ability
	ability.target(character, manager)
	for c in manager.all_characters():
		c.set_untargeted()
	manager.execute_ability(ability)
	character.used_ability = null


## End the acting side's turn with no actions: queue its ticking entries and
## run the round loop (the perform_turn_v3 scaffold) — DoTs resolve exactly as
## they would in a live match. DoT ticks run on the CASTER's side's turns and
## the ticking queue is built at turn START (battle_manager.gd:777-838).
func _pass_turn(manager, player_obj):
	var ticking = manager.get_ticking_effect_information(manager.waiting_for_turn)
	for key in ticking.keys():
		manager.execution_order[key] = ticking[key]
		manager.true_execution_order.append(key)
	for c in player_obj.team.characters:
		if not (c.dead or c.banished):
			c.bot_acted = true
	manager.start_round_loop()


## End the turn a probe CAST happened in WITHOUT gathering ticking entries:
## live matches build the ticking queue before any cast executes, so an effect
## applied this turn must not tick this same turn (gathering here was the
## probe artifact that produced a phantom extra tick).
func _end_cast_turn(manager, player_obj):
	for c in player_obj.team.characters:
		if not (c.dead or c.banished):
			c.bot_acted = true
	manager.start_round_loop()


func _bleeds_on(character) -> Array:
	var out := []
	for e in character.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if e.damage_type == DamageType.Type.BLEED:
			out.append(e)
	return out


func _ready():
	print("=== Denji reslot / Reckless / Bloodshed probe ===")
	var manager := BattleManager.new()
	manager.name = "BattleManager"
	manager.shadow_mode = true
	add_child(manager)
	var p1 := _build_player("BotPlayer", ["denji", "power", "naruto"])
	var p2 := _build_player("BotEnemy", ["zoro", "hisoka", "misaka"])
	manager.start_battle(p1, p2, true, 777, BattleManager.MatchType.BOT)

	var denji = p1.team.characters[0]
	var power = p1.team.characters[1]
	var zoro = p2.team.characters[0]
	var hisoka = p2.team.characters[1]

	# --- 1. Kit order + transform gating ---
	var kit = denji.moveset.get_active_abilities(denji)
	_check(kit[0].ability_name == "Rip and Tear", "S1 is Rip and Tear (got %s)" % kit[0].ability_name)
	_check(kit[1].ability_name == "Reckless Charge", "S2 is Reckless Charge (got %s)" % kit[1].ability_name)
	_check(kit[2].ability_name == "Devil Transformation", "S3 is Devil Transformation (got %s)" % kit[2].ability_name)
	_check(not kit[0].extra_usable(denji), "S1 locked before transforming")
	_check(not kit[1].extra_usable(denji), "S2 locked before transforming")
	_check(kit[2].extra_usable(denji), "S3 (Devil Transformation) usable before transforming")

	# --- 2. Transform swaps slot 2 to Ripcord Pull ---
	_cast(manager, denji, kit[2], denji)
	var kit2 = denji.moveset.get_active_abilities(denji)
	_check(kit2[2].ability_name == "Ripcord Pull", "after transform, S3 becomes Ripcord Pull (got %s)" % kit2[2].ability_name)
	_check(kit2[0].ability_name == "Rip and Tear" and kit2[0].extra_usable(denji), "S1 unlocked after transform")
	_check(kit2[1].extra_usable(denji), "S2 unlocked after transform")

	# --- 3. Reckless Charge: immediate 20 + effects shape ---
	var hp0 = zoro.health.hp
	_cast(manager, denji, kit2[1], zoro)
	_check(zoro.health.hp == hp0 - 20, "Reckless Charge hits 20 immediately (hp %d -> %d)" % [hp0, zoro.health.hp])
	var zbleeds = _bleeds_on(zoro)
	_check(zbleeds.size() == 1, "exactly ONE Bleed instance applied (got %d)" % zbleeds.size())
	if zbleeds.size() == 1:
		_check(int(zbleeds[0].mag) == 10 and not zbleeds[0].last_turn_only,
			"the Bleed is a continuous 10/turn (mag %d, lto %s)" % [int(zbleeds[0].mag), zbleeds[0].last_turn_only])

	# --- 4. Tick the window (DoTs run on DENJI's turns): 20+10 next turn,
	#        10 the turn after, then nothing ---
	var hp1 = zoro.health.hp
	_end_cast_turn(manager, p1)   # end the cast turn (queue was pre-cast = empty)
	_pass_turn(manager, p2)
	_pass_turn(manager, p1)       # Denji's next turn: NORMAL DoT 20 + Bleed 10
	var after_first = hp1 - zoro.health.hp
	_check(after_first == 30, "next turn: 20 DoT + 10 Bleed (took %d)" % after_first)
	var hp2 = zoro.health.hp
	_pass_turn(manager, p2)
	_pass_turn(manager, p1)       # turn after: Bleed 10 only
	var after_second = hp2 - zoro.health.hp
	_check(after_second == 10, "turn after: 10 Bleed only (took %d)" % after_second)
	var hp3 = zoro.health.hp
	_pass_turn(manager, p2)
	_pass_turn(manager, p1)       # window over: nothing
	_check(hp3 - zoro.health.hp == 0, "window ends: no further damage (took %d)" % [hp3 - zoro.health.hp])

	# Realign: section 4 left p2 acting; Bloodshed must be cast during POWER's
	# own turn (its delayed Bleed is timed for a self-turn cast, like live play).
	_pass_turn(manager, p2)

	# --- 5. Bloodshed targeting: no bleeding enemy -> no legal targets ---
	var power_kit = power.moveset.get_active_abilities(power)
	var bloodshed = power_kit[3]
	_check(bloodshed.ability_name == "Bloodshed", "power slot 3 is Bloodshed (got %s)" % bloodshed.ability_name)
	for c in manager.all_characters():
		c.set_untargeted()
	bloodshed.target(power, manager)
	var targeted_none := 0
	for c in manager.all_characters():
		if c.targeted:
			targeted_none += 1
	for c in manager.all_characters():
		c.set_untargeted()
	_check(targeted_none == 0, "no bleeding enemies -> Bloodshed has no targets (got %d)" % targeted_none)

	# --- 6. Bloodshed: sums instances INCLUDING one expiring this turn ---
	var pctx = QueryContext.from_game_state(power, manager)
	var dying = Effect.damage_effect(10, DamageType.Type.BLEED, 1)   # expires this very turn
	dying.set_source(bloodshed)
	Character.add_hostile_effect(pctx, power, hisoka, dying)
	var living_bleed = Effect.damage_effect(15, DamageType.Type.BLEED, 5)
	living_bleed.set_source(bloodshed)
	Character.add_hostile_effect(pctx, power, hisoka, living_bleed)

	bloodshed.target(power, manager)
	var hisoka_targetable = hisoka.targeted
	var zoro_targetable = zoro.targeted
	for c in manager.all_characters():
		c.set_untargeted()
	_check(hisoka_targetable, "bleeding hisoka IS targetable")
	_check(not zoro_targetable, "bleed-free zoro is NOT targetable")

	_cast(manager, power, bloodshed, hisoka)
	var recipient = null
	for ally in [zoro, p2.team.characters[2]]:
		var got = _bleeds_on(ally)
		if got.size() > 0:
			recipient = ally
			_check(got.size() == 1 and int(got[0].mag) == 25 and got[0].last_turn_only,
				"%s received ONE delayed Bleed of 25 (10 expiring + 15 live)" % ally.path_name)
	_check(recipient != null, "a random living ally of the target received the Bleed")

	# --- 7. The transferred Bleed lands on POWER's next turn (caster side) ---
	if recipient != null:
		var rhp = recipient.health.hp
		_end_cast_turn(manager, p1)   # end the Bloodshed cast turn
		_pass_turn(manager, p2)
		_pass_turn(manager, p1)       # Power's next turn: the 25 ticks
		_check(rhp - recipient.health.hp == 25,
			"transferred Bleed ticks 25 on the following turn (took %d)" % [rhp - recipient.health.hp])

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
