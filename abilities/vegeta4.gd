extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Vegeta gains 10 points of damage reduction for 1 turn. If he doesn't have a new Harmful skill used on him during this time, he reduces the cost of Galick Gun by 1 Red energy until the next time it's used (stacks)."

func split_desc():
	return [
		["Vegeta gains 10 damage reduction for 1 turn", Color.CADET_BLUE],
		["If no new Harmful skill is used on him during this time, reduces Galick Gun's cost by 1 Red energy until next used (stacks)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dr = Effect.damage_reduction_effect(10, 2)
	dr.set_source(self)
	var trigger = Effect.trigger_effect(Trigger.always(charge_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, func (eff): return "If Vegeta doesn't receive a new Harmful skill, Galick Gun will have its cost reduced.")
	trigger.set_source(self)
	trigger.wrapup_func = wrapup_trigger

	Character.add_allied_effect(context, user, user, trigger)
	Character.add_allied_effect(context, user, user, dr)

func wrapup_trigger(context):
	var vegeta = context['owner']
	
	var cost_mod = Effect.cost_mod_effect(-1, -1, Energy.Type.RED, ["Galick Gun"])
	cost_mod.set_source(self)
	cost_mod.stackable = true
	cost_mod.display_stacks = true
	cost_mod.per_stack = true
	Character.add_allied_effect(context, vegeta, vegeta, cost_mod)

func charge_trigger(context):
	var vegeta = context['effect'].user
	if context['source'] is Effect:
		return
	
	if vegeta.has_effect("Energy Charge", EffectType.Type.HARMFUL_RECEIVE_TRIGGER):
		vegeta.effects.erase_effect(vegeta.has_effect("Energy Charge", EffectType.Type.HARMFUL_RECEIVE_TRIGGER))
		

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
