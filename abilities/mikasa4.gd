extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mikasa becomes invulnerable and stuns target enemy's non-Strategic skills until the end of Mikasa's next turn."

func split_desc():
	return [
		"Mikasa becomes invulnerable until the end of her next turn",
		"Stuns target enemy's non-Strategic skills until the end of Mikasa's next turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun_eff = Effect.stun_effect(2, [], ["Strategic"])
		stun_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, stun_eff)
	var invuln_eff = Effect.invuln_effect(2)
	invuln_eff.set_source(self)
	Character.add_allied_effect(context, user, user, invuln_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 100)
	
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
