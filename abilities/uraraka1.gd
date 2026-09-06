extends Ability

var base_damage_reduction = -10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Marks one enemy. The next skill they use will have its damage reduced by 10 and will remove 1 random energy from them. Swaps to 'Gravity Plus' for 1 turn. Stackable. Invisible."

func split_desc():
	return [
		"Target enemy deals 10 less damage until they use a new skill (Stacks, Invisible)",
		["Affected enemies lose 1 energy when triggered", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var damage_mod_eff = Effect.damage_mod_effect(base_damage_reduction, -1)
		damage_mod_eff.set_source(self)
		damage_mod_eff.invisible = true
		damage_mod_eff.display_stacks = true
		damage_mod_eff.stackable = true
		damage_mod_eff.per_stack = true
		var trigger = Trigger.from_condition(Condition.always(), gravity_trigger)
		var trigger_desc = func(eff):
			return "If this character uses a new skill, they will lose 1 energy and this effect will end."
		var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, trigger_desc)
		trigger_eff.set_source(self)
		trigger_eff.cleansable = true
		trigger_eff.stackable = true
		trigger_eff.invisible = true
		
		Character.add_hostile_effect(context, user, target, damage_mod_eff)
		Character.add_hostile_effect(context, user, target, trigger_eff)


func gravity_trigger(context):
	context['owner'].lose_energy(context['effect'].user)
	context['effect'].user.manually_advance_mission(7, 1)
	
	context['owner'].effects.full_remove_effect_by_name("Zero Gravity")
	var notification_effect = Effect.invisible_expiration_effect(self)
	notification_effect.set_duration(2)
	notification_effect.set_source(self)
	Character.add_hostile_effect(context, context['effect'].user, context['owner'], notification_effect)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_spread_out(context, "Zero Gravity", EffectType.Type.ACTION_USE_TRIGGER, 150, 0.3)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
