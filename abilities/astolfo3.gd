extends Ability

const CASSEUR = "Casseur de Logistille"

func describe(user):
	return "Astolfo or target ally will ignore the next Harmful non-Physical skill they receive. This effect is permanent but cannot be used on a target already affected, and is Invisible until triggered."

func split_desc():
	return [
		"Astolfo or a target ally ignores the next Harmful non-Physical skill they receive",
		["Permanent and Invisible until it triggers; can't be re-applied while active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var ig = Effect.ignore_skill_effect(-1, ["Physical"])
		ig.set_source(self)
		Character.add_allied_effect(context, user, target, ig)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 35, 1.0)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for ally in user.team.characters:
		# "cannot be used on a target already affected" — skip allies who still hold the effect.
		if ally.has_effect(CASSEUR, EffectType.Type.IGNORE_SKILL, user):
			continue
		check_allied_target(user, ally, context)
