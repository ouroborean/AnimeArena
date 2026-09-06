extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tanjiro deals 10 damage to all enemies for 2 turns, increased by 1 turn more whenever Tanjiro uses another skill during this skill. During this time, Tanjiro gains 10 points of damage reduction. This skill cannot be used while it is active and swaps with Sxith Form: Whirlpool."

func split_desc():
	return [
		"Deals 10 damage to all enemies for 2 turns, +1 turn each time Tanjiro uses another skill",
		["Tanjiro gains 10 damage reduction while active", Color.CADET_BLUE],
		["Cannot be reused while active", Color.DIM_GRAY],
		["Swaps with Sixth Form: Whirlpool", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var cancels = []
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3)
		damage_eff.set_source(self)
		cancels.append(damage_eff)
		Character.add_hostile_effect(context, user, target, damage_eff)
	
	var dr = Effect.damage_reduction_effect(10, 3)
	dr.set_source(self)
	cancels.append(dr)
	var trigger_eff = Effect.trigger_effect(Trigger.always(third_form_trigger), EffectType.Type.ACTION_USE_TRIGGER, 3, "If Tanjiro uses a skill, this effect will be extended by 1 turn.")
	trigger_eff.set_source(self)
	cancels.append(trigger_eff)
	
	var cancel_eff = Effect.control_cancel(3, "Third Form: Flowing Dance", cancels)
	cancel_eff.set_source(self)
	
	
	Character.add_allied_effect(context, user, user, dr)
	Character.add_allied_effect(context, user, user, trigger_eff)
	Character.add_allied_effect(context, user, user, cancel_eff)
	
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25)
	
	return variations

func third_form_trigger(context):
	for character in context['owner'].battle.all_characters():
		if character.has_effect("Third Form: Flowing Dance", EffectType.Type.DAMAGE, context['owner']):
			character.has_effect("Third Form: Flowing Dance", EffectType.Type.DAMAGE, context['owner']).duration += 2
		if character.has_effect("Third Form: Flowing Dance", EffectType.Type.ACTION_USE_TRIGGER, context['owner']):
			character.has_effect("Third Form: Flowing Dance", EffectType.Type.ACTION_USE_TRIGGER, context['owner']).duration += 2
		if character.has_effect("Third Form: Flowing Dance", EffectType.Type.DAMAGE_REDUCTION, context['owner']):
			character.has_effect("Third Form: Flowing Dance", EffectType.Type.DAMAGE_REDUCTION, context['owner']).duration += 2
		if character.has_effect("Third Form: Flowing Dance", EffectType.Type.CONTROL_CANCEL, context['owner']):
			character.has_effect("Third Form: Flowing Dance", EffectType.Type.CONTROL_CANCEL, context['owner']).duration += 2

func extra_usable(user):
	return user.has_effect("Third Form: Flowing Dance", EffectType.Type.CONTROL_CANCEL, user) == null
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
