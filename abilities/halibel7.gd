extends Ability

var base_damage = 25
var dot_damage = 5
var dot_duration_short = 4
var dot_duration_long = 6

func describe(user):
	return "Halibel pierces target enemy for 25 Piercing damage and engulfs them in scalding water, dealing 5 Affliction damage per turn for 2 turns. While Halibel is below max HP, the DOT lasts 3 turns instead."

func split_desc():
	return [
		"Deals 25 Piercing damage to target enemy.",
		"Applies Hirviendo: 5 Affliction damage per turn for 2 turns.",
		["Hirviendo lasts 3 turns instead while Halibel is below max HP.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var wounded = user.health.hp < user.health.max_hp
	var dur = dot_duration_long if wounded else dot_duration_short
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var dot = Effect.damage_effect(dot_damage, DamageType.Type.AFFLICTION, dur)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 10, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
