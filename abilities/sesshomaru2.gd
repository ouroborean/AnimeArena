extends Ability

# Poison Claw. 15 Affliction now (+5 if the target is already affected by Destructive Corrosion), then a
# 10-Affliction DoT for the next 2 turns. The immediate hit is the 15/20; the damage_effect covers only the
# two future ticks (jack2 idiom: an immediate resolve_damage plus a separate DoT effect).

func describe(user):
	return "Deals 15 Affliction damage to target enemy, then 10 Affliction damage each turn for 2 turns. If the target is affected by Destructive Corrosion, deals 5 more initial damage."

func split_desc():
	return [
		"Deals 15 Affliction damage to target enemy, then 10 Affliction damage each turn for 2 turns",
		["Deals 5 more initial damage if the target is affected by Destructive Corrosion", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dc = user.moveset.base_abilities[5]
	for target in user.targeter.targets:
		var initial = 15
		if dc.is_affected(target, user):
			initial += 5
		Character.resolve_damage(context, target, initial, DamageType.Type.AFFLICTION)
		# 10 Affliction on each of the next 2 turns (dur 5 = 2 future ticks; the initial hit is separate).
		var dot = Effect.damage_effect(10, DamageType.Type.AFFLICTION, 5)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
