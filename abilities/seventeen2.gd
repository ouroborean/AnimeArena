extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 Piercing damage to target enemy (Bypasses). Affects another random target for each random energy this skill costs."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy",
		"Bypasses Invulnerability",
		["Hits another random enemy for each random energy this skill costs", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var extra_hits = cost()[Energy.Type.RANDOM]
	var struck = []
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		struck.append(target)

	var pool = []
	for character in battle.all_characters():
		if user.is_hostile(character) and not (character.dead or character.banished) and not character in struck:
			pool.append(character)
	for i in range(extra_hits):
		if pool.is_empty():
			break
		var idx = battle.roll(0, len(pool) - 1)
		var extra = pool[idx]
		pool.remove_at(idx)
		Character.resolve_damage(context, extra, base_damage, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 50, 1.0, true)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, true)
