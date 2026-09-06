extends Ability
var base_damage = 30
var execute_threshold = 30

# Cleaving Light. The finisher form of Axe Smash: it appears on its own whenever anyone on the enemy
# side has dropped to 30 or under, and it kills anyone in that band outright rather than rolling
# damage against their defenses.
#
# The condition that summons it is evaluated in character/stark.gd, not here — one place decides
# which of the two swap-ins holds the slot, so they can never both claim it.
#
# Note the threshold is checked against the target's CURRENT HP at execute time, so an enemy healed
# out of the band between Stark picking the skill and it resolving correctly survives, taking the
# 30 instead.

func describe(user):
	return "Replaces Axe Smash whenever there is an enemy at 30 HP or less. Deals 30 Piercing damage to target enemy, or executes them if their HP is 30 or less."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy",
		["Executes that enemy instead if their health is 30 or less", Color.ORANGE_RED],
		["Replaces Axe Smash while any enemy is at 30 HP or less", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target.health.hp <= execute_threshold:
			target.execute_attempt(execute_threshold, user, self)
			continue
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		if character.is_invuln(self) or character.dead or character.banished:
			continue
		# A kill is worth far more than a hit, so surface the executable target loudly.
		var kill: int = 120 if character.health.hp <= execute_threshold else 0
		variations.append([100 + base_damage + kill, [user, self, [character]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
