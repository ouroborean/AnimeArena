extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Noelle gains 10 damage reduction for 3 turns. During this time, Sea Dragon's Cradle will last two additional turns and no longer be consumed by Sea Dragon's Roar. If used while Sea Dragon's Cradle is active, extends its duration by two turns. Swaps to Point-Blank Sea Dragon's Roar."

func split_desc():
	return [
		"Noelle gains 10 Damage Reduction for 3 turns",
		["While active, Sea Dragon's Cradle lasts 2 more turns and is no longer consumed by Sea Dragon's Roar", Color.CADET_BLUE],
		["Extends any active Sea Dragon's Cradle by 2 turns", Color.CADET_BLUE],
		["Swaps to Point-Blank Sea Dragon's Roar", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dr = Effect.damage_reduction_effect(10, 6)
	dr.set_source(self)
	var mark = Effect.mark(5, "Sea Dragon's Cradle will last two additional turns and will not be consumed by Sea Dragon's Roar.")
	mark.set_source(self)
	var swap_eff = Effect.ability_swap_effect(4, 2, user, 5)
	swap_eff.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, dr)
	Character.add_allied_effect(context, user, user, swap_eff)
	
	var active_cradles = []
	for character in battle.all_characters():
		var cradles = character.effects.get_all_effects_by_name("Sea Dragon's Cradle", user)
		active_cradles += cradles
	for cradle in active_cradles:
		cradle.duration += 4

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 50)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
