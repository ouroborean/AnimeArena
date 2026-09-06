extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Stuns target enemy's Harmful skills for 1 turn",
		["If the stunned enemy uses a Helpful or Strategic skill, their Harmful skills will be stunned for 1 more turn", Color.CADET_BLUE],
		["Swaps to Crush Card Virus", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(2, ["Harmful"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		var trigger = Effect.trigger_effect(Trigger.always(use_trigger), EffectType.Type.ACTION_USE_TRIGGER, 2, "If this character uses a Helpful or Strategic skill, their Harmful skills will be stunned for 1 turn.")
		trigger.set_source(self)
		Character.add_hostile_effect(context, user, target, trigger)
	var abi_swap = Effect.ability_swap_effect(4, 2, user, -1)
	abi_swap.set_source(self)
	Character.add_allied_effect(context, user, user, abi_swap)
	

func use_trigger(context):
	if not (context.source.classes["Helpful"] or context.source.classes["Strategic"]):
		return
	var stun = Effect.stun_effect(3, ["Harmful"])
	stun.set_source(self)
	Character.add_hostile_effect(context, user, context.owner, stun)

	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 15)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
