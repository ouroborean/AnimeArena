extends Ability

# Death Barrier. Team-wide one-shot defensive counter: for 1 turn the FIRST Harmful skill used on ANY
# of Death's allies is countered (aborted). If it triggers, Death's whole team becomes Invulnerable for
# 1 turn (2 turns if an enemy has taxed this skill's cost to include Random energy).

# Snapshotted at cast time (server-authoritative in execute); cooldown 6 >> the 1-turn window so there is
# no overlapping cast to clobber it.
var _extended_invuln = false

func describe(user):
	return "For 1 turn, the first Harmful skill used on Death's team is countered. If it triggers, Death's team becomes Invulnerable for 1 turn (2 turns if this skill costs at least 1 Random energy)."

func split_desc():
	return [
		"For 1 turn, the first Harmful skill used on Death's team is countered",
		["If triggered, Death's team becomes Invulnerable for 1 turn", Color.CADET_BLUE],
		["Invulnerable for 2 turns instead if this skill costs at least 1 Random energy", Color.AQUAMARINE],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	_extended_invuln = cost()[Energy.Type.RANDOM] >= 1
	# target_type ALL(2) + default_allied_target_function -> targeter.targets == the whole ally team.
	for target in user.targeter.targets:
		var counter_eff = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "The first Harmful skill used on this character is countered; if it triggers, Death's team becomes Invulnerable.", ["Harmful"])
		counter_eff.set_source(self)
		counter_eff.invisible = true
		counter_eff.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, counter_eff)

func counter_trigger(context):
	var death = context['effect'].user
	# Abort the incoming skill + notify attacker + consume the hit ally's counter.
	default_counter_trigger(context)
	# One-shot ACROSS THE TEAM: strip the remaining counters off the other allies so a second Harmful
	# skill this turn isn't also countered (default_counter_trigger only consumed the hit ally's copy).
	for character in death.team.characters:
		character.effects.remove_effect(ability_name, EffectType.Type.COUNTER_RECEIVE, death)
	# Grant team-wide invulnerability. Durations are +1 over the usual 2/4 so that when the counter fires
	# mid-way through the OPPONENT'S turn, the invuln still ticks through the opponent's NEXT turn rather
	# than expiring a turn early (dur 3 = the 1-turn grant, dur 5 = the 2-turn grant).
	var invuln_dur = 5 if _extended_invuln else 3
	for character in death.team.characters:
		if character.dead or character.banished:
			continue
		var invuln = Effect.invuln_effect(invuln_dur)
		invuln.set_source(self)
		Character.add_allied_effect(context, death, character, invuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_helpful_aoe_aid(context, 60, 1.1)
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
