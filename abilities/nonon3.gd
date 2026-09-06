extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Nonon deals 10 damage to one enemy for 3 turns. If the target is affected by Overture Barrage, this skill Bypasses. Becomes Unstoppable Performance while active."

func split_desc():
	return [
		"Deals 10 damage to target enemy each turn for 3 turns",
		["Bypasses Invulnerability if the target is affected by Overture Barrage", Color.CADET_BLUE],
		["The target is auto-targeted by Unstoppable Performance", Color.ORANGE_RED],
		["Becomes Unstoppable Performance while active", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var cancels = []
	
	for target in user.targeter.targets:
		
		var bypassing = false
		if target.marked_by("Overture Barrage", user):
			bypassing = true
		
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 5)
		damage_eff.set_source(self)
		var mark = Effect.mark(5, "This character will be automatically targeted by Unstoppable Performance.")
		mark.set_source(self)
		cancels.append(damage_eff)
		cancels.append(mark)
		Character.add_hostile_effect(context, user, target, mark, bypassing)
		Character.add_hostile_effect(context, user, target, damage_eff, bypassing)
	var swap = Effect.ability_swap_effect(4, 2, user, 5)
	swap.set_source(self)
	cancels.append(swap)
	var cancel_eff = Effect.control_cancel(5, "Concentrated Climax", cancels)
	cancel_eff.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	Character.add_allied_effect(context, user, user, cancel_eff)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		var bypassing = false
		if character.marked_by("Overture Barrage", user):
			bypassing = true
		check_hostile_target(user, character, context, bypassing)
