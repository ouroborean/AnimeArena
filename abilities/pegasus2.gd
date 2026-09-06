extends Ability

var base_shield = 30

func describe(user):
	return "For 1 turn, if target enemy uses a Harmful skill, they will be countered and Pegasus will gain 30 Shield. As long as Pegasus has this Shield, this skill and the countered skill are unusable."

func split_desc():
	return [
		"For 1 turn, the next Harmful skill used by target enemy will be countered",
		"On counter, Pegasus gains 30 Shield",
		"While Pegasus carries this Shield, this skill and the countered skill cannot be used"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter = Effect.counter_effect(Trigger.always(relinquished_trigger), EffectType.Type.COUNTER_USE, 2, "If this character uses a new Harmful skill, they will be countered.", ["Harmful"])
		counter.wrapup_func = default_counter_timeout
		counter.invisible = true
		counter.set_source(self)
		Character.add_hostile_effect(context, user, target, counter)

func relinquished_trigger(context):
	var countered = context['owner']
	var countered_skill = countered.used_ability

	var shield = Effect.shield_effect(base_shield, -1)
	shield.set_source(self)

	if countered_skill != null:
		var skill_lock = Effect.mark(-1, "This character cannot use " + countered_skill.ability_name + " while Pegasus carries the Relinquished Shield.")
		skill_lock.ability_targets = [countered_skill.ability_name]
		skill_lock.set_source(self)
		Character.add_hostile_effect(context, user, countered, skill_lock)
		shield.character_target = countered
		shield.wrapup_func = relinquished_shield_broken

	Character.add_allied_effect(context, user, user, shield)

	default_counter_trigger(context)

func relinquished_shield_broken(context):
	var pegasus = context['effect'].user
	var locked_target = context['effect'].character_target
	if locked_target:
		locked_target.effects.full_remove_effect_by_name("Relinquished", pegasus)

func extra_usable(user):
	if user.has_effect("Relinquished", EffectType.Type.SHIELD, user):
		return false
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
