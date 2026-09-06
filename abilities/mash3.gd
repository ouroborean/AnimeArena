extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mash's teammates become invulnerable for 2 turns."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if not target.def_broken() and target.health.hp < 50:
			user.manually_advance_mission(7, 1)
		var invuln = Effect.invuln_effect(4)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, target, invuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	var targets = []
	var mod = 0
	var missing_hp = 0
	for character in context['ally_team'].characters:
		if not character.is_isolated() and not (character.dead or character.banished) and not character == user:
			targets.append(character)
			missing_hp += (100 - character.health.hp)
			mod += 25
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([mod + (missing_hp * 1.2), [user, self, targets]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
