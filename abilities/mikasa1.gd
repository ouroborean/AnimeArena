extends Ability
var base_damage = 20
var stun_boost_inc = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mikasa Ackerman deals 20 piercing damage to one enemy. This skill cannot be countered or reflected. If the target is affected by a stun then this deals 5 additional damage to them."

func split_desc():
	return [
		"Deals 20 piercing damage to target enemy",
		["+5 damage if the target is stunned", Color.CADET_BLUE],
		["Cannot be countered or reflected", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		var stun_boost = 0
		if target.has_stuns():
			user.manually_advance_mission(8, 1)
			stun_boost += stun_boost_inc
		
		Character.resolve_damage(context, target, base_damage + stun_boost, DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	for character in context['enemy_team'].characters:
		if (not character.is_invuln(self)) and not (character.dead or character.banished):
			var missing_hp = 100 - character.health.hp
			if character.has_stuns():
				missing_hp += 60
			variations.append([100 + int(missing_hp * 1.2), [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
