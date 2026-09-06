extends Ability

var protection_duration = 6
var redirect_amount = 0.5

func describe(user):
	return "For 2 turns, another ally takes 50% reduced damage and the remainder is redirected to Halibel. The first time the protected ally is attacked, Halibel gains a permanent stack of Aspect of Sacrifice (+5 damage on Ola Blast / Cascada and Ola Azul / Hirviendo)."

func split_desc():
	return [
		"For 3 turns, half of all damage taken by another ally is redirected to Halibel",
		["The first time the protected ally is attacked, Halibel gains a permanent stack of Aspect of Sacrifice.", Color.CADET_BLUE],
		["Aspect of Sacrifice grants +5 damage on Halibel's offensive skills (stacks)", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:


		var redirect = Effect.redirect_effect(redirect_amount, user, protection_duration)
		redirect.set_source(self)
		Character.add_allied_effect(context, user, target, redirect)

		var watcher = Effect.trigger_effect(
			Trigger.always(on_ally_attacked),
			EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
			protection_duration,
			"The first time this ally is attacked, Halibel gains a stack of Aspect of Sacrifice.")
		watcher.set_source(self)
		Character.add_allied_effect(context, user, target, watcher)

func on_ally_attacked(context):
	var halibel = context['effect'].user
	if halibel.dead or halibel.banished:
		return
	var stack = Effect.damage_mod_effect(5, -1, ["Ola Azul", "Cascada", "Ola Blast", "Hirviendo"])
	stack.set_source(self)
	stack.stackable = true
	stack.display_stacks = true
	stack.stack_mag = true
	stack.description = "+5 damage on Halibel's offensive skills per stack."
	Character.add_allied_effect(context, halibel, halibel, stack)
	context['target'].effects.consume_effect(context['effect'])

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_selfless_helpful(context, 30, 1.0)

func target(user, battle):
	default_allied_target_function(user, battle)
