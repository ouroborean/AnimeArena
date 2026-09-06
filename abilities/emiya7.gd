extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.



func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""



func split_desc():
	return [
		"At the start of the game, Emiya's skills are replaced by Trace, On!",
		["Whenever an enemy uses a new Harmful skill, a random one of Emiya's Trace, On! or True Projection skills will be automatically used", Color.CADET_BLUE],
		["Once Trace On! has been used 4 times, it is permanently replaced by True Projection", Color.DIM_GRAY]
	]



func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for i in range(4):
		var copy = Effect.copy_effect(user.moveset.abilities[0], i, -1, user)
		copy.system = true
		copy.set_source(self)
		copy.cleansable = false
		Character.add_allied_effect(context, user, user, copy)
	for target in context['enemy_team'].characters:
		var on_harm = Effect.trigger_effect(Trigger.always(on_harm_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, -1, "")
		on_harm.set_source(self)
		on_harm.system = true
		on_harm.waiting = false
		Character.add_hostile_effect(context, user, target, on_harm)
	var on_use = Effect.trigger_effect(Trigger.always(on_use_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "If Shirou uses or activates Trace, On! 4 times, it will permanently be replaced by True Projection.")
	on_use.set_source(self)
	on_use.display_mag = true
	Character.add_allied_effect(context, user, user, on_use)

func on_use_trigger(context):
	if context['source'].ability_name == "Trace, On!":
		user.manually_advance_mission(6, 1)
		var tracker = user.has_effect("Unlimited Blade Works", EffectType.Type.ACTION_USE_TRIGGER)
		tracker.mag += 1
		if tracker.mag >= 4:
			for effect in user.effects.get_effects_by_type(EffectType.Type.SKILL_COPY):
				if effect.source.ability_name == "Trace, On!":
					user.effects.erase_effect(effect)
			tracker.display_mag = false
			tracker.description = func (eff): return "Trace, On! has been replaced by True Projection."
			for i in range(4):
				var copy = Effect.copy_effect(user.moveset.abilities[1], i, -1, user)
				copy.system = true
				copy.set_source(self)
				copy.cleansable = false
				Character.add_allied_effect(context, user, user, copy)

func on_harm_trigger(context):
	var skills = []
	for skill in user.moveset.get_active_abilities(user):
		if skill.ability_name == "Trace, On!" or skill.ability_name == "True Projection":
			skills.append(skill)
	if len(skills) <= 0:
		return
	var roll = user.battle.roll(0, len(skills) - 1)
	var used_skill = skills[roll]
	if used_skill.ability_name == "Trace, On!":
		user.manually_advance_mission(6, 1)
		var shield = Effect.shield_effect(5, -1)
		shield.set_source(used_skill)
		Character.add_allied_effect(context, user, user, shield)
		var trace_roll = user.battle.roll(2, 5)
		var copy = Effect.copy_effect(user.moveset.abilities[trace_roll], user.moveset.get_active_abilities(user).find(used_skill), 2, user)
		copy.unique_render_id = int(Time.get_ticks_msec())
		copy.set_source(used_skill)
		copy.cleansable = false
		Character.add_allied_effect(context, user, user, copy)
		var tracker = user.has_effect("Unlimited Blade Works", EffectType.Type.ACTION_USE_TRIGGER)
		if not tracker:
			return
		tracker.mag += 1
		if tracker.mag >= 4:
			for effect in user.effects.get_effects_by_type(EffectType.Type.SKILL_COPY):
				if effect.source.ability_name == "Trace, On!":
					user.effects.erase_effect(effect)
			tracker.display_mag = false
			tracker.description = func (eff): return "Trace, On! has been replaced by True Projection."
			for i in range(4):
				var true_copy = Effect.copy_effect(user.moveset.abilities[1], i, -1, user)
				true_copy.system = true
				true_copy.set_source(self)
				true_copy.cleansable = false
				Character.add_allied_effect(context, user, user, true_copy)
	else:
		var tracker = user.has_effect("Unlimited Blade Works", EffectType.Type.ACTION_USE_TRIGGER)
		if tracker == null:
			return
		var copied_skills = tracker.ability_targets
		var true_roll = user.battle.roll(2, 5 + len(copied_skills))
		var target_skill
		if true_roll <= 5:
			target_skill = user.moveset.abilities[true_roll]
		else:
			true_roll -= 6
			target_skill = copied_skills[true_roll]
		var copy = Effect.copy_effect(target_skill, user.moveset.get_active_abilities(user).find(used_skill), 2, user)
		copy.unique_render_id = int(Time.get_ticks_msec())
		copy.set_source(used_skill)
		copy.cleansable = false
		Character.add_allied_effect(context, user, user, copy)

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
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
