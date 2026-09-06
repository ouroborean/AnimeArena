extends Ability

# Escape Route. Minene guards herself for 1 turn — a full invuln when badly hurt (hp < 70), otherwise
# invuln to non-Strategic skills. apply_escape_route is exposed so the passive's engine-triggered path
# (on_escape_diary_consumed, after a big hit is absorbed by Escape Diary) can re-cast it for free.

func apply_escape_route(minene):
	if minene == null or not is_instance_valid(minene):
		return
	var context = QueryContext.from_game_state(minene, minene.battle)
	var invuln
	if minene.health.hp < 70:
		invuln = Effect.invuln_effect(2)
	else:
		invuln = Effect.invuln_effect(2, [], ["Strategic"])
	invuln.set_source(self)
	Character.add_allied_effect(context, minene, minene, invuln)

func describe(user):
	return "Minene becomes invulnerable to non-Strategic skills for 1 turn. If her health is below 70, she becomes fully invulnerable instead."

func split_desc():
	return [
		["Minene becomes invulnerable to non-Strategic skills for 1 turn", Color.CADET_BLUE],
		["If Minene's health is below 70, she becomes fully invulnerable instead", Color.CADET_BLUE]
	]

func execute(user, battle):
	apply_escape_route(user)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 40)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
