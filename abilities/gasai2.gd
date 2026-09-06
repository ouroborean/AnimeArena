extends Ability

# Breakdown. Flags Yuno with a "Breakdown" mark (read by gasai1 / gasai5) and swaps the hidden Mow Down
# (base_abilities index 5) into this slot (index 1) while active.

func describe(user):
	return "For 3 turns, Yukiteru Diary cannot be removed from or expire on any target. During this time, Axe Crazy deals 5 more damage and this skill is replaced by Mow Down."

func split_desc():
	return [
		["For 3 turns, Yukiteru Diary cannot be removed from or expire on any target", Color.CADET_BLUE],
		["Axe Crazy deals +5 damage while active", Color.ORANGE_RED],
		["Swaps to Mow Down while active", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Swap Mow Down (hidden base_abilities[5]) into this slot for 3 turns. gasai5.breakdown_active()
	# keys the "cannot be removed" lock and Axe Crazy's +5 off this swap's presence, so the lock,
	# the damage bonus, and Mow Down's availability can never desync.
	var swap = Effect.ability_swap_effect(5, 1, user, 7)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
