extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "At the end of each turn, Tanjiro's first three skills may change to their alternate versions."

func split_desc():
	return [
		["At the end of each turn, each of Tanjiro's first three skills may swap to its alternate version", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger_eff = Effect.trigger_effect(Trigger.always(passive_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Tanjiro's first three skills may swap to their alternate versions.")
	trigger_eff.set_source(self)
	Character.add_allied_effect(context, user, user, trigger_eff)

func passive_trigger(context):
	var user = context['owner']
	var battle = context['battle']
	var skill_one = battle.roll(0, 1)
	var skill_two = battle.roll(0, 1)
	var skill_three = battle.roll(0, 1)
	
	var has_one_swap = Condition.has_effect(user, "Tenth Form: Constant Flux", EffectType.Type.ABILITY_SWAP, user)
	var has_two_swap = Condition.has_effect(user, "Sixth Form: Whirlpool", EffectType.Type.ABILITY_SWAP, user)
	var has_three_swap = Condition.has_effect(user, "Eighth Form: Waterfall Basin", EffectType.Type.ABILITY_SWAP, user)
	
	if skill_one == 0:
		if has_one_swap.satisfied(context):
			user.effects.remove_effect("Tenth Form: Constant Flux", EffectType.Type.ABILITY_SWAP, user)
	else:
		if not has_one_swap.satisfied(context):
			var swap = Effect.ability_swap_effect(4, 0, user, -1)
			swap.set_source(user.moveset.base_abilities[4])
			Character.add_allied_effect(context, user, user, swap)
	
	
	if skill_two == 0:
		if has_two_swap.satisfied(context):
			user.effects.remove_effect("Sixth Form: Whirlpool", EffectType.Type.ABILITY_SWAP, user)
	else:
		if not has_two_swap.satisfied(context):
			var swap = Effect.ability_swap_effect(5, 1, user, -1)
			swap.set_source(user.moveset.base_abilities[5])
			Character.add_allied_effect(context, user, user, swap)
	
	
	if skill_three == 0:
		if has_three_swap.satisfied(context):
			user.effects.remove_effect("Eighth Form: Waterfall Basin", EffectType.Type.ABILITY_SWAP, user)
	else:
		if not has_three_swap.satisfied(context):
			var swap = Effect.ability_swap_effect(6, 2, user, -1)
			swap.set_source(user.moveset.base_abilities[6])
			Character.add_allied_effect(context, user, user, swap)
	
			
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	pass
