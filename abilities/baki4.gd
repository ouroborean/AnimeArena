extends Ability

# Prehistoric Kenpo. Baki reads his opponent: he becomes Invulnerable for a turn and sets a counter on
# the first Harmful, non-Strategic skill used on him. Any enemy he counters is left open — they take 10
# more damage from Baki's skills for 2 turns (a VULNERABILITY keyed to Baki's ability names).
#
# NOTE (interpretation): the invuln and the counter both last 1 turn, matching the skill's "for one
# turn" framing. While Invulnerable, ordinary attacks can't target Baki, so in practice the counter
# punishes an enemy who reaches him with an invuln-BYPASSING Harmful skill.

func describe(user):
	return "Baki becomes Invulnerable for 1 turn, and counters the first Harmful, non-Strategic skill used on him. Countered enemies take 10 more damage from Baki's skills for 2 turns."

func split_desc():
	return [
		"Baki becomes Invulnerable for 1 turn",
		"Counters the first Harmful, non-Strategic skill used on him",
		["A countered enemy takes 10 more damage from Baki's skills for 2 turns", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_defend(user, battle)   # Invulnerable for 1 turn
	var counter = Effect.counter_effect(
		Trigger.always(kenpo_countered),
		EffectType.Type.COUNTER_RECEIVE, 2,
		"The first Harmful, non-Strategic skill used on Baki is countered.",
		["Harmful"], ["Strategic"])
	counter.wrapup_func = default_counter_timeout
	counter.set_source(self)
	Character.add_allied_effect(context, user, user, counter)

func kenpo_countered(context):
	# Fired from Character.countered(): owner is the attacker, context['effect'].user is Baki.
	var baki = context['effect'].user
	var attacker = context['owner']
	if not (baki.dead or baki.banished or attacker.dead or attacker.banished):
		var vuln = Effect.vulnerability_effect(10, 4, ["Whip Strike", "Light Speed Jab", "Tiger King"])
		vuln.set_source(self)
		# bypassing: land the vulnerability even if the attacker is currently Invulnerable.
		Character.add_hostile_effect(QueryContext.from_game_state(baki, baki.battle), baki, attacker, vuln, true)
	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 55)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
