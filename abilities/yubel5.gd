extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "For the rest of the game, any damage Yubel takes from enemy skills is reflected to the enemy team. Requires 5 stacks of Terror Incarnate to be used."

func split_desc():
	return [
		"Requires 6+ stacks of Terror Incarnate",
		["For the rest of the game, damage Yubel takes is reflected to the enemy team", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	user.effects.full_remove_effect_by_name("Terror Incarnate", user)

	var marker_desc = func (eff):
		return "Damage Yubel takes from enemy skills is reflected to the enemy team."
	var marker = Effect.trigger_effect(Trigger.always(trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, marker_desc)
	marker.set_source(self)
	Character.add_allied_effect(context, user, user, marker)

func trigger(context):
	pass

func extra_usable(user):
	var stacks = 0
	var mark = user.has_effect("Terror Incarnate", EffectType.Type.MARK, user)
	if mark:
		stacks = mark.stack_count()
	return stacks >= 6

func custom_behavior(context):
	var variations = []
	variations.append([300, [user, self, [context['owner']]]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
