extends Ability

var base_damage = 25
var base_damage_boost = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 damage to one enemy, Bypassing Invulnerability. This skill deals 10 additional damage and refunds Luffy 1 red energy if used on an enemy who is Invulnerable."

func split_desc():
	return [
		"Deals 25 damage to target enemy, Bypassing Invulnerability",
		["+10 damage and refunds 1 Red energy if the target is Invulnerable", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mod_damage = base_damage
		if target.is_invuln(self):
			mod_damage += base_damage_boost
			user.gain_bonus_energy(Energy.Type.RED)
		
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.NORMAL)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var luffy = context['owner']
	for character in context['enemy_team'].characters:
		var mod = 0
		if character.is_invuln(self):
			mod += 75
		if not (character.dead or character.banished):
			variations.append([100 + mod + (100 - character.health.hp), [luffy, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
