extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Kuroko deals 20 damage to one enemy and becomes invulnerable for one turn. If used on the turn after Needle Pin, this ability will have no cooldown. If used on the turn after Judgement Throw, this ability will deal 15 extra damage."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		"Kuroko becomes invulnerable for 1 turn",
		["+15 damage if used the turn after Judgement Throw", Color.CADET_BLUE],
		["No cooldown if used the turn after Needle Pin", Color.CADET_BLUE],
		["Afterward, Judgement Throw stuns its target for 1 turn and Needle Pin Bypasses and deals 20 piercing damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mod_damage = base_damage
		if user.marked_by("Judgement Throw", user):
			mod_damage += 15
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.NORMAL)
	if user.marked_by("Needle Pin", user):
		cooldown_remaining = 0
	var mark = Effect.mark(3, "Judgement Throw will stun its target for 1 turn and Needle Pin will Bypass and deal 20 piercing damage to its target.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations	
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
