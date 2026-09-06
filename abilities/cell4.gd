extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Cell heals 15 HP for 1 turn. This skill lasts an additional turn for each 15 HP Cell is missing."

func split_desc():
	return [
		"Cell heals 15 HP",
		["Lasts 1 more turn per 15 HP Cell is missing when used", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var max_hp = user.get_modified_max_hp()
	var missing = max_hp - user.health.hp
	var extra_turns = int(missing / 15)
	# Each turn in this engine is roughly two duration ticks; using the same
	# "2N - 1" convention as kurotsuchi3 / marco5 healing DOTs.
	var duration = 1 + (2 * (extra_turns))
	Character.resolve_healing(context, user, 15)
	if duration > 1:
		var heal = Effect.healing_effect(15, duration)
		heal.set_source(self)
		Character.add_allied_effect(context, user, user, heal)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 30)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
