extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Ban is permanently Immortal",
		["If Ban receives damage that drops him to 1 HP, he is banished for 1 turn and returns at 20 HP", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var immortality = Effect.immortality_effect(-1)
	immortality.set_source(self)
	immortality.cleansable = false
	Character.add_allied_effect(context, user, user, immortality)
	var damage_trigger = Effect.trigger_effect(Trigger.always(damage_taken_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "If Ban falls to 1 HP, he will be banished for 1 turn")
	damage_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, damage_trigger)

func damage_taken_trigger(context):
	if user.health.hp <= 1:
		var duration
		if user in user.battle.player.team.characters:
			if user.battle.waiting_for_turn:
				#Allied ban killed On enemy turn
				duration = 3
			else:
				#Allied ban killed On player turn
				duration = 4
		else:
			if user.battle.waiting_for_turn:
				duration = 4
			else:
				duration = 3
		
		
		if user.waiting:
			duration = 4
		user.banish_character(QueryContext.from_game_state(user, user.battle), user, self, duration, timeout_trigger)
		

func timeout_trigger(context):
	user.set_health_capped(20)

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
