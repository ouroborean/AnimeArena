extends Ability

var base_damage = 40

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 40 damage to one enemy, Bypassing Invulnerability. This skill fully stuns the target for 1 turn if used on an enemy who is Invulnerable."

func split_desc():
	return [
		"Deals 40 damage to target enemy, Bypassing Invulnerability",
		["Fully stuns the target for 1 turn if they were Invulnerable", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var target_invuln = Condition.is_invuln(target)
		
		if target.is_invuln(self):
			var eff = Effect.stun_effect(2)
			eff.set_source(self)
			Character.add_hostile_effect(context, user, target, eff, true)
		
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
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
			variations.append([125 + mod + (100 - character.health.hp), [luffy, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
