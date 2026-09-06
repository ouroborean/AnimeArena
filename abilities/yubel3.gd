extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "If Yubel has 2 or more stacks of Terror Incarnate, she permanently reflects all damage she takes from enemy skills back to the user. Swaps to Ultimate Nightmare when used."

func split_desc():
	return [
		"Requires 3+ stacks of Terror Incarnate",
		["Permanently reflects damage Yubel takes back to the attacker", Color.CADET_BLUE],
		["Swaps to Ultimate Nightmare", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var marker_desc = func (eff):
		return "Yubel is reflecting damage she takes from enemy skills back to the attacker."
	var marker = Effect.trigger_effect(Trigger.always(trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, marker_desc)
	marker.set_source(self)
	Character.add_allied_effect(context, user, user, marker)

	var swap = Effect.ability_swap_effect(4, 2, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func trigger(context):
	return

func extra_usable(user):
	var stacks = 0
	var mark = user.has_effect("Terror Incarnate", EffectType.Type.MARK, user)
	if mark:
		stacks = mark.stack_count()
	return stacks >= 3

func custom_behavior(context):
	var variations = []
	variations.append([200, [user, self, [context['owner']]]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
