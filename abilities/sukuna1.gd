extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sukuna targets all other characters for 4 turns, executing them if their HP falls to 5 or less. This threshold increases by 5 each turn, and whenever a selected character uses a skill on Sukuna. During this time, Cleave and Dismantle damages random enemies 2 additional times."

func split_desc():
	return [
		"Executes any other character with 5 or less HP at the end of each turn",
		"This threshold increases by 5 each turn",
		"Can only be used once"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var ticking = Effect.trigger_effect(Trigger.always(shrine_trigger), EffectType.Type.TICKING_TRIGGER, -1, "")
	ticking.set_source(self)
	ticking.description = func (eff): return "Sukuna will execute any other character with " + str(eff.mag) + " or less HP."
	ticking.display_mag = true
	ticking.mag = 5
	var mark = Effect.mark(-1, "Sukuna can use Fire Arrow and Cleave and Dismantle.")
	mark.set_source(self)
	mark.cleansable = false
	Character.add_allied_effect(context, user, user, ticking)
	Character.add_allied_effect(context, user, user, mark)
	for target in user.targeter.targets:
		if target == user:
			continue
		target.execute_attempt(5, user, self)
	if user.marked_by("Sealed King"):
		var seal = user.has_effect("Sealed King", EffectType.Type.MARK)
		user.effects.erase_effect(seal)

func shrine_trigger(context):
	var shrine = context['effect']
	shrine.mag += 5
	for character in user.battle.all_characters():
		if not character == user:
			character.execute_attempt(shrine.mag, user, self)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Malevolent Shrine")
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 150)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
