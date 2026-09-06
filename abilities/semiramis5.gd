extends Ability
var base_shield = 25

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Semiramis begins the game banished for 2 turns. She returns to the game with 25 permanent Shield, and gains 1 random energy."

func split_desc():
	return [
		["Semiramis begins the game banished for 2 turns", Color.DIM_GRAY],
		["Returns to the game with 25 permanent Shield, and gains 1 random energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var duration
	var mod
	if not battle.waiting_for_turn:
		#going first with allied semiramis
		if user in battle.player.team.characters:
			duration = 3
			mod = 1
		#going first with enemy semiramis
		else:
			duration = 4
			mod = 1
	else:
		#going second with allied semiramis
		if user in battle.player.team.characters:
			duration = 4
			mod = 1
		#going second with enemy semiramis
		else:
			duration = 3
			mod = 1
	
	
	var context = QueryContext.from_game_state(user, battle)
	
	var entrance_trigger = Effect.trigger_effect(Trigger.always(babylon_trigger), EffectType.Type.START_OF_TURN_TRIGGER, duration + mod, "When this effect ends, Semiramis will rejoin the battle with 25 permanent Shield, and she will gain 1 random energy.")
	entrance_trigger.tick_during_banish = true
	entrance_trigger.set_source(self)
	entrance_trigger.cleansable = false
	Character.add_allied_effect(context, user, user, entrance_trigger)
	user.banish_character(context, user, self, duration)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func babylon_trigger(context):
	if context['source'].duration > 1:
		return
	context['source'].user.effects.remove_effect("Hanging Gardens of Babylon", EffectType.Type.START_OF_TURN_TRIGGER, context['source'].user)
	var shield_effect = Effect.shield_effect(base_shield, -1)
	shield_effect.set_source(self)
	Character.add_allied_effect(context, user, user, shield_effect)
	context['effect'].user.gain_random_energy()
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
