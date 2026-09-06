extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Hisoka executes target enemy",
		["This skill can only be used on the most damaged living enemy", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	for target in user.targeter.targets:
		# Instantly kill the target
		target.instant_kill(user, self)

func extra_usable(user):
	return true
	
func custom_behavior(context):
	# AI Behavior: Extremely high priority (Execute)
	var variations = []
	var user = context['owner']
	
	# 1. Find the lowest HP threshold
	var lowest_hp = 99999
	for enemy in context['enemy_team'].characters:
		# Skip dead, banished, or invulnerable targets (AI shouldn't waste executes on invuln)
		if not (enemy.dead or enemy.banished) and not enemy.is_invuln(self):
			if enemy.health.hp < lowest_hp:
				lowest_hp = enemy.health.hp
	
	# 2. Suggest using this skill on any enemy matching that threshold
	for enemy in context['enemy_team'].characters:
		if not (enemy.dead or enemy.banished) and not enemy.is_invuln(self):
			if enemy.health.hp == lowest_hp:
				# Weight 1000 virtually guarantees usage if valid
				variations.append([1000, [user, self, [enemy]]])
	
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
		
	return variations
	
func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	# 1. Calculate the lowest health among living enemies
	var lowest_hp = 99999
	var enemy_team = battle.get_team_factions_from_character(user)[1]
	
	for character in enemy_team.characters:
		if not (character.dead or character.banished):
			if character.health.hp < lowest_hp:
				lowest_hp = character.health.hp
	
	# 2. Only allow targeting for enemies that match that lowest HP
	for character in enemy_team.characters:
		if not (character.dead or character.banished):
			if character.health.hp == lowest_hp:
				# We manually invoke the trigger that allows the UI to select this target
				check_hostile_target(user, character, context)
