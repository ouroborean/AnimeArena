extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 4 turns, if Toga has 3 or more Twisted Love stacks, Killing Spree deals 15 more damage. If she has 4 or more Twisted Love stacks, her skills cost 1 less Random energy. If she has 5 or more, Twisted Love is replaced by Drop Dead for the duration."

func split_desc():
	return [
		["For 4 turns, with 3+ Twisted Love stacks: Killing Spree deals 15 more damage", Color.CADET_BLUE],
		["With 4+ Twisted Love stacks: skills cost 1 less Random energy", Color.CADET_BLUE],
		["With 5+ Twisted Love stacks: Twisted Love is replaced by Drop Dead for the duration", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stacks = 0
	if user.marked_by("Twisted Love", user):
		stacks = user.effects.has_effect("Twisted Love", EffectType.Type.MARK, user).stack_count()
	
	if stacks >= 3:
		var damage_mod = Effect.damage_mod_effect(15, 9, ["Killing Spree"])
		damage_mod.set_source(self)
		Character.add_allied_effect(context, user, user, damage_mod)
	if stacks >= 4:
		var cost_mod = Effect.cost_mod_effect(-1, 9, Energy.Type.RANDOM)
		cost_mod.set_source(self)
		Character.add_allied_effect(context, user, user, cost_mod)
	if stacks >= 5:
		var swap = Effect.ability_swap_effect(5, 3, user, 9)
		swap.set_source(self)
		Character.add_allied_effect(context, user, user, swap)
	user.manually_advance_mission(7, min(stacks / 2, 6))
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
