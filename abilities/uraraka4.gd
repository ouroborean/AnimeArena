extends Ability

var base_shield = 20
var base_damage_reduction = -10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 2 turns, Uraraka gains 20 points of Shield and any enemy that uses a new skill on her will have 'Zero Gravity' used on them. During this time, this skill is replaced by 'Gravity Plus'. Invisible."

func split_desc():
	return [
		"For 2 turns, Uraraka gains 20 Shield (Invisible)",
		["Uses Zero Gravity on any enemy that uses a skill on her while active", Color.CADET_BLUE]
	]


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shield_eff = Effect.shield_effect(base_shield, 4)
	shield_eff.set_source(self)
	shield_eff.invisible = true
	var trigger = Trigger.from_condition(Condition.always(), float_trigger)
	var trigger_desc = func (eff):
		return "If an enemy uses a new skill on this character, they will have Zero Gravity used on them."
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 4, trigger_desc)
	trigger_eff.invisible = true
	trigger_eff.set_source(self)
	trigger_eff.cleansable = true

	Character.add_allied_effect(context, user, user, shield_eff)
	Character.add_allied_effect(context, user, user, trigger_eff)


func float_trigger(context):
	var target = context['source'].user
	var user = context['effect'].user
	
	var damage_mod_eff = Effect.damage_mod_effect(base_damage_reduction, -1)
	damage_mod_eff.set_source(user.moveset.base_abilities[0])
	damage_mod_eff.invisible = true
	damage_mod_eff.display_stacks = true
	damage_mod_eff.stackable = true
	damage_mod_eff.per_stack = true
	var trigger = Trigger.from_condition(Condition.always(), gravity_trigger)
	var trigger_desc = func(eff):
		return "If this character uses a new skill, they will lose 1 energy and this effect will end."
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, trigger_desc)
	trigger_eff.set_source(user.moveset.base_abilities[0])
	trigger_eff.stackable = true
	trigger_eff.invisible = true
	
	Character.add_hostile_effect(context, user, target, damage_mod_eff)
	Character.add_hostile_effect(context, user, target, trigger_eff)

func gravity_trigger(context):
	context['owner'].lose_energy(context['effect'].user)
	
	
	context['owner'].effects.full_remove_effect_by_name("Zero Gravity")

	var notification_effect = Effect.invisible_expiration_effect(self)
	notification_effect.set_duration(2)
	notification_effect.set_source(context['effect'].user.moveset.base_abilities[1])
	Character.add_hostile_effect(context, context['effect'].user, context['owner'], notification_effect)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25, 5.0)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
