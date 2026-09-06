extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 40 damage to target enemy",
		["Deals 10 more damage to an enemy marked by Great Dragon Fire", Color.CADET_BLUE],
		["If that enemy's HP falls to 10 or lower, they will be executed", Color.ORANGE_RED],
		["Cannot be countered and can only be used once", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# The mark is named after its SOURCE ability and sasuke3 does set_source(self),
		# so the literal "Great Dragon Fire" is the right lookup key.
		var damage = 40
		if target.marked_by("Great Dragon Fire", user):
			damage += 10
		Character.resolve_damage(context, target, damage, DamageType.Type.NORMAL)
		target.execute_attempt(10, user, self)
	var used_mark = Effect.mark(-1, "Kirin has been used.")
	used_mark.set_source(self)
	used_mark.invisible = true
	Character.add_allied_effect(context, user, user, used_mark)
	# Great Dragon Fire's swap is permanent now, so Kirin has to retire itself:
	# without this, slot 2 would be occupied forever by a skill extra_usable()
	# permanently refuses and Sasuke would play the rest of the match on 3 skills.
	# Typed on ABILITY_SWAP so it cannot hit the enemy-side Great Dragon Fire MARK.
	user.effects.remove_effect("Great Dragon Fire", EffectType.Type.ABILITY_SWAP, user)

func extra_usable(user):
	return not user.marked_by("Kirin")

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 100)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
