extends Ability

var base_damage = 5
var weakness_amount = -5
var weakness_duration = 3
var discount_duration = 3

func describe(user):
	return "Deals 5 damage to all enemies and reduces their non-Affliction damage by 5 for 1 turn. The following turn, this skill will cost 1 Random energy."

func split_desc():
	return [
		"Deals 5 damage to all enemies.",
		"Damaged enemies deal 5 less non-Affliction damage for 1 turn.",
		["The following turn, this skill costs 1 Random energy instead of 1 Red.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.ENERGY)
		var weakness = Effect.damage_mod_effect(weakness_amount, weakness_duration, [], [], [], [DamageType.Type.AFFLICTION])
		weakness.set_source(self)
		Character.add_hostile_effect(context, user, target, weakness)

	var discount = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, discount_duration, ["Explosive Aura"])
	discount.set_source(self)
	Character.add_allied_effect(context, user, user, discount)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 30, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
