extends Ability
var base_damage = 10

func describe(user):
	return "Deals 10 damage to all enemies for 2 turns. If this skill is countered, Impmon heals 15 HP."

func split_desc():
	return [
		"Deals 10 damage to all enemies for 2 turns",
		["If this skill is countered, Impmon heals 15 HP", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.ENERGY)
		# "lasts 2 turns": the opening hit above plus one more next turn (immediate + dur 2N-1 idiom).
		var dot = Effect.damage_effect(base_damage, DamageType.Type.ENERGY, 3)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 30, 1.1)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
