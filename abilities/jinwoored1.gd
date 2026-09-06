extends Ability

# Vital Strike (Red form). 15 damage + a permanent, stacking +5 to all of Jin-woo's damage.

func describe(user):
	return "Deals 15 damage to target enemy. Jin-woo permanently deals +5 damage."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["Jin-woo permanently deals +5 damage (stacks)", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
	var buff = Effect.damage_mod_effect(5, -1)
	buff.set_source(self)
	buff.stackable = true
	buff.stack_mag = true
	buff.display_stacks = true
	Character.add_allied_effect(context, user, user, buff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 15)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
