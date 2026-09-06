extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 25 damage to an enemy marked by Death Chaser and stuns them for 1 turn. Refreshes the duration of the mark and Sadistic Tread's swap effect."

func split_desc():
	return [
		"Requires an enemy marked by Death Chaser",
		"Deals 25 damage and Stuns them for 1 turn",
		["Refreshes the duration of Death Chaser's mark and swap effects", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Source the refreshed mark and swap from cooler1 (Death Chaser) so the
	# existing effects (which were applied with source=cooler1 and refresh=true)
	# match by effect_name and get replaced cleanly by add_effect's refresh path.
	var death_chaser = user.moveset.base_abilities[0]

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 25, DamageType.Type.PHYSICAL)

		var stun = Effect.stun_effect(2)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

		var fresh_mark = Effect.mark(3, "This character is marked by Death Chaser.")
		fresh_mark.set_source(death_chaser)
		fresh_mark.refresh = true
		Character.add_hostile_effect(context, user, target, fresh_mark, true)

	# Reset the slot-0 swap so Sadistic Tread stays available another turn.
	var fresh_swap = Effect.ability_swap_effect(4, 0, user, 3)
	fresh_swap.set_source(death_chaser)
	fresh_swap.refresh = true
	Character.add_allied_effect(context, user, user, fresh_swap)

func extra_usable(user):
	# Only usable if at least one enemy still wears the Death Chaser mark.
	for character in user.battle.all_characters():
		if user.is_hostile(character) and character.has_effect("Death Chaser", EffectType.Type.MARK, user):
			return true
	return false

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_single_require_mark(context, "Death Chaser", EffectType.Type.MARK, 100)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, false, "Death Chaser")
