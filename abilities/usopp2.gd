extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, if any enemy uses a new skill on Usopp or target ally, they will be countered and Stunned for 1 turn if they are currently Blinded."

func split_desc():
	return [
		["For 1 turn, counters any enemy that uses a new skill on Usopp or target ally", Color.CADET_BLUE],
		["Countered enemy is Stunned for 1 turn if currently Blinded", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter_eff = Effect.counter_effect(Trigger.always(impact_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "If any enemy uses a new skill on this character, they will be countered and Stunned for 1 turn if they're blinded.")
		counter_eff.invisible = true
		counter_eff.wrapup_func = default_counter_timeout
		counter_eff.set_source(self)
		Character.add_allied_effect(context, user, target, counter_eff)

func impact_trigger(context):
	var attacker = context['owner']
	var usopp = context['target']
	
	if len(attacker.effects.get_effects_by_type(EffectType.Type.BLIND)) >= 1 and not attacker.shrug_off_type(EffectType.Type.BLIND):
		var stun = Effect.stun_effect(3)
		stun.set_source(self)
		Character.add_hostile_effect(context, usopp, attacker, stun)
	
	var notification_effect = Effect.counter_notification_effect(self)
	notification_effect.set_source(self)
	Character.add_hostile_effect(context, usopp, attacker, notification_effect)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 35, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
