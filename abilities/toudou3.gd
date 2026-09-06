extends Ability

var base_damage = 20

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 20 damage to target enemy and increases the Cooldown of their skills by 2 for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var nukiashi = user.marked_by("Nukiashi")
	
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
		var cd_mod = Effect.cooldown_mod(2, 2)
		cd_mod.set_source(self)
		if nukiashi:
			cd_mod.invisible = true
			cd_mod.wrapup_func = default_counter_timeout
		Character.add_hostile_effect(context, user, target, cd_mod)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 40)

func target(user, battle):
	default_hostile_target_function(user, battle)
