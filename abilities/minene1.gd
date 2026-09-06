extends Ability

# Grenade. Deals 15, applies one Explosives Detonator charge + a permanent Ticking Trigger that adds
# another charge each turn (until Explosives Detonator detonates), then temporarily becomes Explosives
# Detonator (hidden base_abilities[5]) for 1 turn. Detonator bookkeeping is centralized on the passive
# (base_abilities[4]): grant_detonator_stack = the initial charge, install_detonator_incrementer = the
# ticking trigger (guarded so it never stacks).

const DETONATOR = "Explosives Detonator"

func passive():
	return user.moveset.base_abilities[4]

func describe(user):
	return "Deals 15 damage to target enemy and applies 1 stack of Explosives Detonator, plus a permanent Ticking Trigger that adds 1 more stack each turn until Explosives Detonator is used. This continuous stack addition does not stack. Grenade is replaced by Explosives Detonator for 1 turn."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["Applies 1 stack of Explosives Detonator, plus a Ticking Trigger that adds 1 more stack each turn until Explosives Detonator is used; this continuous stack addition does not stack", Color.CADET_BLUE],
		["Grenade becomes Explosives Detonator for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
		passive().grant_detonator_stack(target, 1)
		passive().install_detonator_incrementer(target)
	var swap = Effect.ability_swap_effect(5, 0, user, 3)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 15)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
