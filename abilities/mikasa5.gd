extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Destroys one enemy's Shield, deals 25 piercing damage to them, then stuns their strategic skills for 1 turn."

func split_desc():
	return [
		"Destroys target enemy's Shield",
		"Deals 25 piercing damage to them",
		"Stuns their Strategic skills for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		target.shatter_shields(user)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
		var stun_eff = Effect.stun_effect(3, ["Strategic"])
		stun_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, stun_eff)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 150)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
