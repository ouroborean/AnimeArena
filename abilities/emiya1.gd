extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Gives Emiya 5 Shield",
		["Swaps with a random Projection skill for 1 turn", Color.AQUAMARINE]
	]


func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shield = Effect.shield_effect(5, -1)
	shield.set_source(self)
	Character.add_allied_effect(context, user, user, shield)
	var roll = battle.roll(2, 5)
	var copy = Effect.copy_effect(user.moveset.abilities[roll], user.moveset.get_active_abilities(user).find(self), 3, user)
	copy.unique_render_id = int(Time.get_ticks_msec())
	copy.set_source(self)
	Character.add_allied_effect(context, user, user, copy)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 30)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
