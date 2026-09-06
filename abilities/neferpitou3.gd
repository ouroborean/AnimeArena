extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Neferpitou gains 1 stack of Terpsichora and gains up to 10 Shield each turn for the rest of the game",
		["While active, Neferpitou can use this skill to deal 20 damage to target enemy and gain 1 Terpsichora stack", Color.CADET_BLUE],
		["+5 damage per Terpsichora stack", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if not user.has_effect("Terpsichora", EffectType.Type.TARGET_CHANGE):
			var target_change = Effect.target_change_effect(TargetType.Type.SINGLE, -1, ["Terpsichora"])
			target_change.set_source(self)
			Character.add_allied_effect(context, user, user, target_change)
			var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Neferpitou will gain up to 10 Shield.")
			ticking.set_source(self)
			Character.add_allied_effect(context, user, user, ticking)
			var shield = Effect.shield_effect(10, -1)
			shield.unique_render_id = 5
			shield.set_source(self)
			Character.add_allied_effect(context, user, user, shield)
			var damage_mod = Effect.damage_mod_effect(5, -1, ["Terpsichora"])
			damage_mod.set_source(self)
			damage_mod.stackable = true
			damage_mod.display_stacks = true
			damage_mod.stack_mag = true
			damage_mod.unique_render_id = 4
			Character.add_allied_effect(context, user, user, damage_mod)
			user.manually_advance_mission(10, 1)
		else:
			Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
			var damage_mod = Effect.damage_mod_effect(5, -1, ["Terpsichora"])
			damage_mod.set_source(self)
			damage_mod.stackable = true
			damage_mod.display_stacks = true
			damage_mod.stack_mag = true
			damage_mod.unique_render_id = 4
			Character.add_allied_effect(context, user, user, damage_mod)
			user.manually_advance_mission(10, 1)

func tick_trigger(context):
	var existing_shield = user.has_effect("Terpsichora", EffectType.Type.SHIELD)
	if existing_shield:
		existing_shield.mag = 10
	else:
		var shield = Effect.shield_effect(10, -1)
		shield.set_source(self)
		shield.unique_render_id = 5
		Character.add_allied_effect(context, user, user, shield)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	if user.has_effect("Terpsichora", EffectType.Type.TARGET_CHANGE):
		variations += behavior_single_target_damage(context, 25)
	else:
		variations += behavior_self_panic_button(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	if not user.has_effect("Terpsichora", EffectType.Type.TARGET_CHANGE):
		default_self_target_function(user, battle)
	else:
		default_hostile_target_function(user, battle)
