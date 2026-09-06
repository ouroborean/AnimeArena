extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 damage and 0 Affliction damage to target enemy."

func split_desc():
	return ["Deals 15 damage and 0 Affliction damage to target enemy", "Affliction damage dealt is increased by Ace's total Damage Reduction"]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var dr_effects = user.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)
	var base_aff = 0
	for dr in dr_effects:
		base_aff += dr.mag
		user.manually_advance_mission(7, dr.mag)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		Character.resolve_damage(context, target, base_aff, DamageType.Type.AFFLICTION)
	
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
