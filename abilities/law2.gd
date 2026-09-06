extends Ability
var base_damage = 30

# Amputate. Law "targets himself" (SELF target_type) and the strike lands automatically on whichever
# enemy is currently wearing the ROOM mark. True damage, so it ignores DR/Shield (invuln still stops
# it — Amputate is not the bypass skill, Surgeon of Death is).

func describe(user):
	return "Law targets himself, then automatically deals 30 True damage to the enemy marked by ROOM."

func split_desc():
	return [
		"Law targets himself",
		"Automatically deals 30 True damage to the enemy marked with ROOM",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for enemy in _room_enemies(user):
		Character.resolve_damage(context, enemy, base_damage, DamageType.Type.TRUE)

func _room_enemies(user):
	var out = []
	for c in user.battle.all_characters():
		if c.dead or c.banished:
			continue
		if not (c in user.team.characters) and c.marked_by("ROOM", user) and not c.is_invuln(self):
			out.append(c)
	return out

func extra_usable(user):
	# Only after ROOM is up, and only when there is actually a ROOM-marked enemy to cut.
	return user.has_effect("ROOM", EffectType.Type.START_OF_TURN_TRIGGER, user) and not _room_enemies(user).is_empty()

func custom_behavior(context):
	var variations = []
	if not _room_enemies(user).is_empty():
		variations.append([120, [user, self, [user]]])
	else:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
