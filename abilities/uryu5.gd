extends Ability

var base_damage = 35
var damage_inc = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 35 piercing damage to one enemy, increased by 5 for each Quincy Energy Uryuu has. This skill uses up all Quincy Energy. Bypasses."

func split_desc():
	return [
		"Deals 35 piercing damage to one enemy, +5 per Quincy Energy Uryuu has, ignoring invulnerability",
		["Uses up all Quincy Energy", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var energy_count = user.effects.has_effect("Spirit Particle Subjugation", EffectType.Type.MARK, user).mag
	
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + (damage_inc * energy_count), DamageType.Type.PIERCING)
	
	user.spend_quincy_energy(energy_count)
		
func extra_usable(user):
	var context = QueryContext.from_game_state(user, user.battle)
	
	var has_energy = Condition.mag_is(user, "Spirit Particle Subjugation", EffectType.Type.MARK, user, 1)
	return has_energy.satisfied(context)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 25, 1.2, true)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
