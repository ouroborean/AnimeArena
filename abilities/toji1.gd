extends Ability

# Split Soul Katana — 40 Piercing damage to one enemy and stun their Green-costing skills.
# Cost/cooldown/classes/target_type come from abilities_data.json via Ability.from_database.

var base_damage = 40

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 40 Piercing damage to target enemy",
		["Stuns their skills that cost Green energy for 2 turns", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var stun = Effect.cost_stun_effect(4, Energy.Type.GREEN)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 75)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
