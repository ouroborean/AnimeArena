extends Ability

func describe(user):
	return "Target enemy gains 15 points of Nullify for 1 turn. If this Nullify expires without being broken, the affected enemy receives 25 Affliction damage. While Empowered, this skill affects all enemies."

func split_desc():
	return [
		"Target enemy gains 15 points of Nullify for 1 turn",
		"If the Nullify expires without being broken, the enemy receives 25 Affliction damage",
		["While Empowered, this skill affects all enemies", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.marked_by("Rokudo Takeover")

	var targets = user.targeter.targets
	if empowered:
		targets = []
		for character in battle.all_characters():
			if user.is_hostile(character) and not (character.dead or character.banished):
				targets.append(character)

	for target in targets:
		var shield = Effect.barrier_effect(15, 2)
		shield.set_source(self)
		shield.description = func (eff):
			return "This character has " + str(eff.mag) + " points of Nullify. If this Nullify expires, this character will receive 25 Affliction damage."
		shield.wrapup_func = nullify_expire
		Character.add_hostile_effect(context, user, target, shield)

func nullify_expire(context):
	if context['effect'].breaker != null:
		return
	var target_char = context['target']
	if not target_char.dead and not target_char.banished:
		Character.resolve_effect_damage(context, context['effect'], target_char, 25, DamageType.Type.AFFLICTION)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	if context['owner'].marked_by("Rokudo Takeover"):
		variations += behavior_hostile_aoe_damage(context, 20)
	else:
		variations += behavior_single_target_damage(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
