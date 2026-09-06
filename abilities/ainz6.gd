extends Ability

var base_damage = 35

# Fallen Down (hidden reserve, base_abilities[5]). Swapped into slot 0 by Hold of Ribs while its
# Isolate/Shatter window is active. Uncounterable super-tier magic.

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 35 Piercing damage to target enemy",
		["+10 damage if the target is at full HP", Color.ORANGE_RED],
		["+5 damage for each time The Goal of all Life is Death has triggered", Color.ORANGE_RED],
	]

func _triggers(user) -> int:
	var m = user.has_effect("The Goal of all Life is Death", EffectType.Type.MARK, user)
	return int(m.stack_count()) if m else 0

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var dmg = base_damage + 5 * _triggers(user)
		if target.health.hp >= target.get_modified_max_hp():
			dmg += 10
		Character.resolve_damage(context, target, dmg, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 50)

func target(user, battle):
	default_hostile_target_function(user, battle)
