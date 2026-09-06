extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 30 damage to target enemy and permanently marks them",
		["On the third turn, permanently swaps to Kirin", Color.AQUAMARINE],
		["Kirin swaps back to Great Dragon Fire once it has been used", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.NORMAL)
		# Permanent (-1): the Kirin swap is now permanent too, so the mark that
		# Kirin reads for its +10 has to outlive any fixed window or the bonus
		# becomes unreachable on a slow game.
		var mark = Effect.mark(-1, "This character has been marked by Great Dragon Fire.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
	var delay = Effect.empty(4, "Great Dragon Fire will swap to Kirin.")
	delay.set_source(self)
	delay.invisible = true
	delay.wrapup_func = apply_kirin_swap
	Character.add_allied_effect(context, user, user, delay)

func apply_kirin_swap(context):
	var sasuke = context['effect'].user
	# Kirin is single-use and its "Kirin has been used" mark is permanent, so once it is
	# spent the swap must never be re-armed: sasuke6 hands the slot back on use, but a
	# second Great Dragon Fire would otherwise re-install a PERMANENT swap to a skill
	# extra_usable() refuses forever - exactly the "plays on with 3 skills" state the
	# owner ruled out (Q28), just one cast later.
	if sasuke.marked_by("Kirin", sasuke):
		return
	# Permanent (-1) rather than a 2-duration window: Kirin now stays in the slot
	# until it is actually used, at which point sasuke6 removes this swap itself
	# so Sasuke does not play on with a spent, unusable skill in slot 2.
	# Sourced to `self` deliberately — character_component silently frees any
	# ABILITY_SWAP whose source is not in the applier's base_abilities.
	var swap = Effect.ability_swap_effect(5, 2, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, sasuke, sasuke, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 50)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
