extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Until Nobara dies or this skill is re-used, one enemy is permanently Isolated. Additionally, Resonance's stuns last 3 turns on an enemy affected by this skill."

func split_desc():
	return [
		"Permanently Isolates target enemy until Nobara dies or this skill is reused",
		["Resonance's stuns last 3 turns on the affected enemy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if character.has_effect("Straw Doll Technique", EffectType.Type.MARK, user):
			character.effects.full_remove_effect_by_name("Straw Doll Technique", user)
	
	for target in user.targeter.targets:
		user.manually_advance_mission(8, 1)
		var isolate = Effect.isolate(-1)
		isolate.set_source(self)
		var mark = Effect.mark(-1, "If Nobara uses Straw Doll Technique, this effect will end.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, isolate)
		Character.add_hostile_effect(context, user, target, mark)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
