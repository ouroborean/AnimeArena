extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 piercing damage to the enemy team and stuns their non-strategic skills for 1 turn."

func split_desc():
	return [
		"Deals 20 piercing damage to all enemies",
		"Stuns their non-Strategic skills for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var stun = Effect.stun_effect(2, [], ["Strategic"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Slime Transformation", EffectType.Type.IGNORE_NON_DAMAGE, user) == null

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 10, 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
