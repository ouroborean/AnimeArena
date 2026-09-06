extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 4 turns, all enemies take 5 Affliction damage",
		["Blinds Strategic skills", Color.ORANGE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 5, DamageType.Type.AFFLICTION)
		var damage_eff = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 7)
		damage_eff.set_source(self)
		var blind_eff = Effect.blind_effect(8, ["Strategic"])
		blind_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, blind_eff)
		Character.add_hostile_effect(context, user, target, damage_eff)

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
