extends Ability

var base_shield = 25
var bonus_shield = 10

func describe(user):
	return "Android 17 gains 25 Shield for 2 turns. Grants 10 more Shield and lasts 1 more turn for each random energy this skill costs."

func split_desc():
	return [
		"Android 17 gains 25 Shield for 2 turns",
		["+10 Shield and +1 turn for each random energy this skill costs", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var surge = cost()[Energy.Type.RANDOM]
	var barrier = Effect.shield_effect(base_shield + (bonus_shield * surge), 4 + (2 * surge))
	barrier.set_source(self)
	Character.add_allied_effect(context, user, user, barrier)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 20)

func target(user, battle):
	default_self_target_function(user, battle)
