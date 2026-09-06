extends Ability

func describe(user):
	return "For 2 turns, any enemy that uses a Harmful skill on Jeanne receives 20 damage."

func split_desc():
	return [
		"For 2 turns, any enemy that uses a Harmful skill on Jeanne takes 20 damage",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var retal = Effect.trigger_effect(
		Trigger.always(shamash_retal),
		EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
		4,
		"Enemies that use Harmful skills on Jeanne take 20 damage.")
	retal.set_source(self)
	Character.add_allied_effect(context, user, user, retal)

func shamash_retal(context):
	var jeanne = context['effect'].user
	var attacker = context['owner']
	if attacker == null or attacker.dead or attacker.banished:
		return
	if not jeanne.is_hostile(attacker):
		return

	var stored = jeanne.used_ability
	jeanne.used_ability = self
	Character.resolve_damage(QueryContext.from_game_state(jeanne, jeanne.battle), attacker, 20, DamageType.Type.NORMAL)
	jeanne.used_ability = stored

func extra_usable(user):
	if user.has_effect("Iron Maiden", EffectType.Type.MARK, user):
		return false
	return not user.has_effect("Shamash Judgment", EffectType.Type.HARMFUL_RECEIVE_TRIGGER, user)

func custom_behavior(context):
	return behavior_self_panic_button(context, 25, 1.1)

func target(user, battle):
	default_self_target_function(user, battle)
