extends Ability


func describe(user):
	return "Mavis becomes Invulnerable for 3 turns. During this time, she cannot act and gains 1 Random energy each turn. This skill can only be used if Mavis has targetable allies. While it is active, Fairy Star Strategy will not target her."


func split_desc():
	return [
		"Mavis gains 15 Shield for 3 turns",
		"During this time, she cannot act",
		"During this time, she gains 1 Random energy each turn",
		["Fairy Star Strategy will not target Mavis while active", Color.DIM_GRAY],
	]


func execute(user, battle):
	var context = make_context(battle)

	# Shield instead of Invulnerability: dur 6 == 3 turns, matching the lockout
	# mark and the energy ticker below, so all three end together.
	apply_allied(context, user, Effect.shield_effect(15, 6))

	# END_OF_TURN_TRIGGER fires once per round, only on the acting team's
	# turn-end. START_OF_TURN_TRIGGER fires twice per round in this engine
	# (once at top-of-round and once after the first player acts), which
	# would double-grant the energy.
	var ticker = Effect.trigger_effect(
		Trigger.always(fairy_heart_tick),
		EffectType.Type.TICKING_TRIGGER,
		6,
		"Mavis gains 1 Random energy at the end of each turn.")
	user.gain_random_energy()
	apply_allied(context, user, ticker)

	# This mark drives both the Fairy Star Strategy exclusion and the
	# per-ability extra_usable lockout in mavis1/2/3/4/6 — it is what
	# enforces "she cannot act" without using a stun (which would interact
	# with stun-immunity, control_cancel, etc.).
	var mark = Effect.mark(6, "Mavis is sealed inside Fairy Heart and cannot act or be targeted by Fairy Star Strategy.")
	apply_allied(context, user, mark)


func fairy_heart_tick(context):
	context['effect'].user.gain_random_energy()


func extra_usable(user):
	# The living-ally requirement is gone this patch; the only gate left is
	# "not already sealed inside Fairy Heart". mavis2.gd has an identical-looking
	# has_targetable_living_ally() clause that is NOT part of this change.
	return not user.marked_by("Fairy Heart")


func custom_behavior(context):
	return behavior_self_panic_button(context, 30)


func target(user, battle):
	default_self_target_function(user, battle)
