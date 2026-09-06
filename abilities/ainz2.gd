extends Ability

var base_damage = 20

# Astral Smite. Scales two ways: +5 per cumulative trigger of The Goal of all Life is Death, and +5 per
# EXTRA energy it currently costs.

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["+5 damage for each time The Goal of all Life is Death has triggered", Color.ORANGE_RED],
		["+5 damage for each extra energy this skill costs", Color.ORANGE_RED],
	]

func _extra_energy() -> int:
	var extra := 0
	var c = cost()
	for e in c:
		extra += c[e]
	for e in _cost:
		extra -= _cost[e]
	return max(0, extra)

func _triggers(user) -> int:
	var m = user.has_effect("The Goal of all Life is Death", EffectType.Type.MARK, user)
	return int(m.stack_count()) if m else 0

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dmg = base_damage + 5 * _triggers(user) + 5 * _extra_energy()
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, dmg, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 40)

func target(user, battle):
	default_hostile_target_function(user, battle)
