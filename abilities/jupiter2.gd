extends Ability

var base_damage = 15

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Shatters all enemies and deals 15 damage to them for 2 turns",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var shatter_eff = Effect.def_negate(3)
		shatter_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, shatter_eff)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3, false)
		damage_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 80)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
