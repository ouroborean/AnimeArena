extends Ability

func describe(user):
	return ""

func split_desc():
	return [
		"Venus gains 1 stack of Venus Burning Love whenever she receives a Harmful skill. Each stack increases Venus's next skill's damage by 5 and is consumed on use",
		["Gains 2 stacks instead if the attacker is Taunted", Color.CADET_BLUE],
		["Consuming stacks heals Venus 10 HP, plus 5 per stack consumed", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = make_context(battle)
	var trigger = Effect.trigger_effect(Trigger.always(burning_love_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "Venus will gain stacks of Venus Burning Love when she receives a Harmful skill.")
	trigger.set_source(self)
	trigger.waiting = false
	Character.add_allied_effect(context, user, user, trigger)

func burning_love_trigger(context):
	var attacker = context['source'].user
	var stacks_to_add = 1
	if attacker.is_taunted():
		stacks_to_add = 2
	for i in range(stacks_to_add):
		var boost = Effect.damage_mod_effect(5, -1)
		boost.set_source(self)
		boost.stackable = true
		boost.stack_mag = true
		boost.display_stacks = true
		Character.add_allied_effect(context, user, user, boost)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	return false
