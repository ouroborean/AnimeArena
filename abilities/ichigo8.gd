extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "After using this skill, if Ichigo's health reaches 50 or lower, he gains 25 Shield and deals 10 more damage. During this time, this skill will be replaced by 'Getsuga Vortex'. This skill will end if its Shield is destroyed and cannot be used while active."

func split_desc():
	return [
		"When Ichigo's health next falls to 50 or lower, he gains 25 Shield and deals 10 more damage with all skills",
		["Replaced by Getsuga Vortex while active", Color.AQUA],
		["Ends when the Shield is destroyed; cannot be used while active", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger_desc = func (eff):
		return "If Ichigo's health is brought to 50 or lower, he will gain 25 Shield, deal 10 more damage with all his skills, and this skill will be replaced by Getsuga Vortex. This skill ends when the Shield is destroyed."
	var trigger = Trigger.from_condition(Condition.health_is(user, -1, 50), takeover_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, trigger_desc)
	trigger_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, trigger_eff)

func takeover_trigger(context):
	var user = context['owner']
	user.effects.full_remove_effect_by_name("Hollow Takeover", user)
	var portrait = Effect.portrait_change_effect(1, -1)
	portrait.set_source(self)
	Character.add_allied_effect(context, user, user, portrait)
	var shield = Effect.shield_effect(25, -1)
	shield.set_source(self)
	shield.wrapup_func = shield_break_trigger
	
	var boost = Effect.damage_mod_effect(10, -1)
	boost.set_source(self)
	
	var ability_swap = Effect.ability_swap_effect(8, 2, user, -1)
	ability_swap.set_source(self)
	
	Character.add_allied_effect(context, user, user, shield)
	Character.add_allied_effect(context, user, user, boost)
	Character.add_allied_effect(context, user, user, ability_swap)

func shield_break_trigger(context):
	context['effect'].user.full_remove_effect_by_name("Hollow Takeover", context['effect'].user)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25, 0.3)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	default_self_target_function(user, battle)
