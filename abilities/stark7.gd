extends Ability
var base_damage = 30
var stun_duration = 4

# Lightning Strike. The control form of Axe Smash. It becomes available because SOMEONE on the enemy
# side is Stunned — but it does not have to be used on them: aimed at a fresh enemy it stuns, and
# aimed at one already Stunned it hits for 30 instead. So one stun on the board opens a chain.
#
# It takes PRIORITY over Cleaving Light when both conditions hold (owner ruling). That contest is
# settled in character/stark.gd, which only ever keeps one swap live.
#
# Stun duration 4, not 2. Stark casts on his own turn, so the stun has to survive: end of his turn
# (4 -> 3), the enemy's turn — the one they lose — (3 -> 2), his next turn (2 -> 1), and it expires
# at the end of the enemy's following turn. Duration 2 would tick out before they ever missed a turn.

func describe(user):
	return "Replaces Axe Smash whenever there is a Stunned enemy, taking priority over Cleaving Light. Stuns target enemy for 2 turns, or deals 30 Piercing damage to them if they are already Stunned."

func split_desc():
	return [
		"Stuns target enemy for 2 turns",
		["Deals 30 Piercing damage instead if that enemy is already Stunned", Color.ORANGE_RED],
		["Replaces Axe Smash while any enemy is Stunned, taking priority over Cleaving Light", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# is_stunned takes the skill being attempted; pass this one so a stun that only blocks
		# certain classes is judged against what Stark is actually doing.
		if target.is_stunned(self):
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
			continue
		var stun = Effect.stun_effect(stun_duration)
		apply_hostile(context, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		if character.is_invuln(self) or character.dead or character.banished:
			continue
		# Finishing a stunned enemy is damage; stunning a fresh one is tempo. Prefer spreading the
		# lockdown unless the stunned target is nearly dead.
		if character.is_stunned(self):
			variations.append([100 + base_damage, [user, self, [character]]])
		else:
			variations.append([120, [user, self, [character]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
