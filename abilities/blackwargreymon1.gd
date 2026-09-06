extends Ability

const TORNADO = "Black Tornado"

func describe(user):
	return "Deals 10 Piercing damage to target enemy and caps their damage at 20 for 1 turn. Lasts 2 turns against enemies affected by Black Tornado."

func split_desc():
	return [
		"Deals 10 Piercing damage to target enemy",
		["Caps the target's damage at 20 for 1 turn", Color.CADET_BLUE],
		["Lasts 2 turns against enemies affected by Black Tornado", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.PIERCING)
		# Black Tornado applies a same-named ACTION_USE_TRIGGER, so its presence == "affected by it".
		var dur = 4 if target.has_effect(TORNADO, EffectType.Type.ACTION_USE_TRIGGER, user) else 2
		var cap = Effect.damage_cap(20, dur)
		cap.set_source(self)
		Character.add_hostile_effect(context, user, target, cap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 10)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
