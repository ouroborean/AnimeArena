extends Ability

# Demon King's Longsword (Red form swap-in — hidden index 4, pulled into slot 2 by Summon - Igris).
# 35 damage + a permanent, stacking +10 to all of Jin-woo's damage.

func describe(user):
	return "Deals 35 damage to target enemy. Jin-woo permanently deals +10 damage."

func split_desc():
	return [
		"Deals 35 damage to target enemy",
		["Jin-woo permanently deals +10 damage (stacks)", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 35, DamageType.Type.NORMAL)
	var buff = Effect.damage_mod_effect(10, -1)
	buff.set_source(self)
	buff.stackable = true
	buff.stack_mag = true
	buff.display_stacks = true
	Character.add_allied_effect(context, user, user, buff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
