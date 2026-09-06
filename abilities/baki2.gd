extends Ability

# Light Speed Jab. 35 uncounterable damage, and a full 1-turn stun that applies ONLY when the hit
# actually deals damage — not when fully absorbed by Shield / Damage Reduction / Nullify (read from the
# target's HP before vs after the hit, same as Whip Strike).

func describe(user):
	return "Deals 35 damage to target enemy. If the target takes damage from this skill, they are also Stunned for 1 turn."

func split_desc():
	return [
		"Deals 35 damage to target enemy",
		["If it deals damage, the target is Stunned for 1 turn", Color.CADET_BLUE],
		["Cannot be countered", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hp_before = target.health.hp
		Character.resolve_damage(context, target, 35, DamageType.Type.NORMAL)
		if target.health.hp < hp_before and not (target.dead or target.banished):
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
