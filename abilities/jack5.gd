extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "At the end of any turn in which an enemy is the only character to act, or is the only character to not act, that enemy is Isolated for 1 turn."

func split_desc():
	return [
		["At the end of a turn, any enemy who was the only character to act (or the only one not to act) is Isolated for 1 turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in context['enemy_team'].characters:
		var end_of_turn = Effect.trigger_effect(Trigger.always(isolation_trigger), EffectType.Type.END_OF_TURN_TRIGGER, -1, "If this character is the only enemy to act or not act, they will be Isolated for 1 turn.")
		end_of_turn.set_source(self)
		end_of_turn.cleansable = false
		Character.add_hostile_effect(context, user, target, end_of_turn, true)
		

func isolation_trigger(context):
	var char = context['target']
	var isolate_me = true
	for character in char.team.characters:
		if not (character.dead or character.banished) and char != character:
			if character.acted and char.acted:
				isolate_me = false
			if not character.acted and not char.acted:
				isolate_me = false
	if isolate_me:
		var isolate = Effect.isolate(3)
		isolate.set_source(self)
		isolate.unique_render_id = 1
		Character.add_hostile_effect(context, context['effect'].user, char, isolate)
	


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
