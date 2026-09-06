extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "For 1 turn, Cooler gains 25 Damage Reduction (Invisible). If he receives a new Harmful skill during this time, Death Chaser will deal 10 more damage to that skill's user on the following turn. Usable while Stunned."

func split_desc():
	return [
		"Cooler gains 25 Damage Reduction for 1 turn (Invisible)",
		["If a Harmful skill lands on Cooler during this window, Death Chaser deals +10 damage to that attacker next turn", Color.CADET_BLUE],
		["A successful trigger also sends Cooler into Final Form (see Cruel Transformation)", Color.AQUAMARINE],
		["Usable while Stunned", Color.GOLD]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var dr = Effect.damage_reduction_effect(25, 2)
	dr.set_source(self)
	dr.invisible = true
	Character.add_allied_effect(context, user, user, dr)

	var trigger_desc = func (eff):
		return "If Cooler receives a new Harmful skill, the attacker takes +10 from Death Chaser next turn and Cooler enters Final Form."
	var trigger = Effect.trigger_effect(
		Trigger.always(nova_chariot_trigger),
		EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
		2,
		trigger_desc
	)
	trigger.set_source(self)
	trigger.invisible = true
	Character.add_allied_effect(context, user, user, trigger)

func nova_chariot_trigger(context):
	var cooler = context['target']
	var attacker = context['owner']
	if attacker == null or attacker == cooler:
		return

	# Vulnerability: +10 incoming damage to the attacker, gated to Death Chaser
	# by ability_targets. 1-turn duration so it persists into Cooler's next turn.
	var vuln = Effect.vulnerability_effect(10, 2, ["Death Chaser"])
	vuln.set_source(self)
	Character.add_hostile_effect(context, cooler, attacker, vuln, true)

	# A successful Nova Chariot trigger is one of Cruel Transformation's three
	# Final Form triggers. Delegate to the passive's helper.
	var transformation = cooler.moveset.base_abilities[5]
	transformation.enter_final_form(context, cooler)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 30)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
