extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "When Shinra falls to 40 health for the first time each game, he will permanently become Isolated and Ignition: Shinra will be reapplied to Shinra each time he uses a new Harmful skill. "

func split_desc():
	return [
		["When Shinra first falls to 40 health each game, he permanently becomes Isolated and Ignition: Shinra is reapplied to him each time he uses a new Harmful skill", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger_desc = func (eff):
		return "If Shinra's health is brought to 40 or below, he will permanently become Isolated and Ignition: Shinra will be reapplied to him each time he uses a new Harmful skill."
	
	var trigger = Trigger.from_condition(Condition.health_is(user, -1, 40), hysteria_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, trigger_desc)
	trigger_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, trigger_eff)

func hysteria_trigger(context):
	var user = context['owner']
	
	user.effects.full_remove_effect_by_name("Hysterical Strength", user)
	
	
	var isolation = Effect.isolate(-1)
	isolation.set_source(self)
	
	var reapply = Effect.trigger_effect(Trigger.always(hysteria_reapply_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, -1, "If Shinra uses a Harmful skill, he will gain the effect of Ignition: Shinra.")
	reapply.set_source(self)
	
	Character.add_allied_effect(context, user, user, reapply)
	Character.add_allied_effect(context, user, user, isolation)

func hysteria_reapply_trigger(context):
	var shinra = context['owner']
	
	var color_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.GREEN, 3)
	color_change.set_source(shinra.moveset.base_abilities[0])
	var mark = Effect.mark(3, "Rapid Kick and Tora Hishigi will apply 5 permanent affliction damage to their target.")
	mark.set_source(shinra.moveset.base_abilities[0])
	
	Character.add_allied_effect(context, shinra, shinra, mark)
	Character.add_allied_effect(context, shinra, shinra, color_change)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
