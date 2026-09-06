extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Another character at or below 20 HP is executed and Neferpitou gains 1 stack of Puppeteering",
		["At the end of each turn, Neferpitou deals 10 Piercing damage to a random enemy for each stack of Puppeteering on them", Color.ORANGE_RED],
		["This skill can target dead characters", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if not target.dead:
			target.execute_attempt(20, user, self)
			
		if not user.has_effect("Puppeteering", EffectType.Type.TICKING_TRIGGER):
			var potential_targets = []
			for enemy in context['enemy_team'].characters:
				if not (enemy.dead or enemy.banished or enemy.is_invuln(self)):
					potential_targets.append(enemy)
			
			if potential_targets.size() > 0:
				var roll = battle.roll(0, potential_targets.size() - 1)
				var chosen_enemy = potential_targets[roll]
				Character.resolve_damage(context, chosen_enemy, 10, DamageType.Type.PIERCING)
			
		var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Neferpitou will deal 10 Piercing damage to a random enemy, repeating for each stack.")
		ticking.set_source(self)
		ticking.damage_type = DamageType.Type.PIERCING
		ticking.stackable = true
		ticking.stacks = 1
		ticking.display_stacks = true
		user.manually_advance_mission(10, 1)
		Character.add_allied_effect(context, user, user, ticking)
	
		
		
func tick_trigger(context):
	for i in range(context.effect.stacks):
		var potential_targets = []
		for enemy in context['enemy_team'].characters:
			if not (enemy.dead or enemy.banished or enemy.is_invuln(self)):
				potential_targets.append(enemy)
		
		if potential_targets.size() > 0:
			var roll = context.battle.roll(0, potential_targets.size() - 1)
			var chosen_enemy = potential_targets[roll]
			Character.resolve_effect_damage(context, context.effect, chosen_enemy, 10, DamageType.Type.PIERCING)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	for character in battle.all_characters():
		if character.dead and not character.banished:
			character.set_targeted()
		elif not (character.dead or character.banished):
			if character.health.hp <= 20:
				character.set_targeted()
