extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sukuna is permanently stunned, untargetable, and he permanently marks a random ally at the beginning of the game, increasing their non-Affliction damage by 5. Each game, the first time the marked ally's HP falls below 70/30, Sukuna will disable Sealed King on himself and apply it to his ally for 3 turns. If the marked ally dies, Sukuna permanently disables Sealed King."

func split_desc():
	return [
		"Sukuna is permanently Untargetable",
		"This effect ends if Malevolent Shrine is used or both of his teammates die"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(-1, "Sukuna is permanently untargetable. This effect will end if both his teammates die or he uses Malevolent Shrine.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, user, user, mark)
	for ally in user.team.characters:
		var trigger = Effect.trigger_effect(Trigger.always(death_trigger), EffectType.Type.ON_DEATH_TRIGGER, -1, "")
		trigger.set_source(self)
		trigger.system = true
		Character.add_allied_effect(context, user, ally, trigger)
	death_trigger(context)

func death_trigger(context):
	if user.has_targetable_living_ally():
		return
	var mark = user.has_effect("Sealed King", EffectType.Type.MARK)
	if mark:
		user.effects.erase_effect(mark)
		
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
