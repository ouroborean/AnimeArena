extends Ability

const DIARY = "Yukiteru Diary"

func describe(user):
	return "Deals 15 damage to target enemy, increased by 5 for each stack of Yukiteru Diary on Yuno and the target. If there are 3 or more such stacks, this skill deals Piercing damage and Bypasses the target if it is affected by Yukiteru Diary."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["+5 damage for each stack of Yukiteru Diary on Yuno and the target", Color.ORANGE_RED],
		["At 3+ combined stacks: becomes Piercing and Bypasses the marked target", Color.CADET_BLUE],
		["+5 damage while Breakdown is active", Color.CADET_BLUE]
	]

func passive():
	return user.moveset.base_abilities[4]

# Only Yuno's own stacks and the target's stacks count (each capped at 3 by the passive).
func _diary_stacks(character):
	var m = character.has_effect(DIARY, EffectType.Type.MARK)
	return m.stack_count() if m else 0

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var breakdown_bonus = 5 if passive().breakdown_active(user) else 0
	for target in user.targeter.targets:
		var stacks = _diary_stacks(user) + _diary_stacks(target)
		var dmg = 15 + 5 * stacks + breakdown_bonus
		var dtype = DamageType.Type.PIERCING if stacks >= 3 else DamageType.Type.NORMAL
		Character.resolve_damage(context, target, dmg, dtype)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var yuno_stacks = _diary_stacks(user)
	for character in battle.all_characters():
		if character in user.team.characters:
			continue
		var stacks = yuno_stacks + _diary_stacks(character)
		var bypass = stacks >= 3 and character.marked_by(DIARY) != null
		check_hostile_target(user, character, context, bypass)
