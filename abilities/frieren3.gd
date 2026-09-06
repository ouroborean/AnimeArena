extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For the following turn, Frieren gains 1 White energy, 10 Damage Reduction, and her skills are empowered.",
		["Swaps Flower Field and Mana Release for Vollzanbel and Judradjim", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark = Effect.mark(3, "Frieren has released her mana, empowering her skills.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	var dr = Effect.damage_reduction_effect(10, 2)
	dr.set_source(self)
	Character.add_allied_effect(context, user, user, dr)
	var swap1 = Effect.ability_swap_effect(5, 1, user, 3)
	var swap2 = Effect.ability_swap_effect(6, 2, user, 3)
	var cost_change1 = Effect.cost_change_effect({Energy.Type.WHITE: 1}, 3, ["Zoltraak"])
	cost_change1.set_source(self)
	var cost_change2 = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 3, ["Flight Evasion"])
	cost_change2.set_source(self)
	cost_change1.system = true
	cost_change2.system = true
	swap1.set_source(self)
	swap2.set_source(self)
	swap1.system = true
	swap2.system = true
	Character.add_allied_effect(context, user, user, swap1)
	Character.add_allied_effect(context, user, user, swap2)
	Character.add_allied_effect(context, user, user, cost_change1)
	Character.add_allied_effect(context, user, user, cost_change2)

	user.gain_bonus_energy(Energy.Type.WHITE)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 105)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
