extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 Piercing damage to the enemy team for 3 turns. While active, can be used for no cost to deal 5 Piercing damage and apply 15 points of Nullify to a single enemy until Rose Barrage ends."

func split_desc():
	return [
		"Deals 10 Piercing damage to all enemies each turn for 3 turns",
		["While active, can be used for free to deal 5 Piercing damage and apply 15 Nullify to one enemy until Rose Barrage ends", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var barraging = Condition.has_effect(user, "Rose Barrage", EffectType.Type.MARK, user)
	var cancels = []
	
	for target in user.targeter.targets:
		if not barraging.satisfied(context):
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
			var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, 10)
			damage_eff.set_source(self)
			cancels.append(damage_eff)
			Character.add_hostile_effect(context, user, target, damage_eff)
		else:
			var duration_remaining = user.has_effect("Rose Barrage", EffectType.Type.MARK, user).duration
			var barrier_eff = Effect.barrier_effect(15, duration_remaining)
			barrier_eff.set_source(self)
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
			Character.add_hostile_effect(context, user, target, barrier_eff)
	if not barraging.satisfied(context):
		var mark_eff = Effect.mark(5, "Rose Barrage can be used to give its target 15 Nullify.")
		mark_eff.set_source(self)
		cancels.append(mark_eff)
		var cost_change_eff = Effect.cost_change_effect({}, 5, ["Rose Barrage"])
		cost_change_eff.set_source(self)
		cancels.append(cost_change_eff)
		var target_change = Effect.target_change_effect(TargetType.Type.SINGLE, 5, ["Rose Barrage"])
		target_change.set_source(self)
		cancels.append(target_change)
		var cancel_effect = Effect.control_cancel(5, "Rose Barrage", cancels)
		cancel_effect.set_source(self)
		
		Character.add_allied_effect(context, user, user, mark_eff)
		Character.add_allied_effect(context, user, user, cost_change_eff)
		Character.add_allied_effect(context, user, user, target_change)
		Character.add_allied_effect(context, user, user, cancel_effect)


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	if user.has_effect("Rose Barrage", EffectType.Type.MARK, user):
		variations += behavior_single_target_damage(context, 50, 0.7)
	else:
		variations += behavior_hostile_aoe_damage(context, 50)
	
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var barraging = Condition.has_effect(user, "Rose Barrage", EffectType.Type.MARK, user)
	if barraging.satisfied(context):
		for character in battle.all_characters():
			var barraged = Condition.has_effect(character, "Rose Barrage", EffectType.Type.DAMAGE, user)
			if barraged.satisfied(context):
				check_hostile_target(user, character, context)
	else:
		#There are 3 default targeting functions, but if there are unique requirements, just put them here
		default_hostile_target_function(user, battle)
