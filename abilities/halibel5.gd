extends Ability

var release_threshold = 59
var release_dr = 10

func describe(user):
	return "The first time Halibel's HP falls below 60, she releases her Resurrección. Ola Blast becomes Cascada (AoE), Ola Azul becomes Hirviendo (Piercing + boiling water DOT), Halibel permanently gains 10 damage reduction, and she immediately gains a stack of Aspect of Sacrifice."

func split_desc():
	return [
		"The first time Halibel falls below 60 HP, her Resurrección is released:",
		["Ola Blast is permanently replaced with Cascada.", Color.AQUA],
		["Ola Azul is permanently replaced with Hirviendo.", Color.AQUA],
		["Halibel gains 10 permanent damage reduction.", Color.CADET_BLUE],
		["Halibel gains 1 stack of Aspect of Sacrifice.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var release_trigger = Effect.trigger_effect(
		Trigger.from_condition(Condition.health_is(user, -1, release_threshold), release_callback),
		EffectType.Type.HEALTH_CHANGE_TRIGGER,
		-1,
		"The first time Halibel falls below 60 HP, she will release her Resurrección.")
	release_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, release_trigger)

func release_callback(context):
	var halibel = context['owner']
	if halibel.dead or halibel.banished:
		return

	var swap1 = Effect.ability_swap_effect(5, 0, halibel, -1)
	swap1.set_source(self)
	Character.add_allied_effect(context, halibel, halibel, swap1)

	var swap2 = Effect.ability_swap_effect(6, 1, halibel, -1)
	swap2.set_source(self)
	Character.add_allied_effect(context, halibel, halibel, swap2)

	var dr = Effect.damage_reduction_effect(release_dr, -1)
	dr.set_source(self)
	dr.cleansable = false
	Character.add_allied_effect(context, halibel, halibel, dr)

	var stack = Effect.damage_mod_effect(5, -1, ["Ola Blast", "Ola Azul", "Cascada", "Hirviendo"])
	var aspect_source = self
	for ability in halibel.moveset.base_abilities:
		if ability.ability_name == "Aspect of Sacrifice":
			aspect_source = ability
			break
	stack.set_source(aspect_source)
	stack.stackable = true
	stack.display_stacks = true
	stack.stack_mag = true
	stack.description = "+5 damage on Halibel's offensive skills per stack."
	Character.add_allied_effect(context, halibel, halibel, stack)

	var portrait_swap = Effect.portrait_change_effect(0, -1)
	portrait_swap.set_source(self)
	Character.add_allied_effect(context, user, user, portrait_swap)

	halibel.effects.consume_effect(context['effect'])

func extra_usable(user):
	return true

func custom_behavior(context):
	return [[0, [user, "PASS", []]]]

func target(user, battle):
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
