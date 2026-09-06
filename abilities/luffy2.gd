extends Ability

var base_damage = 10
var boost_increment = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 damage to all enemies, Bypassing Invulnerability. This skill deals 5 more damage every time it is used (stacks) and lasts 1 more turn if used on an enemy who is Invulnerable."

func split_desc():
	return [
		"Deals 10 damage to all enemies, Bypassing Invulnerability",
		["+5 damage each time it is used (stacks)", Color.CADET_BLUE],
		["Deals 10 damage again next turn to any enemy who was Invulnerable", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var target_invuln = Condition.is_invuln(target)
		
		if target.is_invuln(self):
			var eff = Effect.damage_effect(base_damage, DamageType.Type.NORMAL, 3)
			eff.set_source(self)
			Character.add_hostile_effect(context, user, target, eff, true)
		
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
	var boost_eff = Effect.damage_mod_effect(5, -1, ["Gomu Gomu No Gatling Gun"])
	boost_eff.set_source(self)
	boost_eff.stackable = true
	boost_eff.per_stack = true
	boost_eff.display_stacks = true
	Character.add_allied_effect(context, user, user, boost_eff)

func custom_behavior(context):
	var variations = []
	var luffy = context['owner']
	var targets = []
	var mod = 0
	var missing_hp = 0
	for character in context['enemy_team'].characters:
		if character.is_invuln(self):
			mod += 50
		if not (character.dead or character.banished):
			missing_hp += (100 - character.health.hp)
			targets.append(character)
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([125 + mod + (missing_hp * 0.5), [luffy, self, targets]])
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
