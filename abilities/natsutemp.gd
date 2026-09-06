extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Natsu targets one enemy and ignores all harmful effects until the end of his next turn. On the following turn, he will deal 15 damage and 0 affliction damage to the targeted enemy, increased by 5 damage for each new skill Natsu ignored. Invisible."

func split_desc():
	return [
		"Natsu ignores all Harmful effects until the end of his next turn",
		["Next turn, deals 15 damage to the targeted enemy, +5 for each new skill Natsu ignored", Color.CADET_BLUE],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var ticking_trigger = Effect.trigger_effect(Trigger.always(sword_horn_trigger), EffectType.Type.TICKING_TRIGGER, 3, "Natsu will deal 15 physical damage and 0 affliction damage to this character.")
		ticking_trigger.invisible = true
		ticking_trigger.set_source(self)
		ticking_trigger.damage_type = DamageType.Type.NORMAL
		ticking_trigger.wrapup_func = default_counter_timeout
		Character.add_hostile_effect(context, user, target, ticking_trigger)
	var harmful_ignore = Effect.ignore_non_damage_effect(3)
	harmful_ignore.set_source(self)
	harmful_ignore.invisible = true
	var damage_ignore = Effect.ignore_damage_effect(2)
	damage_ignore.set_source(self)
	damage_ignore.invisible = true
	var receive_trigger = Effect.trigger_effect(Trigger.always(sword_horn_boost_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "If Natsu receives a new harmful skill, Fire Dragon's Sword Horn will deal 5 more damage (stacks).")
	receive_trigger.set_source(self)
	receive_trigger.invisible = true
	receive_trigger.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, harmful_ignore)
	Character.add_allied_effect(context, user, user, damage_ignore)
	Character.add_allied_effect(context, user, user, receive_trigger)

func sword_horn_trigger(context):
	Character.resolve_effect_damage(context, context['effect'], context['target'], 15, DamageType.Type.NORMAL)
	Character.resolve_effect_damage(context, context['effect'], context['target'], 0, DamageType.Type.AFFLICTION)
	

func sword_horn_boost_trigger(context):
	var natsu = context['target']
	var damage_mod = Effect.damage_mod_effect(5, 2, ["Fire Dragon's Sword Horn"])
	damage_mod.set_source(self)
	damage_mod.stackable = true
	damage_mod.display_stacks = true
	damage_mod.per_stack = true
	Character.add_allied_effect(context, natsu, natsu, damage_mod)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 55)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
