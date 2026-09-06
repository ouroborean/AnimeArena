extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, whenever a character uses a new skill, they will permanently gain 5 Shield if they're an ally or 5 Nullify if they're an enemy."

func split_desc():
	return [
		["For 3 turns, whenever an ally uses a new skill, they permanently gain 5 Shield", Color.CADET_BLUE],
		["Whenever an enemy uses a new skill, they permanently gain 5 Nullify", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hostile = Condition.is_hostile(user, target)
		if hostile.satisfied(context):
			var trigger_eff = Effect.trigger_effect(Trigger.always(harmful_trigger), EffectType.Type.ACTION_USE_TRIGGER, 6, "If this character uses a new skill, they will permanently gain 5 Nullify.")
			trigger_eff.set_source(self)
			trigger_eff.unique_render_id = 1
			Character.add_hostile_effect(context, user, target, trigger_eff)
		else:
			var trigger_eff = Effect.trigger_effect(Trigger.always(helpful_trigger), EffectType.Type.ACTION_USE_TRIGGER, 6, "If this character uses a new skill, they will permanently gain 5 Shield.")
			trigger_eff.set_source(self)
			trigger_eff.unique_render_id = 1
			Character.add_allied_effect(context, user, target, trigger_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 40)
	
	return variations

func helpful_trigger(context):
	var shield_eff = Effect.shield_effect(5, -1)
	shield_eff.set_source(self)
	Character.add_allied_effect(context, context['effect'].user, context['owner'], shield_eff)

func harmful_trigger(context):
	var barrier = Effect.barrier_effect(5, -1)
	barrier.set_source(self)
	Character.add_allied_effect(context, context['effect'].user, context['owner'], barrier)

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
	default_hostile_target_function(user, battle)
