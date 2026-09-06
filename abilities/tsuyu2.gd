extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, Tsuyu becomes Invulnerable to non-Strategic skills",
		["If an enemy is affected by Tongue Lash, they take 15 damage and are stunned for 1 turn (Bypassing)", Color.ORANGE_RED],
		["If an ally is affected by Tongue Lash, they become Invulnerable for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var invuln = Effect.invuln_effect(2, [], ["Strategic"])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	for character in battle.all_characters():
		if character.marked_by("Tongue Lash", user):
			if character in user.team.characters:
				var ally_invuln = Effect.invuln_effect(2)
				ally_invuln.set_source(self)
				Character.add_allied_effect(context, user, character, ally_invuln)
			else:
				Character.resolve_damage(context, character, 15, DamageType.Type.NORMAL)
				var stun = Effect.stun_effect(2)
				stun.set_source(self)
				Character.add_hostile_effect(context, user, character, stun)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 15)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
