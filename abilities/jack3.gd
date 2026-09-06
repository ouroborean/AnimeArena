extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 affliction damage to target Isolated enemy that is also affected by Fog of London."

func split_desc():
	return [
		"Deals 30 Affliction damage to target enemy",
		["Can only target Isolated enemies affected by Fog of London", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.AFFLICTION)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished) and (character.is_isolated() and character.marked_by("Fog of London", user)):
			variations.append([190, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and (character.is_isolated() and character.marked_by("Fog of London", user)):
			check_hostile_target(user, character, context)
