extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 Piercing damage to target enemy, 10 Piercing damage to all enemies affected by Overture Barrage, and 10 Piercing damage to any enemy affected by Concentrated Climax."

func split_desc():
	return [
		"Deals 10 Piercing damage to target enemy",
		"Deals 10 Piercing damage to all enemies affected by Overture Barrage",
		"Deals 10 Piercing damage to any enemy affected by Concentrated Climax"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target == user.targeter.main_target:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		if target.marked_by("Overture Barrage", user):
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		if target.marked_by("Concentrated Climax", user):
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	

func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		var targets = []
		if not character.is_invuln(self) and not (character.dead or character.banished):
			targets.append(character)
		for sub_character in context['enemy_team'].characters:
			if sub_character != character and (sub_character.marked_by("Overture Barrage", user) or sub_character.marked_by("Concentrated Climax", user)):
				targets.append(character)
		if len(targets) == 0:
			variations.append([0, [user, "PASS", []]])
		else:
			variations.append([150, [user, self, targets]])
	return variations

func and_target(character):
	return character.marked_by("Overture Barrage", user) or character.marked_by("Concentrated Climax", user)

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
