extends Ability

# Shambles. Law's signature swap, and the "novel" skill. It marks an enemy invisibly; the next skill
# THEY use is hijacked mid-cast and re-aimed — a Helpful skill onto Law's ROOM-marked ally (they end
# up healing/buffing the wrong side), a Harmful skill onto the ROOM-marked enemy (friendly fire on
# their own line).
#
# Mechanism: this is caster-side target surgery, so it rides the SAME rail as skill reflection — a
# REFLECT_USE effect on the marked enemy. reflect_check (character_component.gd) fires REFLECT_USE
# effects when their HOLDER uses a matching skill, gated by Condition.action_countered (here: Helpful
# or Harmful). The trigger then rewrites the caster's targeter, exactly as Ability.reflect_trigger
# does for a bounce — execute() runs afterward against whatever the targeter now holds.

func describe(user):
	return "Marks target enemy for 1 turn (Invisible). If that enemy uses a new Helpful skill, it will be redirected to only target the ally currently marked with ROOM. If they use a new Harmful skill, it will be redirected to only target the enemy currently marked with ROOM."

func split_desc():
	return [
		"Marks target enemy for 1 turn (Invisible)",
		["Their next Helpful skill is redirected to ONLY the ally marked with ROOM", Color.CADET_BLUE],
		["Their next Harmful skill is redirected to ONLY the enemy marked with ROOM", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# count = 1 => one-shot (fires on the first Helpful/Harmful skill, then consumes itself).
		var redirect = Effect.reflect_effect(
			Trigger.always(shambles_redirect),
			EffectType.Type.REFLECT_USE, -1, 2,
			"Shambles: this character's next Helpful/Harmful skill is redirected by Law.",
			["Helpful", "Harmful"], [], 1)
		redirect.set_source(self)
		redirect.invisible = true
		Character.add_hostile_effect(context, user, target, redirect)

func shambles_redirect(context):
	var caster = context['owner']          # the marked enemy, mid-cast
	var law = context['effect'].user
	var ability = caster.used_ability
	var room_ally = null
	var room_enemy = null
	for c in law.battle.all_characters():
		if c.dead or c.banished:
			continue
		if not c.marked_by("ROOM", law):
			continue
		if c in law.team.characters:
			room_ally = c
		else:
			room_enemy = c
	var dest = null
	if ability.classes["Helpful"]:
		dest = room_ally
	elif ability.classes["Harmful"]:
		dest = room_enemy
	if dest != null:
		caster.targeter.targets = [dest]
		caster.targeter.main_target = dest
		# One-shot consume, mirroring reflect_trigger — ONLY when the redirect actually fired. If the
		# relevant ROOM target is absent (dest null), keep the mark so it can still catch a later skill.
		if context['effect'].stacks != -1:
			var exp = Effect.invisible_expiration_effect(self, 2)
			exp.set_source(self)
			Character.add_allied_effect(context, context['effect'].user, context['effect'].target, exp)
			context['effect'].target.effects.erase_effect(context['effect'])

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_hostile(context, 35)

func target(user, battle):
	default_hostile_target_function(user, battle)
