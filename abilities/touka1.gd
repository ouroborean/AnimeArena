extends Ability

var base_damage = 20
var base_boost = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to all enemies. Deals 5 additional damage to an enemy affected by 'Crystallized Shards'. This skill deals 20 additional damage and fully stuns for 1 turn during 'Crystallized Ukaku'."

func split_desc():
	return [
		"Deals 20 damage to all enemies, +5 to an enemy affected by 'Crystallized Shards'",
		["During 'Crystallized Ukaku': +20 damage and fully stuns for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var ukaku_active = Condition.has_effect(user, "Crystallized Ukaku", EffectType.Type.TARGET_CHANGE, user)
	
	
	for target in user.targeter.targets:
		var boost = 0
		var crystallizing = Condition.has_effect(target, "Crystallized Shards", EffectType.Type.MARK, user)
		
		if crystallizing.satisfied(context):
			boost = base_boost
		
		var mod_damage = base_boost + base_damage
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.NORMAL)
		
		if ukaku_active.satisfied(context):
			var stun_eff = Effect.stun_effect(2)
			stun_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, stun_eff)
		
func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	if target_type() == TargetType.Type.SINGLE:
		variations += behavior_single_target_damage(context, 35)
	else:
		variations += behavior_hostile_aoe_damage(context, 15)
	
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
