extends Ability

const DIARY = "Yukiteru Diary"

func describe(user):
	return "Yuno or target ally marked by Yukiteru Diary becomes Invulnerable for 1 turn. If Yuno has 2 or more stacks of Yukiteru Diary, she becomes Invulnerable even if this targets an ally."

func split_desc():
	return [
		"Yuno or a Yukiteru Diary-marked ally becomes Invulnerable for 1 turn",
		["If Yuno has 2+ stacks, she also becomes Invulnerable when this targets an ally", Color.CADET_BLUE]
	]

func yuno_stacks(user):
	var m = user.marked_by(DIARY)
	return m.stack_count() if m else 0

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var inv = Effect.invuln_effect(2)
		inv.set_source(self)
		Character.add_allied_effect(context, user, target, inv)
		if target != user and yuno_stacks(user) >= 2:
			var self_inv = Effect.invuln_effect(2)
			self_inv.set_source(self)
			Character.add_allied_effect(context, user, user, self_inv)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 45, 1.0)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	check_allied_target(user, user, context)   # Yuno herself is always eligible
	for ally in user.team.characters:
		if ally == user:
			continue
		if ally.marked_by(DIARY):
			check_allied_target(user, ally, context)
