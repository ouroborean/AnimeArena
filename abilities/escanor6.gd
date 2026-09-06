extends Ability

# Divine Spear: Escanor (hidden base_abilities[5]). Swapped into display slot 0 by Rhitta Smash's
# watcher while Escanor holds 12 Sunshine. On use it deals 100 Piercing and consumes ALL Sunshine,
# then re-evaluates the swap so slot 0 reverts to Rhitta Smash the same turn.

var base_damage = 100

func describe(user):
	return "Deals 100 Piercing damage to target enemy. This skill replaces Rhitta Smash whenever Escanor has 12 stacks of Sunshine, and consumes all stacks on use."

func split_desc():
	return [
		"Deals 100 Piercing damage to target enemy",
		["Replaces Rhitta Smash while Escanor has 12 Sunshine; consumes all stacks on use", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	# consume ALL Sunshine, then revert the swap this turn
	user.effects.remove_effect("Sunshine", EffectType.Type.MARK, user)
	user.moveset.base_abilities[0]._evaluate_divine(context, user)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, base_damage)

func target(user, battle):
	default_hostile_target_function(user, battle)
