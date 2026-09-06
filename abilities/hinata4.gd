extends Ability

# My Turn To Protect — a plain Harmful counter placed on an ally.
#
# REWORKED (patch 2026-08-02). It used to plant a permanent invisible pair of triggers on the ally
# (DAMAGE_RECEIVE_TRIGGER watching for HP < 30, plus STUN_RECEIVED_TRIGGER) and fire on whichever
# landed first, gated once per match by a `used` flag. That whole mechanism is gone: this is now the
# standard COUNTER_RECEIVE idiom (see gasai3.gd / adam2.gd), so it INTERCEPTS the enemy's skill
# outright instead of reacting after the damage or stun has already landed.
#
# What deliberately did NOT change: the countered enemy is still taunted PERMANENTLY, and firing
# still swaps this slot to Gentle Step: Twin Lions Fist permanently. The ALLY target is also kept —
# the rework replaces the trigger mechanism, not who Hinata protects, which is what the skill's name
# is about.
#
# The `used` flag is gone with the old mechanism: a cooldown of 2 (abilities_data.json) now governs
# re-use. That only matters before it fires, since firing swaps the skill away for good.

func describe(user):
	return ""

func split_desc():
	return [
		"For 1 turn, counters the next Harmful skill used on target ally",
		["The countered enemy is permanently Taunted", Color.ORANGE_RED],
		["This skill is then permanently replaced by Gentle Step: Twin Lions Fist", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter = Effect.counter_effect(
			Trigger.always(protect_counter),
			EffectType.Type.COUNTER_RECEIVE,
			2,
			"The next Harmful skill used on this character is countered. Hinata will permanently taunt the countered enemy.",
			["Harmful"]
		)
		# Without this the counter lingers past the turn it was bought for — every shipped counter
		# pairs the 2-tick duration with the timeout wrapup.
		counter.wrapup_func = default_counter_timeout
		# Invisible, like most counters (adam2 / gasai3 idiom): hides the counter MARKER from the
		# opponent. The paired "Invisible" ability class (abilities_data.json + ability_info.json) hides
		# the skill's USE too — both layers are needed for a fully hidden counter.
		counter.invisible = true
		counter.set_source(self)
		Character.add_allied_effect(context, user, target, counter)

# Fired from Character.countered(): context['owner'] is the ATTACKER whose skill was intercepted,
# context['effect'].user is Hinata (she applied the counter, so she owns it even on an ally).
func protect_counter(context):
	var hinata = context['effect'].user
	var enemy = context['owner']
	if hinata == null or enemy == null:
		return
	if hinata.dead or hinata.banished:
		return
	# A counter can only be triggered by a hostile skill, but the guard is cheap and mirrors the
	# check the old triggers carried.
	if hinata in enemy.team.characters:
		return
	var new_context = QueryContext.from_game_state(hinata, hinata.battle)
	var taunt = Effect.taunt_effect(-1, hinata)
	taunt.set_source(self)
	Character.add_hostile_effect(new_context, hinata, enemy, taunt)
	# Permanent swap of THIS slot (index 3) to Gentle Step: Twin Lions Fist (base_abilities[4]).
	var swap = Effect.ability_swap_effect(4, 3, hinata, -1)
	swap.set_source(self)
	Character.add_allied_effect(new_context, hinata, hinata, swap)
	# Consume the counter so it only intercepts the NEXT Harmful skill (one-shot), not every Harmful
	# skill used on the ally for the rest of the duration-2 window. default_counter_trigger notifies the
	# opponent AND removes the counter effect from the ally — the gasai3 Harmful-path idiom. Without this
	# the counter lingered and re-fired on every subsequent hit that turn.
	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []

	variations += behavior_single_target_selfless_helpful(context, 75)

	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
