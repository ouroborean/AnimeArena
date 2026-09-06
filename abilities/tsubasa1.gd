extends Ability

# Azure Slash. Basic Blue strike. If the target is already suffering One Thousand Tears
# (tsubasa2's NORMAL DoT), Azure Slash also saps their non-Affliction offense for a turn.

func describe(user):
	return "Deals 20 damage to target enemy. If that enemy is affected by One Thousand Tears, they deal 10 less non-Affliction damage for 1 turn."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["If the target is affected by One Thousand Tears, they deal 10 less non-Affliction damage for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.NORMAL)
		# One Thousand Tears is a DAMAGE (DoT) effect named after tsubasa2, sourced to Tsubasa.
		if target.has_effect("One Thousand Tears", EffectType.Type.DAMAGE, user):
			var weaken = Effect.damage_mod_effect(-10, 2, [], [], [DamageType.Type.AFFLICTION])
			weaken.set_source(self)
			Character.add_hostile_effect(context, user, target, weaken)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
