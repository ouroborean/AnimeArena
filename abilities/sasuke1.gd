extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to target enemy",
		["Until that enemy dies, they take 5 damage per turn", Color.ORANGE_RED],
		["Swaps with Shadow Shuriken Wire Trap while active", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
		var dot = Effect.damage_effect(5, DamageType.Type.NORMAL, -1)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot)
	var swap = Effect.ability_swap_effect(4, 0, user, -1)
	swap.set_source(self)
	swap.unique_render_id = 5
	Character.add_allied_effect(context, user, user, swap)
	# "While active" = only while a LIVING enemy still carries the Shuriken Jutsu DoT. The swap is permanent
	# + cleansable=false and nothing reverted it when the target died, leaving Sasuke stuck on Shadow Shuriken
	# Wire Trap. (Death-cleanse only strips the DEAD char's OWN effects — effect.user == the corpse — so this
	# DoT, whose user is Sasuke, actually LINGERS on the corpse.) Install a watcher that reverts the swap,
	# restoring Shuriken Jutsu, once no living enemy carries the DoT. Guard against a dupe.
	if user.has_effect("Shuriken Jutsu", EffectType.Type.START_OF_TURN_TRIGGER, user) == null:
		var watcher = Effect.trigger_effect(Trigger.always(revert_swap_if_dot_gone), EffectType.Type.START_OF_TURN_TRIGGER, -1, "Reverts Shadow Shuriken Wire Trap to Shuriken Jutsu once the Shuriken Jutsu mark is gone.")
		watcher.set_source(self)
		watcher.system = true
		Character.add_allied_effect(context, user, user, watcher)

# Fires at each turn boundary (i.e. before Sasuke next acts). Once no enemy still carries the Shuriken Jutsu
# DoT — its target died, or the DoT was cleansed — strip the Shadow Shuriken Wire Trap swap so Shuriken Jutsu
# returns, then retire this watcher. Polls the DoT rather than hooking effect_removed so it also covers the
# cleanse path (cleanse rebuilds _effects via filter and never fires effect_removed).
func revert_swap_if_dot_gone(context):
	var sasuke = context['effect'].user
	if sasuke == null or not is_instance_valid(sasuke) or sasuke.battle == null:
		return
	for c in sasuke.battle.all_characters():
		# Skip DEAD holders: this DoT lingers on a corpse (death-cleanse only strips the corpse's own
		# effects), but a dead target means Shuriken Jutsu is finished, so it must not keep the swap alive.
		# A banished (not-dead) holder keeps its DoT and should keep the swap.
		if not c.dead and c.has_effect("Shuriken Jutsu", EffectType.Type.DAMAGE, sasuke) != null:
			return   # a living enemy still carries the Shuriken Jutsu DoT -> keep the swap
	# Strip this ability's Shadow Shuriken Wire Trap swap (only ever one, but remove all matches to be safe),
	# then retire this watcher. (Deliberate: if the dead holder is later revived it re-enters carrying the
	# lingering DoT, but we do NOT re-arm the swap — that only frees Sasuke to re-cast Shuriken Jutsu, which
	# re-arms cleanly, so the edge favors him rather than re-locking the wire trap.)
	for swap in sasuke.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		if swap.effect_name() == "Shuriken Jutsu" and swap.user == sasuke:
			sasuke.effects.erase_effect(swap)
	sasuke.effects.erase_effect(context['effect'])

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
