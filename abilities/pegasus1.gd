extends Ability

var base_damage = 20
var tick_damage = 20

func describe(user):
	return "Pegasus deals 20 damage to target enemy for 2 turns. This skill bypasses Invulnerability."

func split_desc():
	return [
		"Deals 20 damage to target enemy for 2 turns (Bypasses)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var dot = Effect.damage_effect(tick_damage, DamageType.Type.NORMAL, 4)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 0, 1.0, true)

func target(user, battle):
	default_hostile_target_function(user, battle, true)
