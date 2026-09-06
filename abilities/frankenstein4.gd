extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 4 turns, Frankenstein will heal 15 HP any time she is affected by a new Energy skill, and Bridal Chest's cooldown increasing effect is increased by 1."

func split_desc():
	return [
		"For 4 turns, Frankenstein heals 15 HP when targeted by an Energy skill",
		"During this time, Bridal Chest adds +1 more cooldown on hit",
		["During this time, Bridal Chest and Bridal Rampage deal 5 more damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var receive = Effect.trigger_effect(Trigger.always(receive_trigger), EffectType.Type.ACTION_RECEIVE_TRIGGER, 8, "Frankenstein will heal 15 HP if she is affected by a new Energy skill.")
	receive.set_source(self)
	Character.add_allied_effect(context, user, user, receive)
	var mark = Effect.mark(9, "Bridal Chest's cooldown increasing effect is increased by 1.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

func receive_trigger(context):
	var ability = context['source']
	if not ability.classes['Energy']:
		return
	user.manually_advance_mission(8, 1)
	Character.resolve_effect_healing(context, context['effect'], user, 15)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 15, 0.9)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
