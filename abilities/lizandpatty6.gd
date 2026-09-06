extends Ability

func describe(user):
	return "Deals 15 Piercing damage to target enemy and gives the ally wielding Liz 10 Shield. Can only be used if Liz is currently being wielded."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy.",
		"Gives the ally wielding Liz 10 Shield."
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
	var wielder = _find_wielder(user)
	if wielder != null:
		var shield = Effect.shield_effect(10, -1)
		shield.set_source(self)
		Character.add_allied_effect(context, user, wielder, shield)

func _find_wielder(user):
	# The wielder package installed by Transform: Liz (lizandpatty1) is a
	# COLOR_CHANGE plus a HARMFUL_USE_TRIGGER on the target, both sourced from
	# that ability (so effect_name() == "Transform: Liz") and user-owned by the
	# Thompson Sisters. There is NO wielder MARK: the "Transform: Demon Twin
	# Guns" mark belonged to a retired single-transform design (lizandpattyold).
	# Key the lookup on the trigger, exactly as lizandpatty3 does.
	for character in user.team.characters:
		var wield = character.has_effect("Transform: Liz", EffectType.Type.HARMFUL_USE_TRIGGER, user)
		if wield != null:
			return character
	return null

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
