extends Ability

func describe(user):
	return "For 3 turns, all enemies deal 5 less damage. This effect is removed if an affected enemy uses a Harmful skill. While Empowered, is no longer removed when using Harmful skills."

func split_desc():
	return [
		"For 3 turns, all enemies deal 5 less damage",
		"This effect is removed if an affected enemy uses a Harmful skill",
		["While Empowered, the effect is no longer removed by Harmful skills", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.marked_by("Rokudo Takeover")
	var dur = 7

	for target in user.targeter.targets:
		var dmg_mod = Effect.damage_mod_effect(-5, dur)
		dmg_mod.set_source(self)
		Character.add_hostile_effect(context, user, target, dmg_mod)

		if not empowered:
			var trigger_desc = "Using a Harmful skill will remove the damage reduction from Illusion: Broken Ground."
			var trigger = Effect.trigger_effect(
				Trigger.always(broken_ground_remove),
				EffectType.Type.HARMFUL_USE_TRIGGER,
				dur,
				trigger_desc
			)
			trigger.set_source(self)
			Character.add_hostile_effect(context, user, target, trigger)

func broken_ground_remove(context):
	var enemy = context['target']
	enemy.effects.remove_effect("Illusion: Broken Ground", EffectType.Type.DAMAGE_MOD, user)
	enemy.effects.erase_effect(context['effect'])

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
