extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Meliodas becomes invulnerable for 1 turn."

func split_desc():
	return [
		"Deals 15 damage to all enemies and makes Meliodas Invulnerable to Physical skills for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
	var invuln = Effect.invuln_effect(2, ["Physical"])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Revenge Counter")

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 15)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
