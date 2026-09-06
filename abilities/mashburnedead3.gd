extends Ability

# Hell Fall Knuckle (display slot 2). 25 damage. When enhanced (Big Bang Dash), first removes all
# Shield AND all Damage Reduction on the target, dealing 10 more for EACH category actually removed
# (both can occur -> up to +20). If the target has NEITHER Shield nor DR, it deals 10 more instead.

const BASE = 25
const BONUS = 10

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 25 damage to target enemy",
		["While enhanced, first removes all Shield and Damage Reduction on that enemy, dealing 10 more damage for each that was removed (both can occur)", Color.CADET_BLUE],
		["While enhanced, deals 10 more damage if the target has neither Shield nor Damage Reduction", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var enhanced = user.has_effect("Big Bang Dash", EffectType.Type.MARK, user) != null
	for target in user.targeter.targets:
		var dmg = BASE
		if enhanced:
			var has_shield = not target.get_shield_effects().is_empty()
			var has_dr = not target.get_effects_by_type(EffectType.Type.DAMAGE_REDUCTION).is_empty()
			if not has_shield and not has_dr:
				dmg += BONUS
			else:
				if target.shatter_shields(user) > 0:
					dmg += BONUS
				if has_dr:
					target.effects.full_remove_effect_by_type(EffectType.Type.DAMAGE_REDUCTION)
					dmg += BONUS
		Character.resolve_damage(context, target, dmg, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 45)

func target(user, battle):
	default_hostile_target_function(user, battle)
