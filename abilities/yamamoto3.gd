extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Consumes all stacks of Asari Ugetsu on use, and remains active for one turn plus one per stack consumed. While active, replaces Shinotsuku Ame with Scontro di Rondine and Utsuhi Ame with Beccata di Rondine, and Yamamoto gains 25 Shield."

func split_desc():
	return [
		["Consumes all stacks of Asari Ugetsu, active for 1 turn plus 1 per stack consumed", Color.CADET_BLUE],
		["Yamamoto gains 25 Shield", Color.CADET_BLUE],
		["Replaces Shinotsuku Ame with Scontro di Rondine", Color.AQUA],
		["Replaces Utsuhi Ame with Beccata di Rondine", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var asari = user.has_effect("Asari Ugetsu", EffectType.Type.MARK, user)
	var duration = 3
	if asari:
		duration = 3 + (asari.stacks * 2)
		asari.stacks = 0
	var swap1 = Effect.ability_swap_effect(4, 0, user, duration)
	swap1.set_source(self)
	var swap2 = Effect.ability_swap_effect(5, 1, user, duration)
	swap2.set_source(self)
	var shield = Effect.shield_effect(25, duration - 1)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	Character.add_allied_effect(context, user, user, swap1)
	Character.add_allied_effect(context, user, user, swap2)
	

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 15)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.effects.has_effect("Asari Ugetsu", EffectType.Type.ABILITY_SWAP, user) == null
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
