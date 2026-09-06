extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to all enemies for 4 turns",
		["Costs 1 less Random energy for each stack of Black Abyss on Tokoyami", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var mag = 0
	if user.has_effect("Black Abyss", EffectType.Type.MARK):
		mag = user.has_effect("Black Abyss", EffectType.Type.MARK).mag
	if mag == 3:
		user.manually_advance_mission(8, 1)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var damage = Effect.damage_effect(10, DamageType.Type.NORMAL, 7)
		damage.set_source(self)
		Character.add_hostile_effect(context, user, target, damage)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
