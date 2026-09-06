extends Ability

# Grand Challenge (White form swap-in — hidden index 4, pulled into slot 2 by Summon - Tank).
# Taunts the target enemy for 3 turns and every other enemy for 1 turn (they can only target Jin-woo).

func describe(user):
	return "Taunts target enemy for 3 turns and all other enemies for 1 turn."

func split_desc():
	return [
		"Taunts target enemy for 3 turns",
		["Taunts all other enemies for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for enemy in context['enemy_team'].characters:
		if enemy.dead or enemy.banished:
			continue
		var dur = 6 if enemy in user.targeter.targets else 2
		var taunt = Effect.taunt_effect(dur, user)
		taunt.set_source(self)
		Character.add_hostile_effect(context, user, enemy, taunt)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
