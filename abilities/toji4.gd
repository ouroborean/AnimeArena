extends Ability

# Chain of a Thousand Miles — 10 damage to all enemies, then Toji becomes cost-gated
# invulnerable for 1 turn: he can ONLY be targeted by skills that pay Green energy.
# The self-buff is independent of the AoE damage.

var base_damage = 10

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 10 damage to all enemies",
		["For 1 turn, Toji can only be targeted by skills that cost Green energy", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
	var invuln = Effect.cost_invuln_effect(2, Energy.Type.GREEN)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
