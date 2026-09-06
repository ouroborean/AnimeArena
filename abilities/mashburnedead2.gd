extends Ability

# Ballista Knuckle (display slot 1). 20 damage. When Mash is enhanced (Big Bang Dash), it first
# removes all Shield AND all Damage Reduction on the target, dealing 10 more for EACH category actually
# removed (matching Hell Fall Knuckle — both can occur, up to +20).

const BASE = 20
const BONUS = 10

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["While enhanced, first removes all Shield and Damage Reduction on that enemy, dealing 10 more damage for each that was removed (both can occur)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var enhanced = user.has_effect("Big Bang Dash", EffectType.Type.MARK, user) != null
	for target in user.targeter.targets:
		var dmg = BASE
		if enhanced:
			if target.shatter_shields(user) > 0:
				dmg += BONUS
			if not target.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION).is_empty():
				target.effects.full_remove_effect_by_type(EffectType.Type.DAMAGE_REDUCTION)
				dmg += BONUS
		Character.resolve_damage(context, target, dmg, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 40)

func target(user, battle):
	default_hostile_target_function(user, battle)
