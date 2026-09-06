extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Once 20 skills have been used in the battle, EMIYA's next Caladbolg Barrage deals 40 True damage to its target",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		var trigger = Effect.trigger_effect(Trigger.always(use_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "")
		trigger.set_source(self)
		trigger.system = true
		if character in user.team.characters:
			Character.add_allied_effect(context, user, character, trigger)
		else:
			Character.add_hostile_effect(context, user, character, trigger)
	var label = Effect.empty(-1, "Once 20 total skills have been used this battle, EMIYA's next Caladbolg Barrage deals 40 True damage to its target.")
	label.set_source(self)
	label.display_mag = true
	Character.add_allied_effect(context, user, user, label)

func use_trigger(context):
	if user.moveset.base_abilities[1].cooldown_remaining > 0:
		user.moveset.base_abilities[1].cooldown_remaining -= 1
	var label = user.has_effect("Grand Caladbolg", EffectType.Type.EMPTY)
	if not label:
		return
	label.mag += 1
	if label.mag >= 20:
		user.effects.erase_effect(label)
		var mark = Effect.mark(-1, "EMIYA's next Caladbolg Barrage will deal 40 True damage to its target.")
		mark.set_source(self)
		Character.add_allied_effect(context, user, user, mark)
	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
