extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 Piercing damage to one enemy. If that enemy has Shield, this skill deals 10 more damage. If that enemy has Damage Reduction, this skill deals 10 more damage. Both of these effects can activate."

func split_desc():
	return [
		"Deals 20 Piercing damage to one enemy, +10 if that enemy has Shield, +10 if that enemy has Damage Reduction (both can activate)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mod_damage = base_damage
		var both = 0
		if len(target.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)) > 0:
			mod_damage += 10
			both += 1
		if len(target.effects.get_effects_by_type(EffectType.Type.SHIELD)) > 0:
			mod_damage += 10
			both += 1
		if both == 2:
			user.manually_advance_mission(8, 1)
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.PIERCING)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			var mod = 0
			if len(character.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION)) > 0:
				mod += 25
			if len(character.effects.get_effects_by_type(EffectType.Type.SHIELD)) > 0:
				mod += 25
			variations.append([175 + mod, [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
