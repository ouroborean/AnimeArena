extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Gon gains 10 Shield and his skills will deal 5 more damage permanently and are improved. This skill stacks & will end if Gon uses a Damaging Skill."

func split_desc():
	return [
		"Gon gains 10 Shield and +5 damage permanently",
		"Ends if Gon uses a damaging skill"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var eff_desc = func (eff):
		return "Gon's other skills are improved until he uses a new skill other than Jajanken Stance."
	var trigger = Trigger.from_condition(Condition.always(), jajanken_trigger)
	var eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, eff_desc)
	eff.refresh = true
	eff.set_source(self)
	
	var boost_eff = Effect.damage_mod_effect(5, -1, ["Jajanken Paper", "Jajanken Rock"])
	boost_eff.set_source(self)
	boost_eff.stackable = true
	boost_eff.display_stacks = true
	boost_eff.per_stack = true
	
	var shield_eff = Effect.shield_effect(10, -1, false)
	shield_eff.set_source(self)
	shield_eff.stack_mag = true
	shield_eff.display_mag = true
	shield_eff.stackable = true
	shield_eff.unique_render_id = 5
	var random_cost_eff = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, -1, ["Jajanken Paper"])
	random_cost_eff.set_source(self)
	random_cost_eff.system = true
	
	Character.add_allied_effect(context, user, user, eff)
	Character.add_allied_effect(context, user, user, boost_eff)
	Character.add_allied_effect(context, user, user, random_cost_eff)
	Character.add_allied_effect(context, user, user, shield_eff)

func jajanken_trigger(context):
	var gon = context['owner']
	if not gon.used_ability:
		return
	if gon.used_ability.ability_name != "Jajanken Stance":
		context['owner'].effects.full_remove_effect_by_name("Jajanken Stance")

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	var jajanken_stacks = 0
	if user.has_effect("Jajanken Stance", EffectType.Type.DAMAGE_MOD, user):
		jajanken_stacks = user.has_effect("Jajanken Stance", EffectType.Type.DAMAGE_MOD, user).stack_count()
		
	variations += behavior_self_panic_button(context, 150 - (50 * jajanken_stacks), 1.1)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
