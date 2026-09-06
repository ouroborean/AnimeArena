extends Ability

# Explosives Detonator. Hidden base_abilities[5]; swapped into slot 0 by Grenade (minene1) or slot 1 by
# Landmines (minene2) for 1 turn. Detonates every Explosives Detonator charge on the field. The detonate
# helper is shared with the passive's on-death trigger (base_abilities[4].detonate).

const DETONATOR = "Explosives Detonator"

func passive():
	return user.moveset.base_abilities[4]

func describe(user):
	return "Deals 10 damage to each enemy marked with Explosives Detonator for every stack they carry, then removes the marks. Bypasses invulnerability."

func split_desc():
	return [
		"Deals 10 damage per stack to every enemy marked with Explosives Detonator",
		["Consumes all Explosives Detonator marks", Color.ORANGE_RED],
		["Bypasses invulnerability", Color.CADET_BLUE]
	]

func execute(user, battle):
	passive().detonate(user, battle)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 40, 1.0, true)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if character in user.team.characters:
			continue
		if character.marked_by(DETONATOR, user) == null:
			continue
		check_hostile_target(user, character, context, true)
