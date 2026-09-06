extends Ability

# Ame no Habakiri (PASSIVE, base_abilities index 4). Auto-run at battle start by
# startup_passives. Installs a permanent flat 5 Damage Reduction on Tsubasa plus a permanent,
# invisible ACTION_USE_TRIGGER: each time she uses a skill she gains another 5 Damage Reduction
# that lasts until the end of her opponent's next turn.
#
# Both DR effects share the effect_name "Ame no Habakiri" (source == this passive). The per-use
# DR is dur 2 (self-limits to a single +5 covering the enemy's next turn) and is deliberately NOT
# refresh/stackable: refresh would delete the permanent DR (same name); expiry erases by instance,
# so the two coexist safely (uranus5 / ace4 permanent-DR idiom + midoriya4 ACTION_USE_TRIGGER).

func describe(user):
	return "Permanently, Tsubasa gains 5 Damage Reduction. Each time she uses a skill, she gains 5 additional Damage Reduction until the end of her opponent's next turn."

func split_desc():
	return [
		["Tsubasa permanently gains 5 Damage Reduction", Color.CADET_BLUE],
		["Each time Tsubasa uses a skill, she gains 5 Damage Reduction until the end of her opponent's next turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dr = Effect.damage_reduction_effect(5, -1)
	dr.set_source(self)
	dr.cleansable = false
	dr.display_mag = true   # show the "5" on the permanent DR's tooltip
	Character.add_allied_effect(context, user, user, dr)
	var use_trigger = Effect.trigger_effect(Trigger.always(on_tsubasa_act), EffectType.Type.ACTION_USE_TRIGGER, -1, "Each time Tsubasa uses a skill, she gains 5 Damage Reduction until the end of her opponent's next turn.")
	use_trigger.set_source(self)
	use_trigger.invisible = true
	use_trigger.system = true
	Character.add_allied_effect(context, user, user, use_trigger)

func on_tsubasa_act(context):
	var tsubasa = context['effect'].user
	if tsubasa.dead or tsubasa.banished:
		return
	var dr = Effect.damage_reduction_effect(5, 2)
	dr.set_source(self)
	# The per-use DR shares the effect_name "Ame no Habakiri" with the permanent one, so without a
	# distinct unique_render_id the client clusters both under one tooltip (keyed name@unique_render_id)
	# and the temporary one hides under the permanent. A non-zero id gives it its own panel; display_mag
	# shows the "5" so it reads as a second, active +5 while it lasts.
	dr.unique_render_id = 1
	dr.display_mag = true
	Character.add_allied_effect(context, tsubasa, tsubasa, dr)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
