extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Saber or the target of her Avalon become invulnerable for 1 turn. This skill always costs the same energy as Wind Blade Combat."

func split_desc():
	return [
		["Saber or the target of her Avalon becomes invulnerable for 1 turn", Color.CADET_BLUE],
		["Always costs the same energy as Wind Blade Combat", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var invuln = Effect.invuln_effect(2)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, target, invuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	var user = context['owner']
	var allies = context['owner'].team.characters
	for ally in allies:
		if ally.has_effect("Avalon", EffectType.Type.HEALING, user):
			variations.append([75, [user, self, [ally]]])
	if len(variations) == 0:
		variations += behavior_self_panic_button(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	for character in battle.all_characters():
		if character == user or character.has_effect("Avalon", EffectType.Type.HEALING, user):
			check_allied_target(user, character, QueryContext.from_game_state(user, battle))
