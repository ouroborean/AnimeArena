extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 Piercing damage to one enemy and ends all of that enemy's cancellable effects. Can instead be used on an ally to cleanse them of all Harmful effects and make them Invulnerable for 1 turn."

func split_desc():
	return [
		"Deals 25 Piercing damage to one enemy and ends all of their cancellable effects",
		["Or, on an ally: cleanses all Harmful effects and grants Invulnerability for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			# Ally: cleanse all Harmful (enemy-placed) effects and grant 1 turn of Invulnerability.
			target.effects.cleanse_all_enemy_effects(user)
			var invuln = Effect.invuln_effect(2)
			invuln.set_source(self)
			Character.add_allied_effect(context, user, target, invuln)
		else:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
			target.check_cancels(true)
		
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
			if len(character.effects.get_effects_by_type(EffectType.Type.CHANNEL_CANCEL)) > 0:
				mod += 150
			if len(character.effects.get_effects_by_type(EffectType.Type.CONTROL_CANCEL)) > 0:
				mod += 150
			variations.append([50 + mod, [user, self, [character]]])
			
	# Also consider cleansing + shielding an ally carrying Harmful (cleansable) effects.
	for character in context['ally_team'].characters:
		if character.dead or character.banished or character == context['owner']:
			continue
		var harmful = 0
		for eff in character.effects._effects:
			if character.is_hostile(eff.user) and eff.cleansable:
				harmful += 1
		if harmful > 0:
			variations.append([30 + harmful * 25, [user, self, [character]]])

	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])

	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
