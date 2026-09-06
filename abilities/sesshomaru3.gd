extends Ability

# Whip of Light. 15 Piercing + a 1-turn Blind. Against enemies affected by Destructive Corrosion it also
# pierces Invulnerability — done entirely in target(): invuln is filtered at targeting (_drop_invuln_targets
# re-runs this target()), so offering an invuln DC-affected enemy with bypass=true both selects it AND lets
# the damage land, while a non-affected invulnerable enemy stays unselectable.

func describe(user):
	return "Deals 15 Piercing damage to target enemy and Blinds them for 1 turn. Bypasses Invulnerability against enemies affected by Destructive Corrosion."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy and Blinds them for 1 turn",
		["Bypasses Invulnerability against enemies affected by Destructive Corrosion", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dc = user.moveset.base_abilities[5]
	for target in user.targeter.targets:
		# Bypass the target's Invulnerability for the WHOLE skill (damage AND Blind) when it is corroded —
		# targeting bypass only lets the damage land; the effect-application layer needs its own bypass flag.
		var bypass = dc.is_affected(target, user)
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
		var blind = Effect.blind_effect(2)
		blind.set_source(self)
		Character.add_hostile_effect(context, user, target, blind, bypass)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 15)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dc = user.moveset.base_abilities[5]
	for character in battle.all_characters():
		# Bypass Invulnerability only for DC-affected enemies; non-affected invuln enemies stay unselectable.
		check_hostile_target(user, character, context, dc.is_affected(character, user))
