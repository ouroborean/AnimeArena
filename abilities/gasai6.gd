extends Ability

# Mow Down. Hidden base_abilities index 5; swapped into slot 1 by Breakdown (gasai2).

const DIARY = "Yukiteru Diary"

func describe(user):
	return "Deals 5 damage to all enemies for each stack of Yukiteru Diary on the field, consuming all stacks. Bypasses against enemies marked with Yukiteru Diary."

func split_desc():
	return [
		"Deals 5 damage to all enemies per stack of Yukiteru Diary on the field",
		["Consumes all stacks of Yukiteru Diary", Color.ORANGE_RED],
		["Bypasses enemies marked with Yukiteru Diary", Color.CADET_BLUE]
	]

func passive():
	return user.moveset.base_abilities[4]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dmg = 5 * passive().total_diary_stacks(battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, dmg, DamageType.Type.NORMAL)
	passive().consume_all_diary(battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 30, 1.0)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if character in user.team.characters:
			continue
		var bypass = character.marked_by(DIARY) != null
		check_hostile_target(user, character, context, bypass)
