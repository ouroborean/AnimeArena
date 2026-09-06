extends Ability

var base_damage = 40

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 40 piercing damage to one enemy and stuns their non-mental skills for 1 turn."

func split_desc():
	return [
		"Deals 40 piercing damage to target enemy",
		"Stuns their non-Mental skills for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mod_damage = get_true_damage(user, target, base_damage)
		if not target.is_ignoring_damage(true):
			context.battle.log_damage(user, target, mod_damage, DamageType.Type.PIERCING, user.used_ability)
			user.deal_ability_damage(user.used_ability, mod_damage, target, DamageType.Type.PIERCING)
		else:
			context.battle.log_invuln_block(user, target, user.used_ability)

		var stun_eff = Effect.stun_effect(2, [], ["Mental"])
		stun_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, stun_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
