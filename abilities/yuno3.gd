extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, Yuno gains 1 blue energy per turn and gains 10 damage reduction. Replaces Wind Blades Shower with Gale White Bow, Towering Torando with Sylph's Breath, and this skill with Spirit of Zephyr while active."

func split_desc():
	return [
		["For 3 turns, Yuno gains 1 blue energy per turn and 10 damage reduction", Color.CADET_BLUE],
		["Swaps Wind Blades Shower with Gale White Bow", Color.AQUA],
		["Swaps Towering Tornado with Sylph's Breath", Color.AQUA],
		["Swaps with Spirit of Zephyr while active", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.gain_bonus_energy(Energy.Type.BLUE)
	user.effects.remove_effect("Wind Blades Shower", EffectType.Type.COST_MOD, user)
	
	
	var energy_trigger = Effect.trigger_effect(Trigger.always(sylph_energy_trigger), EffectType.Type.TICKING_TRIGGER, 5, "Yuno will gain 1 Blue energy.")
	energy_trigger.set_source(self)
	var dr = Effect.damage_reduction_effect(10, 6)
	dr.set_source(self)
	var swap1 = Effect.ability_swap_effect(4, 0, user, 5)
	swap1.set_source(self)
	var swap2 = Effect.ability_swap_effect(5, 1, user, 5)
	swap2.set_source(self)
	var swap3 = Effect.ability_swap_effect(6, 2, user, 5)
	swap3.set_source(self)
	
	Character.add_allied_effect(context, user, user, energy_trigger)
	Character.add_allied_effect(context, user, user, dr)
	Character.add_allied_effect(context, user, user, swap1)
	Character.add_allied_effect(context, user, user, swap2)
	Character.add_allied_effect(context, user, user, swap3)
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 85)
	
	return variations

func sylph_energy_trigger(context):
	context['owner'].gain_bonus_energy(Energy.Type.BLUE)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
