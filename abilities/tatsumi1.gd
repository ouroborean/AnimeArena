extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 damage to one enemy. If that enemy is stunned, they take 5 additional damage. If the target is below 50 health, they take 5 additional damage. Both of these effects can activate."

func split_desc():
	return [
		"Deals 25 damage to one enemy, +5 if the target is stunned, +5 if the target is below 50 health (both can activate)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mod_damage = base_damage
		var d_type = DamageType.Type.NORMAL
		var both = 0
		if user.marked_by("Incursio", user):
			d_type = DamageType.Type.PIERCING
		if target.has_stuns():
			mod_damage += 5
			both += 1
		if target.health.hp <= 50:
			mod_damage += 5
			both += 1
		if both == 2:
			user.manually_advance_mission(10, 1)
		Character.resolve_damage(context, target, mod_damage, d_type)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var bypass = false
	if context['owner'].has_effect("Incursio", EffectType.Type.MARK, context['owner']) and context['owner'].is_invuln():
		bypass = true
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			var mod = 0
			if character.has_stuns():
				mod += 50
			if character.health.hp <= 50:
				mod += 50
			variations.append([100 + mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, (user.has_effect("Incursio", EffectType.Type.MARK, user) and user.is_invuln()))
