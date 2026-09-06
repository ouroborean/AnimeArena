extends Ability

var base_damage = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Touka gains 20 Shield, makes her skills single-target, and deals 5 damage to all enemies every turn for 2 turns."

func split_desc():
	return [
		"Deals 5 damage to all enemies every turn for 2 turns",
		["Touka gains 20 Shield", Color.CADET_BLUE],
		["Makes Touka's skills single-target", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var shield_eff = Effect.shield_effect(20, 4)
	shield_eff.set_source(self)
	
	var shard_target_eff = Effect.target_change_effect(TargetType.Type.SINGLE, 3, ["Crystallized Shards"])
	shard_target_eff.set_source(self)
	
	var slam_target_eff = Effect.target_change_effect(TargetType.Type.SINGLE, 3, ["Ukaku Slam"])
	slam_target_eff.set_source(self)
	
	var shard_damage_eff = Effect.damage_mod_effect(15, 3, ["Crystallized Shards"])
	shard_damage_eff.set_source(self)
	
	var slam_damage_eff = Effect.damage_mod_effect(20, 3, ["Ukaku Slam"])
	slam_damage_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, shield_eff)
	Character.add_allied_effect(context, user, user, shard_target_eff)
	Character.add_allied_effect(context, user, user, shard_damage_eff)
	Character.add_allied_effect(context, user, user, slam_target_eff)
	Character.add_allied_effect(context, user, user, slam_damage_eff)
	
	for target in user.targeter.targets:
		if target == user:
			continue
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, 5)
		damage_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_eff)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 30)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_self_target_function(user, battle)
