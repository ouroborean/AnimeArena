extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 25 damage to target enemy and executes them if their HP falls to 10 or less",
		["Next turn, Brutal Kick will execute its target if their HP falls to 10 or less", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 25, DamageType.Type.NORMAL)
		target.execute_attempt(10, user, self)
		if user.marked_by("Brutal Kick"):
			var weakness = Effect.damage_mod_effect(-10, 2, [], [], [DamageType.Type.AFFLICTION])
			weakness.set_source(self)
			Character.add_hostile_effect(context, user, target, weakness)
	var mark = Effect.mark(3, "Brutal Kick will execute its target if their HP falls to 10 or less.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
