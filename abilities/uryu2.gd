extends Ability

var base_damage = 25

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 piercing damage to one enemy that ignores invulnerability. For 1 turn, 'Seele Schneider' costs 1 random energy and Uryuu becomes invulnerable to enemy non-strategic skills. Uses 1 Quincy Energy."

func split_desc():
	return [
		"Deals 25 piercing damage to one enemy, ignoring invulnerability",
		["Seele Schneider costs 1 random energy for 1 turn", Color.CADET_BLUE],
		["Uryuu becomes invulnerable to enemy non-strategic skills for 1 turn", Color.CADET_BLUE],
		["Uses 1 Quincy Energy", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
	var invuln_eff = Effect.invuln_effect(3, [], ["Strategic"])
	invuln_eff.set_source(self)
	
	var cost_change_eff = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 3, ["Seele Schneider"])
	cost_change_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, invuln_eff)
	Character.add_allied_effect(context, user, user, cost_change_eff)
	user.spend_quincy_energy(1)
		
func extra_usable(user):
	var context = QueryContext.from_game_state(user, user.battle)
	
	var has_energy = Condition.mag_is(user, "Spirit Particle Subjugation", EffectType.Type.MARK, user, 1)
	return has_energy.satisfied(context)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35, 1.0, true)
	
	return variations
	
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
