extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Until the end of his next turn, Gray ignores stun effects and can use his skills. During this time, this skill is replaced by Ice, Make Unlimited. If Ice, Make Unlimited is already active, this skill is replaced by One-Sided Chaotic Dance."

func split_desc():
	return [
		"Gray ignores stun effects and can use his skills until the end of his next turn",
		["Replaced by Ice, Make Unlimited during this time", Color.AQUA],
		["Replaced by One-Sided Chaotic Dance instead if Ice, Make Unlimited is already active", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stun_ign = Effect.ignore_effect_effect(3, EffectType.Type.STUN)
	stun_ign.set_source(self)
	var mark = Effect.mark(3, "Gray can use his skills.")
	mark.set_source(self)
	var counter = Effect.damage_mod_effect(10, -1, ["One-Sided Chaotic Dance"])
	counter.set_source(self)
	counter.stackable=true
	counter.display_stacks = true
	counter.per_stack = true
	Character.add_allied_effect(context, user, user, stun_ign)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, counter)
	
	if user.has_effect("Ice, Make Unlimited", EffectType.Type.MARK, user):
		var abi_swap = Effect.ability_swap_effect(7, 0, user, 3)
		abi_swap.set_source(self)
		Character.add_allied_effect(context, user, user, abi_swap)
	else:
		var abi_swap = Effect.ability_swap_effect(5, 0, user, 3)
		abi_swap.set_source(self)
		Character.add_allied_effect(context, user, user, abi_swap)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations.append([300, [user, self, [user]]])
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
