extends Ability
var base_damage = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Jack deals 5 affliction damage to all enemies for 3 turns. During this time, they will receive 50% reduced healing. This skill cannot be countered."

func split_desc():
	return [
		"Deals 5 Affliction damage to all enemies each turn for 3 turns",
		["Affected enemies receive 50% reduced healing", Color.ORANGE_RED],
		["Cannot be countered", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)
		var aff = Effect.damage_effect(base_damage, DamageType.Type.AFFLICTION, 5)
		aff.set_source(self)
		var mark = Effect.mark(5, "Jack can target this character as though they were Isolated.")
		mark.set_source(self)
		var heal_cut = Effect.heal_cut(50, 6)
		heal_cut.set_source(self)
		Character.add_hostile_effect(context, user, target, aff)
		Character.add_hostile_effect(context, user, target, heal_cut)
		Character.add_hostile_effect(context, user, target, mark)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 75)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
