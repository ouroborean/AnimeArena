extends Ability

var base_damage = 20
var counter_damage = 10

func describe(user):
	return "Deals 20 damage to target enemy for 2 turns. During this time, if they use a new Harmful skill, that skill will be countered, they will take 10 damage, and this skill will end."

func split_desc():
	return [
		"Deals 20 damage to target enemy for 2 turns",
		["If they use a new Harmful skill: it is countered, they take 10 damage, and this skill ends", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var beam = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3)
		beam.set_source(self)
		Character.add_hostile_effect(context, user, target, beam)

		var trap = Effect.counter_effect(
			Trigger.always(eraser_counter),
			EffectType.Type.COUNTER_USE,
			3,
			"If this character uses a new Harmful skill, it is countered, they take 10 damage, and Eraser Cannon ends.",
			["Harmful"]
		)
		trap.set_source(self)
		Character.add_hostile_effect(context, user, target, trap)

func eraser_counter(context):
	var struck = context['owner']
	if struck != null and not (struck.dead or struck.banished):
		Character.resolve_effect_damage(context, context['effect'], struck, counter_damage, DamageType.Type.NORMAL)
		struck.effects.remove_effect("Eraser Cannon", EffectType.Type.DAMAGE, context['effect'].user)
	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 45)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
