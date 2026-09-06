extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 damage to one enemy. If Satsuki is at full health, the target's Harmful skills are stunned for 1 turn."

func split_desc():
	return [
		"Deals 25 damage to one enemy",
		["If Satsuki is at full health, stuns the target's Harmful skills for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		if user.health.hp >= 100:
			var stun = Effect.stun_effect(2, ["Harmful"])
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
		
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var superiority_mod = 0
	if user.health.hp >= 100:
		superiority_mod += 50
	variations += behavior_single_target_damage(context, 35 + superiority_mod)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
