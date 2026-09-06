extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Kuroko deals 20 damage to one enemy and Silences them for one turn. If used on the turn after Teleporting Strike, this skill will stun its target for 1 turn. If used on the turn after Needle Pin, this skill will remove one energy from its target."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		"Silences them for 1 turn",
		["Also stuns the target for 1 turn if used the turn after Teleporting Strike", Color.CADET_BLUE],
		["Also removes 1 energy if used the turn after Needle Pin", Color.CADET_BLUE],
		["Afterward, Teleporting Strike deals 15 more damage and Needle Pin Isolates its target for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var silence = Effect.silence_effect(2)
		silence.set_source(self)
		Character.add_hostile_effect(context, user, target, silence)
		if user.marked_by("Teleporting Strike", user):
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
		if user.marked_by("Needle Pin", user):
			target.lose_energy(user, 1)
	var mark = Effect.mark(3, "Teleporting Strike will deal 15 more damage and Needle Pin will Isolate its target for 1 turn.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
