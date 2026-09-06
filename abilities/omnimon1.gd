extends Ability

var base_damage = 30

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 Piercing damage to target enemy. If that enemy is Omnimon's Nemesis, this skill will Bypass and remove all Shield effects from the target before damaging them."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy",
		["If the target is Omnimon's Nemesis, Bypasses Invulnerability and removes all their Shield first", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target.marked_by("Digidestiny", user) or user.marked_by("Digidestiny", user):
			user.manually_advance_mission(9, 1)
			target.shatter_shields(user)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		var bypass = false
		var nemesis_mod = 0
		if character.marked_by("Digidestiny", user) or user.marked_by("Digidestiny", user):
			bypass = true
			nemesis_mod = 70
		
		if (user.marked_by("Destiny Digivolve", user) and not character.marked_by("Digidestiny", user)) and not user.marked_by("Digidestiny", user):
			continue
		
		if (not character.is_invuln(self) or bypass) and not (character.dead or character.banished):
			variations.append([100 + nemesis_mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in context['enemy_team'].characters:
		var bypassing = false
		if character.marked_by("Digidestiny", user) or user.marked_by("Digidestiny", user):
			bypassing = true
		if (user.marked_by("Destiny Digivolve", user) and not character.marked_by("Digidestiny", user)) and not user.marked_by("Digidestiny", user):
			continue
		check_hostile_target(user, character, context, bypassing)
