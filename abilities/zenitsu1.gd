extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Permanently, 'First Form: Thunderclap and Flash' and 'Thunder Release' will deal 5 additional damage. Until the next time it is used, First Form: Thunderclap and Flash will make Zenitsu invulnerable to non-Strategic skills for 1 turn and this skill cannot be used."

func split_desc():
	return [
		["Permanently, First Form: Thunderclap and Flash and Thunder Release deal 5 additional damage", Color.CADET_BLUE],
		["Until next used, First Form: Thunderclap and Flash makes Zenitsu invulnerable to non-Strategic skills for 1 turn", Color.CADET_BLUE],
		["Cannot be used until next triggered", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var damage_mod = Effect.damage_mod_effect(5, -1, ["First Form: Thunderclap and Flash", "Thunder Release"])
	damage_mod.set_source(self)
	damage_mod.display_stacks = true
	damage_mod.stackable = true
	damage_mod.stack_mag = true
	var mark = Effect.trigger_effect(Trigger.always(speed_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "First Form: Thunderclap and Flash will make Zenitsu invulnerable to non-Strategic skills for 1 turn.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, damage_mod)
	

func speed_trigger(context):
	if context['source'].ability_name == "First Form: Thunderclap and Flash":
		var invuln = Effect.invuln_effect(2, [], ["Strategic"])
		invuln.set_source(context['source'])
		Character.add_allied_effect(context, context['owner'], context['owner'], invuln)
		context['owner'].effects.remove_effect("Speed of Thunder", EffectType.Type.ACTION_USE_TRIGGER, context['owner'])

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 75)
	
	return variations

func extra_usable(user):
	return user.effects.has_effect("Speed of Thunder", EffectType.Type.ACTION_USE_TRIGGER, user) == null
	
func target(user, battle):
	default_self_target_function(user, battle)
