extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the rest of the game, Gray's team gains 5 Shield each turn, and the enemy team receives 5 piercing damage each turn."

func split_desc():
	return [
		["Gray's team gains 5 Shield each turn for the rest of the game", Color.CADET_BLUE],
		["The enemy team takes 5 piercing damage each turn for the rest of the game", Color.ORANGE_RED],
		["Ice, Make... is now replaced by One-Sided Chaotic Dance on use", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var cancels = []
	
	
	for target in user.targeter.targets:
		if target in context['enemy_team'].characters:
			Character.resolve_damage(context, target, 5, DamageType.Type.PIERCING)
			var damage_eff = Effect.damage_effect(5, DamageType.Type.PIERCING, -1)
			damage_eff.set_source(self)
			cancels.append(damage_eff)
			Character.add_hostile_effect(context, user, target, damage_eff)
		else:
			var shield_eff = Effect.shield_effect(5, -1)
			shield_eff.set_source(self)
			var ticking_trigger = Effect.trigger_effect(Trigger.always(shield_trigger), EffectType.Type.TICKING_TRIGGER, -1, "This character will receive 5 Shield.")
			ticking_trigger.set_source(self)
			
			cancels.append(shield_eff)
			cancels.append(ticking_trigger)
			Character.add_allied_effect(context, user, target, shield_eff)
			Character.add_allied_effect(context, user, target, ticking_trigger)
	var mark = Effect.mark(-1, "Ice, Make... will now be replaced by One-Sided Chaotic Dance on use.")
	mark.set_source(self)
	cancels.append(mark)
	var control_eff = Effect.control_cancel(-1, ability_name, cancels)
	control_eff.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, control_eff)
		
func shield_trigger(context):
	var shielded = context['target']
	var gray = context['owner']
	var shield_eff = Effect.shield_effect(5, -1)
	shield_eff.remove_on_death = false
	shield_eff.set_source(self)
	shield_eff.unique_render_id = 1
	Character.add_allied_effect(context, gray, shielded, shield_eff)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	var targets = []
	var mod = 0
	for character in context['battle'].all_characters():
		if character in context['enemy_team'].characters:
			if not character.is_invuln(self) and not (character.dead or character.banished):
				targets.append(character)
				mod += 35
		else:
			if not (character.dead or character.banished):
				targets.append(character)
				mod += 35
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([mod, [user, self, targets]])
	
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
