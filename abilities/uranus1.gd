extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 20 damage to target enemy and gives the ally marked with Uranus Lip Rod 10 Shield for 1 turn."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["Grants 10 Shield to the ally marked by Uranus Lip Rod for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.ENERGY)

	# Lip Rod ally is whichever allied character carries the passive's mark
	# (source=uranus5, user=Uranus). The marked_by helper accepts the source
	# user as its second arg so we get exact-source disambiguation.
	var lip_rod_ally = _find_lip_rod_ally(user)
	if lip_rod_ally != null and not (lip_rod_ally.dead or lip_rod_ally.banished):
		var shield = Effect.shield_effect(10, 3)
		shield.set_source(self)
		Character.add_allied_effect(context, user, lip_rod_ally, shield)

func _find_lip_rod_ally(user):
	for ally in user.team.characters:
		if ally == user:
			continue
		if ally.marked_by("Uranus Lip Rod", user):
			return ally
	return null

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
