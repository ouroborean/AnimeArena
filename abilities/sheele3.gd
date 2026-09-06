extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 2 turns, all enemies are Shattered. During this time, neither of Sheele's allies can be killed. "

func split_desc():
	return [
		["All enemies are Shattered for 2 turns", Color.ORANGE_RED],
		["Sheele's allies cannot be killed for 2 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in context['enemy_team'].characters:
			var shatter = Effect.def_negate(3)
			shatter.set_source(self)
			Character.add_hostile_effect(context, user, target, shatter)
		else:
			var immortal = Effect.immortality_effect(4)
			immortal.set_source(self)
			Character.add_allied_effect(context, user, target, immortal)
			
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var targets = []
	var mod = 0
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			targets.append(character)
			mod += 35
	for character in context['ally_team'].characters:
		if not (character.dead or character.banished):
			targets.append(character)
			mod += (100 - character.health.hp)
			mod += 35
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([mod, [user, self, targets]])
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
