extends Ability

# The Goal of all Life is Death (PASSIVE). The negation itself lives in character/ainz.gd
# (negate_harmful_effect); this ability plants the cumulative trigger counter that override advances,
# which Astral Smite and Fallen Down read for their +5-per-trigger scaling.

func describe(user):
	return ""

func split_desc():
	return [
		"Whenever Ainz is targeted by a negative non-damage effect, he negates it",
		["The first negation each turn raises all his skills' cost by 1 Random for 3 turns", Color.CADET_BLUE],
		["Astral Smite and Fallen Down deal +5 damage for each such trigger", Color.ORANGE_RED],
	]

func execute(user, battle):
	# Idempotent (startup_passives runs once): plant the permanent, cleanse-proof trigger counter.
	if user.has_effect(ability_name, EffectType.Type.MARK, user) != null:
		return
	var context = QueryContext.from_game_state(user, battle)
	var counter = Effect.mark(-1, func(eff): return "The Goal of all Life is Death has triggered " + str(int(eff.stack_count())) + " time(s).")
	counter.set_source(self)
	counter.stackable = true           # a permanent STACKING effect — one stack per passive trigger
	counter.display_stacks = true
	counter.stacks = 0
	counter.system = true              # keep death-cleanse survival semantics
	counter.display_system = true      # but serialize it to BOTH players so the triggered count is visible
	counter.remove_on_death = false
	counter.cleansable = false
	Character.add_allied_effect(context, user, user, counter)

func extra_usable(user):
	return true

func custom_behavior(context):
	return []

func target(user, battle):
	default_self_target_function(user, battle)
