extends Ability
var base_damage = 45
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Saber deals 45 piercing damage to one enemy and Silences them for one turn. This skill cannot be countered or reflected and starts the game on cooldown."

func split_desc():
	return [
		"Saber deals 45 piercing damage to one enemy",
		["Silences the target for 1 turn", Color.ORANGE_RED],
		["Cannot be countered or reflected", Color.DIM_GRAY],
		["Starts the game on cooldown", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var silence = Effect.silence_effect(2)
		silence.set_source(self)
		Character.add_allied_effect(context, user, target, silence)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	
	variations += behavior_single_target_damage(context, 175, 0.7)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
