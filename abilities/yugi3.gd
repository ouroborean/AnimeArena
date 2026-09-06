extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Stuns all characters' Harmful skills for 3 turns",
		["This Stun cannot be ignored", Color.DIM_GRAY],
		["Dark Magician and Dark Magician Girl ignore it", Color.CADET_BLUE],
		["Swaps to Dark Magician while active", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# A NON-ignorable STUN, not a skill_seal. ability_targets = ["Harmful"] stuns only Harmful skills;
		# exclusion_names keeps Dark Magician / Dark Magician Girl usable BY NAME (owner ruling Q7) - the
		# same exemption that lets Yugi end his own Swords, which also seals him. Because ignorable == false
		# it bypasses Unstunnable (both cards ARE Unstunnable), so ONLY the name exemption saves them; and
		# it registers with is_stunned, so it also pauses Action skills and breaks channel / control
		# skills through the one uniform gate. dur 6 == 3 turns, unchanged from the seal it replaces.
		var stun = Effect.stun_effect(6, ["Harmful"])
		stun.exclusion_names = ["Dark Magician", "Dark Magician Girl"]
		stun.ignorable = false
		stun.remove_on_death = true   # parity with the old seal (removed on death) — stun_effect defaults this false
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
	# 7, not 5: an ability swap of N turns is 2N+1, so the swap now covers the seal's full
	# 3 turns instead of reverting a turn early (owner ruling Q6).
	var swap = Effect.ability_swap_effect(4, 2, user, 7)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	
	user.call_unique("yugi", "check_card", ["swords"])
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 35)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
