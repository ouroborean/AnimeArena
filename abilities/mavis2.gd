extends Ability


func describe(user):
	return "Another ally has their first skill replaced by Fairy Glitter for 2 turns."


func split_desc():
	return [
		"Another ally's first skill is replaced by Fairy Glitter for 2 turns",
	]


func execute(user, battle):
	var context = make_context(battle)
	var fairy_glitter = user.moveset.base_abilities[5]
	for target in user.targeter.targets:
		var copy = Effect.copy_effect(fairy_glitter, 0, 4, target)
		copy.set_source(self)
		Character.add_allied_effect(context, user, target, copy)


func extra_usable(user):
	return user.has_targetable_living_ally() and not user.marked_by("Fairy Heart")


func custom_behavior(context):
	var variations = []
	for ally in context['ally_team'].characters:
		if ally == context['owner']:
			continue
		if ally.dead or ally.banished:
			continue
		variations.append([90 + (100 - ally.health.hp) / 4, [context['owner'], self, [ally]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations


func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in user.team.characters:
		if character == user:
			continue
		check_allied_target(user, character, context)
