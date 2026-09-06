extends Ability
var used = false
func describe(user):
	return "Lyserg permanently targets an ally. If the target takes new damage that would kill them, they instead become Immortal until the end of the turn and Lyserg deals 35 damage to the enemy that is targeting them. This effect can only be used once."

func split_desc():
	return [
		"Lyserg permanently targets an ally",
		"If the target would be killed by new damage, that damage is prevented",
		"Lyserg deals 35 damage to the enemy targeting them",
		["Can only be used once per game", Color.DIM_GRAY],
	]

func execute(user, battle):
	used = true
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var protect = Effect.mark(-1, "Protected by Heavenly Intervention — one save available.")
		protect.set_source(self)
		protect.invisible = true
		protect.wrapup_func = default_counter_timeout
		protect.cleansable = false
		Character.add_allied_effect(context, user, target, protect)

func extra_usable(user):
	if used:
		return false
	if user.has_effect("Heavenly Intervention", EffectType.Type.MARK, user):
		return false
	for ally in user.team.characters:
		if ally.has_effect("Heavenly Intervention", EffectType.Type.MARK, user):
			return false
	return true

func custom_behavior(context):
	return behavior_single_target_helpful(context, 40)

func target(user, battle):
	default_allied_target_function(user, battle)
