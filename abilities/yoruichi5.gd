extends Ability
var base_damage = 20

# Fickle Flash. The hidden slot-2 swap-in that Black Cat Warrior Princess hands her for 3 turns.
# It has no cooldown, so for that window it is a repeatable hit that punishes anyone already locked
# down by Gather's Paralyze by pushing one of their skills further out of reach.
#
# BYPASSING: the "Bypassing" ability CLASS is a display/serialization tag — it does NOT make an
# Invulnerable enemy selectable. Condition.can_hostile_target only skips the invuln check when the
# `bypassing` PARAMETER is true, so the 3rd argument in target() below is the entire mechanism.
# (byakuya7 is the shipped counter-example: classed Bypassing, promises a bypass in its text, and
# omits the argument — so it fizzles against invulnerability.)
#
# The other two classes on this skill DO carry weight: "Harmful" is what makes Taunt redirect it and
# the target's harmful-receive reactives fire, and "Damaging" is the internal flag Ability.
# is_silenced_out reads — without it a silenced Yoruichi could not use a pure damage skill.

func describe(user):
	return "Deals 20 Piercing damage to target enemy, bypassing Invulnerability. If they are Paralyzed, a random one of their skills has its remaining cooldown increased by 1."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy (Bypassing)",
		["If that enemy is Paralyzed, one of their skills at random has its remaining cooldown increased by 1", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Read before the hit: a lethal blow runs cleanse_death_effects synchronously, which strips
		# the Paralyze, so checking afterwards would silently drop the rider on a killing blow.
		var was_paralyzed: bool = target.paralyzed()
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		if not was_paralyzed or target.dead or target.banished:
			continue
		# get_active_abilities, NOT display_abilities: server-side the latter returns the target's
		# UN-swapped base slots, so a bump could land on a skill the enemy cannot even see, and on
		# a slot that is not the one serialized to the client.
		var valid_skills = []
		for ability in target.moveset.get_active_abilities(target):
			# A swap can point two display slots at the same Ability node; dedup so one skill is
			# not double-weighted in the roll.
			if ability != null and not valid_skills.has(ability):
				valid_skills.append(ability)
		if valid_skills.is_empty():
			continue
		# Any skill, not just ones already ticking: Gather's Paralyze FREEZES cooldowns rather than
		# creating them, so 0 -> 1 is exactly the lockout this is for.
		var roll = battle.roll(0, valid_skills.size() - 1, "Fickle Flash cooldown bump")
		valid_skills[roll].cooldown_remaining += 1

func extra_usable(user):
	return true

func custom_behavior(context):
	# bypass=true so the bot's candidate list matches what target() will actually accept — if the
	# two disagree the bot's pick is silently dropped.
	return behavior_single_target_damage(context, base_damage, 1.0, true)

func target(user, battle):
	default_hostile_target_function(user, battle, true)
