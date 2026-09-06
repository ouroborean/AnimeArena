extends Ability

var base_damage = 25

func describe(user):
	return "Deals 25 damage to all enemies. Any enemy marked by Four Scythe Child is stunned for 1 turn, consuming the mark."

func split_desc():
	return [
		"Deals 25 damage to all enemies",
		["Marked enemies are stunned for 1 turn, consuming the mark", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var mark = target.marked_by("Four Scythe Child", user)
		if mark:
			# Stun the marked enemy for 1 turn
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
			# Consume mark unless Doji Manifestation is active
			if not user.marked_by("Doji Manifestation", user):
				target.effects.consume_effect(mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 30, 1.0)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
