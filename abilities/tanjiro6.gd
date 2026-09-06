extends Ability

var base_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 2 turns, Tanjiro deals 10 damage to all enemies while making his team invulnerable against Energy skills. Swaps with Third Form: Flowing Dance."

func split_desc():
	return [
		"Deals 10 damage to all enemies for 2 turns",
		["Tanjiro's team is invulnerable to Energy skills for 2 turns", Color.CADET_BLUE],
		["Swaps with Third Form: Flowing Dance", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var cancels = []
	for target in user.targeter.targets:
		var hostile = Condition.is_hostile(user, target)
		if hostile.satisfied(context):
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
			var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3)
			damage_eff.set_source(self)
			cancels.append(damage_eff)
			Character.add_hostile_effect(context, user, target, damage_eff)
		else:
			var invuln_eff = Effect.invuln_effect(4, ["Energy"])
			invuln_eff.set_source(self)
			cancels.append(invuln_eff)
			Character.add_allied_effect(context, user, target, invuln_eff)
	var cancel_eff = Effect.control_cancel(3, ability_name, cancels)
	cancel_eff.set_source(self)
	Character.add_allied_effect(context, user, user, cancel_eff)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
