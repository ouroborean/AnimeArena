extends Ability

const TUMBLE := "Tumble"

# To The Rescue. Stark throws himself in front of one ally for a turn: any Harmful skill aimed at
# them is re-aimed at him, and he cannot die while doing it. Every skill he catches this way hands
# Tumble back, so a turn spent covering someone also buys the escape that follows.
#
# The guardian is the shipped REFLECT_RECEIVE idiom (marco3), with one difference: marco3 passes -1
# as the reflect target, which bounces the skill back at its caster. Passing STARK instead makes
# Ability.reflect_trigger re-aim the skill onto him — the guardian branch rather than the bounce
# branch. count = -1 so it catches every Harmful skill during the turn rather than just the first.
#
# NOTE: reflect_trigger only re-aims SINGLE-target skills. A multi-target Harmful skill returns
# early and is not redirected — the ally takes it alongside everyone else. That is the engine's
# existing guardian rule and it is why this reads "skills used on one ally".

func describe(user):
	return "For 1 turn, Stark reflects Harmful skills used on one ally onto himself and is Immortal. Reflecting a skill this way resets Tumble's cooldown."

func split_desc():
	return [
		["For 1 turn, Harmful skills used on target ally are redirected onto Stark", Color.CADET_BLUE],
		["Stark is Immortal for that turn", Color.LIGHT_GREEN],
		["Each skill redirected this way resets Tumble's cooldown", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var guard = Effect.reflect_effect(
			Trigger.always(rescue_trigger), EffectType.Type.REFLECT_RECEIVE, user, 2,
			"Harmful skills used on this character will be redirected onto Stark.",
			["Harmful"], [], -1)
		guard.set_source(self)
		Character.add_allied_effect(context, user, target, guard)
	# Immortal for the same window: catching the whole team's damage is only a plan if it cannot
	# kill him outright.
	apply_allied(context, user, Effect.immortality_effect(2))

func rescue_trigger(context):
	var stark = context['effect'].user
	var attacker = context['owner']
	# reflect_trigger RETURNS WITHOUT RE-AIMING for any non-SINGLE-target skill (the guardian branch
	# in ability_component.gd), so "reflecting a skill this way" has to be measured, not assumed --
	# otherwise a multi-target Harmful skill that merely clips the guarded ally would refund Tumble
	# while the ally still ate it.
	var covered_before: bool = attacker != null and stark in attacker.targeter.targets
	reflect_trigger(context)
	if stark == null or not is_instance_valid(stark) or stark.moveset == null:
		return
	if attacker == null or covered_before or not stark in attacker.targeter.targets:
		return
	# Reset Tumble by NAME, not by index: a copied or stolen To The Rescue runs from a caster whose
	# slot 3 is not Tumble, and base_abilities[3] would silently reset the wrong skill.
	for ability in stark.moveset.base_abilities:
		if ability != null and ability.ability_name == TUMBLE:
			ability.cooldown_remaining = 0
			return

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	for ally in context['ally_team'].characters:
		if ally.dead or ally.banished:
			continue
		if ally == user:
			continue
		# Worth most on a fragile ally, since that is who a redirect actually saves.
		variations.append([25 + int((100 - ally.health.hp) * 0.4), [user, self, [ally]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
