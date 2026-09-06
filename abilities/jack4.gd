extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Jack deals 15 damage to target enemy and becomes Invulnerable for one turn. If this targets an Isolated enemy or an enemy affected by Fog of London, its cooldown is reduced by 2. Both of these effects can occur."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		"Jack becomes invulnerable for 1 turn",
		["Cooldown reduced by 2 if the target is Isolated", Color.CADET_BLUE],
		["Cooldown reduced by 2 if the target is affected by Fog of London (stacks with the above)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var isolated = false
	var fogged = false
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		if target.is_isolated():
			isolated = true
		if target.marked_by("Fog of London", user):
			user.manually_advance_mission(7, 1)
			fogged = true
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	if isolated:
		cooldown_remaining -= 2
	if fogged:
		cooldown_remaining -= 2
	if cooldown_remaining < 0:
		cooldown_remaining = 0
	

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
