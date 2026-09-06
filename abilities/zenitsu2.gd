extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Permanently, 'First Form: Thunderclap and Flash' and 'Thunder Release' will deal 5 additional damage. Until the next time it is used, First Form: Thunderclap and Flash will permanently make Zenitsu deal 0 piercing damage to any enemy that uses a new non-Strategic skill on him."

func split_desc():
	return [
		["Permanently, First Form: Thunderclap and Flash and Thunder Release deal 5 additional damage", Color.CADET_BLUE],
		["Until next used, First Form: Thunderclap and Flash makes Zenitsu permanently deal 0 piercing damage to any enemy that uses a new non-Strategic skill on him", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var damage_mod = Effect.damage_mod_effect(5, -1, ["First Form: Thunderclap and Flash", "Thunder Release"])
	damage_mod.set_source(self)
	damage_mod.stackable = true
	damage_mod.display_stacks = true
	damage_mod.per_stack = true
	var mark = Effect.trigger_effect(Trigger.always(thunder_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "First Form: Thunderclap and Flash will permanently make Zenitsu deal 0 piercing damage to any enemy that uses a new skill on him.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, damage_mod)



func thunder_trigger(context):
	if context['source'].ability_name == "First Form: Thunderclap and Flash":
		var trigger = Effect.trigger_effect(Trigger.always(thorns_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "Zenitsu will deal 0 piercing damage to any enemy who uses a new skill on him.")
		trigger.set_source(self)
		Character.add_allied_effect(context, context['owner'], context['owner'], trigger)
		context['owner'].effects.remove_effect("Thunder Release", EffectType.Type.ACTION_USE_TRIGGER, context['owner'])


func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 75)
	
	return variations

func thorns_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['owner'], 0, DamageType.Type.PIERCING)

func extra_usable(user):
	return user.effects.has_effect("Thunder Release", EffectType.Type.ACTION_USE_TRIGGER, user) == null
	
func target(user, battle):
	default_self_target_function(user, battle)
