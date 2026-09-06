extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 damage to target enemy. If that enemy is marked by Four Scythe Child, the mark is consumed to Shatter them for 1 turn."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["If marked by Four Scythe Child, consumes the mark to Shatter them for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var mark = target.marked_by("Four Scythe Child", user)
		if mark:
			# Shatter the target for 1 turn
			var shatter = Effect.def_negate(2)
			shatter.set_source(self)
			Character.add_hostile_effect(context, user, target, shatter)
			# Consume mark unless Doji Manifestation is active
			if not user.marked_by("Doji Manifestation", user):
				target.effects.consume_effect(mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			var mod = 0
			if character.marked_by("Four Scythe Child", context['owner']):
				mod += 75
			variations.append([100 + mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
