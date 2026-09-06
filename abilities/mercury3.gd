extends Ability

var base_damage = 0

func describe(user):
	return ""

func split_desc():
	return [
		"For 1 turn, the first enemy to use a Harmful skill on Mercury will be countered and take 15 damage (Invisible)",
		["While Empowered, can target any ally", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		var counter = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "The first enemy to use a Harmful skill on this character will be countered and take 15 damage.")
		counter.set_source(self)
		counter.invisible = true
		counter.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, counter)

func counter_trigger(context):
	Character.resolve_effect_damage(context, context.effect, context.owner, 15, DamageType.Type.NORMAL)
	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	if user.marked_by("Shabon Spray"):
		var variations = []
		variations += behavior_single_target_helpful(context, 30)
		return variations
	else:
		return behavior_self_panic_button(context)

func target(user, battle):
	if user.marked_by("Shabon Spray"):
		default_allied_target_function(user, battle)
	else:
		default_self_target_function(user, battle)
