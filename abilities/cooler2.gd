extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 10 damage to target enemy for 3 turns. Each turn, this damage increases by 10."

func split_desc():
	return [
		"Deals 10 damage to target enemy, then 20 next turn, then 30 next turn",
		["In Final Form: deals 60 Energy damage instantly instead", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var in_final_form = user.has_effect("Cruel Transformation", EffectType.Type.MARK, user) != null

	for target in user.targeter.targets:
		if in_final_form:
			# Final Form collapses all three Supernova ticks (10+20+30) into a
			# single 60 Energy hit.
			Character.resolve_damage(context, target, 60, DamageType.Type.ENERGY)
		else:
			# eff.mag tracks the current tick value. supernova_tick increments
			# by 10 BEFORE dealing damage, so first tick = 10, second = 20,
			# third = 30.
			Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
			var dot_desc = func (eff):
				return "Supernova: next tick deals " + str(eff.mag + 10) + " Energy damage. Ramps by 10 each turn."
			var dot = Effect.trigger_effect(
				Trigger.always(supernova_tick),
				EffectType.Type.TICKING_TRIGGER,
				5,
				dot_desc
			)
			dot.set_source(self)
			dot.damage_type = DamageType.Type.ENERGY
			dot.mag = 10
			Character.add_hostile_effect(context, user, target, dot)

func supernova_tick(context):
	var eff = context['effect']
	eff.mag += 10
	Character.resolve_effect_damage(context, eff, context['target'], eff.mag, DamageType.Type.ENERGY)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
