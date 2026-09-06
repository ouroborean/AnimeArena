extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Stuns all other characters for 2 turns",
		["This Stun cannot be ignored", Color.DIM_GRAY],
		["After this effect ends, Esdeath is Stunned for 2 turns", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# A NON-ignorable STUN, not a skill_seal. ignorable == false makes it bypass every stun escape
		# hatch (the Unstunnable class, shrug_off_type(STUN), Clear Heart Clothing, Gunha's Guts veto) —
		# which is what "cannot be ignored" means — and, unlike the old seal, it registers with
		# is_stunned, so the SAME gate that skips a stunned turn also pauses Action skills and breaks
		# channel / control skills. Empty filters stun EVERY skill. dur 4 == 2 turns, unchanged.
		var stun = Effect.stun_effect(4)
		stun.ignorable = false
		stun.remove_on_death = true   # parity with the old seal (owner ruling: removed on death) — stun_effect defaults this false
		stun.set_source(self)
		stun.wrapup_func = timeout_trigger
		Character.add_hostile_effect(context, user, target, stun)


func timeout_trigger(context):
	# Esdeath takes the same prevention she dealt (owner ruling Q9) - also a non-ignorable STUN. The guard
	# keeps the recoil to ONE application no matter how many targets' stuns expire on the same turn; it
	# probes STUN now (the recoil is a STUN too), or every expiry would re-apply the penalty.
	if not user.has_effect("Mahapadma", EffectType.Type.STUN, user):
		var stun = Effect.stun_effect(4)
		stun.ignorable = false
		stun.remove_on_death = true
		stun.set_source(self)
		Character.add_allied_effect(context, user, user, stun)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 10)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
