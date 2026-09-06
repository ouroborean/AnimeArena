extends Ability

func describe(user):
	return "Power targets an enemy with a Bleed effect on them. A random ally of theirs receives Bleed damage next turn equal to every instance of Bleed on the targeted enemy."

func split_desc():
	return [
		"Targets an enemy affected by Bleed",
		["A random ally of theirs takes Bleed damage next turn equal to the total of every Bleed instance on the target", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Sum the PER-TURN magnitude of every Bleed instance on the target
		# (same accounting as GAHAHA! GUTS!). A fresh delayed Bleed is created
		# from the total rather than copying the source effects — copies of
		# bleeds expiring this same turn never joined the ticking order and
		# silently did nothing.
		var total = 0
		for e in target.effects.get_effects_by_type(EffectType.Type.DAMAGE):
			if e.damage_type == DamageType.Type.BLEED:
				total += int(e.mag)
		if total <= 0:
			continue
		var candidates = []
		for ally in target.team.characters:
			if ally == target or ally.dead or ally.banished:
				continue
			candidates.append(ally)
		if candidates.is_empty():
			continue
		var pick = candidates[battle.roll(0, candidates.size() - 1, "Bloodshed Target")]
		var bleed = Effect.damage_effect(total, DamageType.Type.BLEED, 3)
		bleed.set_source(self)
		bleed.last_turn_only = true
		Character.add_hostile_effect(context, user, pick, bleed)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context)
	return variations

## Only enemies currently carrying a Bleed instance are legal targets.
func _is_bleeding(character) -> bool:
	for e in character.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if e.damage_type == DamageType.Type.BLEED:
			return true
	return false

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if _is_bleeding(character):
			check_hostile_target(user, character, context)
