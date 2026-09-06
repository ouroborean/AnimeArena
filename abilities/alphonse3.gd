extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 affliction damage to one enemy and removes 1 random energy from them. Requires Transmutation Circle to be used."

func split_desc():
	return [
		"Deals 20 Piercing damage to one enemy and removes 1 Random energy from them"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		target.lose_energy(user, 1)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Transmutation Circle", user)
	
func custom_behavior(context):
	var variations = []
	
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			var missing_hp = 100 - character.health.hp
			variations.append([125 + missing_hp, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
