extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 3 turns, Omnimon will ignore Harmful, non-damaging effects and if his Nemesis is alive, he can only target them. During this time, his Nemesis is Isolated."

func split_desc():
	return [
		["For 3 turns, Omnimon ignores negative non-damage effects", Color.CADET_BLUE],
		["While his Nemesis is alive, he can only target them", Color.DIM_GRAY],
		["His Nemesis is Isolated during this time", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ignore = Effect.ignore_non_damage_effect(6)
	ignore.set_source(self)
	Character.add_allied_effect(context, user, user, ignore)
	
	for enemy in context['enemy_team'].characters:
		if enemy.marked_by("Digidestiny", user) and not enemy.dead and not enemy.banished:
			var mark = Effect.mark(5, "Omnimon can only target his Nemesis.")
			mark.set_source(self)
			Character.add_allied_effect(context, user, user, mark)
			
			var isolation = Effect.isolate(6)
			isolation.set_source(self)
			Character.add_hostile_effect(context, user, enemy, isolation, true)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
