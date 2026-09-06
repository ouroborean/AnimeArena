extends Ability

func describe(user):
	return "Reflects all Harmful skills that target Katara back at their caster for 1 turn. Does not interrupt Channeling."

func split_desc():
	return [
		"Reflects all Harmful skills targeting one ally for 1 turn.",
		["Does not interrupt active Channeling.", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = make_context(battle)
	for target in user.targeter.targets:
		var reflect = Effect.reflect_effect(Trigger.always(reflect_trigger), EffectType.Type.REFLECT_RECEIVE, user, 2, "Harmful skills targeting this character reflect back at their caster.", ["Harmful"])
		reflect.set_source(self)
		reflect.invisible = true
		reflect.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, reflect)

func reflect_trigger(context):
	var attacker = context['owner']
	var tt = attacker.used_ability.target_type()
	if tt == TargetType.Type.SINGLE:
		attacker.targeter.targets.erase(context['target'])
		attacker.targeter.targets.append(attacker)
	elif tt != TargetType.Type.SELF:
		# AoE reflected back to its caster: re-aim onto the attacker's team.
		var valid = reflect_retarget_to_team(attacker)
		attacker.targeter.targets = valid
		attacker.targeter.main_target = valid[0]

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 10, 0.5)

func target(user, battle):
	# Allied targeting, NOT default_self_target_function - that helper passes bypassing=true,
	# so it would keep letting an isolated Katara shield herself. The owner ruled she may not
	# (Q19), and the same ruling gives this skill the Helpful class in abilities_data.json.
	# No engine change needed for the ally case: reflect_check reads REFLECT_RECEIVE off each
	# of the attacker's targets, wherever the effect happens to sit.
	default_allied_target_function(user, battle)
