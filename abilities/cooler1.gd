extends Ability

var base_damage = 30
var hp_threshold = 50

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 30 damage to target enemy. For 1 turn, that enemy is marked and this skill swaps to Sadistic Tread."

func split_desc():
	return [
		"Deals 30 damage to target enemy",
		"Marks them and swaps to Sadistic Tread for 1 turn",
		["Hitting a Stunned target, or dropping a target below 50 HP, triggers Final Form (see Cruel Transformation)", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# cooler6 (passive) hosts the Final Form helper. base_abilities[5] is stable
	# regardless of the slot-0 swap that this ability installs.
	var transformation = user.moveset.base_abilities[5]

	for target in user.targeter.targets:
		# Snapshot Cruel Transformation pre-conditions BEFORE Death Chaser's
		# damage lands. "Stunned target" means stunned at the moment the hit
		# arrives; "drops below 50" means the hit takes them across the 50 HP
		# threshold (already-low targets don't re-trigger).
		var was_stunned = target.is_stunned(self)
		var pre_hp = target.health.hp

		Character.resolve_damage(context, target, base_damage, DamageType.Type.PHYSICAL)

		var mark = Effect.mark(3, "This character is marked by Death Chaser.")
		mark.set_source(self)
		mark.refresh = true
		Character.add_hostile_effect(context, user, target, mark)

		var dropped_below = pre_hp >= hp_threshold and target.health.hp < hp_threshold
		if was_stunned or dropped_below:
			transformation.enter_final_form(context, user)

	# Slot 4 (cooler5 = Sadistic Tread) takes over slot 0's button for 1 turn.
	# refresh=true so Sadistic Tread can extend it on use.
	var swap = Effect.ability_swap_effect(4, 0, user, 3)
	swap.set_source(self)
	swap.refresh = true
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
