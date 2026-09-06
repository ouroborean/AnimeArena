extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever any of Koro-Sensei's allies ends their turn without using a new skill, they will gain 10 Shield for 1 turn. Whenever any of his allies is stunned, they will heal 10 HP."

func split_desc():
	return [
		["An ally who ends their turn without using a new skill gains 10 Shield for 1 turn", Color.CADET_BLUE],
		["Whenever an ally is stunned, they heal 10 HP", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.team.characters:
		if target == user:
			continue
		var stun_trigger = Effect.trigger_effect(Trigger.always(class_stun_trigger), EffectType.Type.STUN_RECEIVED_TRIGGER, -1, "If this character is stunned, they will heal 10 HP.")
		stun_trigger.set_source(self)
		var end_trigger = Effect.trigger_effect(Trigger.always(end_of_turn_trigger), EffectType.Type.END_OF_TURN_TRIGGER, -1, "If this character ends their turn without using a new skill, they will gain 10 Shield for 1 turn.")
		end_trigger.set_source(self)
		Character.add_allied_effect(context, user, target, stun_trigger)
		Character.add_allied_effect(context, user, target, end_trigger)
		


func class_stun_trigger(context):
	var koro = context['effect'].user
	var target = context['target']
	user.manually_advance_mission(10, 10)
	Character.resolve_effect_healing(context, context['effect'], target, 10)
	

func end_of_turn_trigger(context):
	var koro = context['effect'].user
	var target = context['target']
	
	if target.acted:
		return
	
	user.manually_advance_mission(10, 10)
	var shield = Effect.shield_effect(10, 2)
	shield.set_source(self)
	Character.add_allied_effect(context, koro, target, shield)
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
