extends Ability
var base_damage = 20
var base_heal = 25

# Surgeon of Death. A dual-purpose scalpel: 20 True damage to an enemy, or 25 healing to an ally.
# It can reach through Invulnerability, but ONLY against a target currently marked with ROOM — that
# bypass is applied in target() (invuln is enforced at targeting; resolve_damage does not re-check).

func describe(user):
	return "Deals 20 True damage to target enemy or heals target ally 25 HP. Bypasses invulnerability against targets marked by ROOM."

func split_desc():
	return [
		"Deals 20 True damage to target enemy, or heals target ally 25 HP",
		["Bypasses Invulnerability against a target marked with ROOM", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			if target.is_isolated() and target.marked_by("ROOM", user):
				# ROOM reaches through Isolation, which would otherwise make resolve_healing a no-op.
				var mod = user.used_ability.get_true_healing(user, target, base_heal)
				battle.log_healing(user, target, mod, user.used_ability)
				user.give_ability_healing(user.used_ability, mod, target)
			else:
				Character.resolve_healing(context, target, base_heal)
		else:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.TRUE)

func extra_usable(user):
	return user.has_effect("ROOM", EffectType.Type.START_OF_TURN_TRIGGER, user)

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 40)
	variations += behavior_single_target_helpful(context, 20)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# ROOM is Law's operating theatre: a ROOM-marked target is reachable through the protection that
	# would normally block it — Invulnerability on an enemy, Isolation on an ally.
	for c in battle.all_characters():
		if c in user.team.characters:
			check_allied_target(user, c, context, c.marked_by("ROOM", user))
		else:
			check_hostile_target(user, c, context, c.marked_by("ROOM", user))
