extends Ability

# Spirit Shotgun. AoE blast that scales off both stack piles. Empowered stuns the primary target.

func describe(user):
	return "Deals 15 damage to all enemies. Deals 5 more damage per stack of Spirit Gun and 10 more per stack of Mega Spirit Gun on Yusuke. While Empowered, stuns the primary target for 1 turn."

func split_desc():
	return [
		"Deals 15 damage to all enemies",
		["Deals 5 more per stack of Spirit Gun and 10 more per stack of Mega Spirit Gun", Color.CADET_BLUE],
		["While Empowered: stuns the primary target for 1 turn", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.marked_by("Empowered", user)
	# Base 15; the "Spirit Shotgun" DAMAGE_MOD on Yusuke (fed +5/Spirit Gun stack, +10/Mega stack) adds the
	# rest through the engine, so the boost is a native, visible damage mod rather than an inline computation.
	var main = user.targeter.main_target
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
		if empowered and target == main:
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
	if empowered:
		user.effects.erase_effect(empowered)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 15, 1.0)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
