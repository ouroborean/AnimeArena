extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Gogeta deals 35 damage to target enemy and reduces the remaining cooldown of all his skills by 1. For 2 turns, all of Gogeta's Blue costs turn to Random."

func split_desc():
	return [
		"Deals 35 damage to target enemy and reduces the remaining cooldown of Gogeta's skills by 1",
		"Gogeta's skills cost Random instead of Blue energy for 2 turns"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.has_effect("Bluff Kamehameha", EffectType.Type.COST_MOD):
		user.manually_advance_mission(10, 1)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 35, DamageType.Type.NORMAL)
	for skill in user.moveset.abilities:
		if skill.cooldown_remaining > 0:
			skill.cooldown_remaining -= 1
	var color_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.BLUE, 5, [])
	color_change.set_source(self)
	Character.add_allied_effect(context, user, user, color_change)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
