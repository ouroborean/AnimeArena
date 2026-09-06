extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"If Black Star is alive on Tsubaki's team, Tsubaki Mode: Kusarigama can only target him and is used on him automatically at the start of the game",
		["Tsubaki Mode: Smoke Bomb will trigger Black Star's Tsubaki Smoke Bomb (S4) if used while Black Star is stunned", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in user.team.characters:
		if character.path_name == "blackstar":
			
			user.targeter.targets = [character]
			user.targeter.main_target = character
			
			user.moveset.base_abilities[0].execute(user, battle)
			user.moveset.base_abilities[0].cooldown_remaining = 3
			if battle.get_player_owner(user).waiting_for_turn:
				user.moveset.base_abilities[0].cooldown_remaining = 4
			user.targeter.clear_targets()
			var mark_eff = Effect.mark(-1, "Tsubaki Mode: Kusarigama can only target Black Star.")
			mark_eff.set_source(self)
			mark_eff.cleansable = false
			Character.add_allied_effect(context, user, user, mark_eff)
		
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
