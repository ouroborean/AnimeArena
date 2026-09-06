extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Usopp Blinds target enemy for 3 turns, and a different random enemy for 1 turn. Will not randomly target an enemy already affected by Smoke Star. Bypassing."

func split_desc():
	return [
		["Blinds target enemy for 3 turns", Color.ORANGE_RED],
		["Blinds a different random enemy for 1 turn (not one already affected by Smoke Star)", Color.ORANGE_RED],
		["Bypassing", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var duration = 6
		
		if target.marked_by("Gunpowder Star", user):
			duration += (target.has_effect("Gunpowder Star", EffectType.Type.MARK, user).stacks * 2)
		
		var blind = Effect.blind_effect(duration)
		blind.unique_render_id = int(Time.get_ticks_msec())
		blind.set_source(self)
		Character.add_hostile_effect(context, user, target, blind, true)
	var potential_targets = []
	for enemy in context['enemy_team'].characters:
		if not (enemy.dead or enemy.banished) and not enemy.has_effect("Smoke Star", EffectType.Type.BLIND, user):
			potential_targets.append(enemy)
	
	if len(potential_targets) > 0:
		var roll = battle.roll(0, len(potential_targets) - 1)
		var chosen_enemy = potential_targets[roll]
		var duration = 3
		if chosen_enemy.marked_by("Gunpowder Star", user):
			duration += (chosen_enemy.has_effect("Gunpowder Star", EffectType.Type.MARK, user).stacks * 2)
		var blind = Effect.blind_effect(duration)
		blind.unique_render_id = 1
		blind.set_source(self)
		Character.add_hostile_effect(context, user, chosen_enemy, blind, true)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 75, true)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
