extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 2 turns, whenever an ally receives new damage, they will heal for that amount over the next 2 turns."

func split_desc():
	return [
		["For 2 turns, whenever an ally receives new damage, they heal that amount over the next 2 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(synchro_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, 4, "If this character receives new damage, they will heal for that amount over the next 2 turns.")
		trigger.set_source(self)
		trigger.ability_only = true
		Character.add_allied_effect(context, user, target, trigger)

func synchro_trigger(context):
	var attacker = context['owner']
	var damaged = context['target']
	var damage = context['value']
	var eff = context['effect']
	var heal_eff = Effect.healing_effect(damage / 2, 4)
	heal_eff.unique_render_id = int(Time.get_ticks_msec())
	heal_eff.set_source(self)
	Character.add_allied_effect(context, eff.user, damaged, heal_eff)
	
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_heal(context, 35, 0.9)
	
	return variations
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
