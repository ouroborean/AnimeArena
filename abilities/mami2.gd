extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mami isolates target enemy for 1 turn and stuns their Harmful skills. If Mami Soul Gem has at least 3 stacks, this skill swaps to Tiro Finale for 1 turn."

func split_desc():
	return [
		"Isolates target enemy for 1 turn and stuns their Harmful skills",
		["Swaps to Tiro Finale for 1 turn if Mami: Soul Gem has at least 3 stacks", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var isolate = Effect.isolate(2)
		isolate.set_source(self)
		var stun = Effect.stun_effect(2, ["Harmful"])
		stun.set_source(self)
		var mark = Effect.mark(3, "This character can be targeted by Tiro Finale.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, isolate)
		Character.add_hostile_effect(context, user, target, stun)
		Character.add_hostile_effect(context, user, target, mark)
		
	if user.effects.has_effect("Soul Gem: Mami", EffectType.Type.MARK, user):
		if user.effects.has_effect("Soul Gem: Mami", EffectType.Type.MARK, user).mag >= 2:
			var swap = Effect.ability_swap_effect(4, 1, user, 3)
			swap.set_source(self)
			Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
