extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "For 3 turns, Ai gains 15 damage reduction and if she's affected by a new Harmful skill, the attacker receives 10 Piercing damage and permanently takes 5 more damage from Pen-Light Charges."

func split_desc():
	return [
		"For 3 turns, Ai gains 15 Damage Reduction",
		["While active, an enemy who uses a new Harmful skill on Ai takes 10 Piercing damage", Color.CADET_BLUE],
		["That enemy also permanently takes 5 more damage from Pen-Light Charges", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dr = Effect.damage_reduction_effect(15, 6)
	dr.set_source(self)
	Character.add_allied_effect(context, user, user, dr)

	var counter = Effect.trigger_effect(Trigger.always(ribbon_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 6, "If Ai is affected by a new Harmful skill, the attacker takes 10 Piercing damage and permanently takes 5 more damage from Pen-Light Charges.")
	counter.set_source(self)
	Character.add_allied_effect(context, user, user, counter)

	# Reloads Now I'm Mad!: its Red cost becomes Random for 2 turns (read by ai2.cost()).
	var reload = Effect.mark(4, "Now I'm Mad!'s Red cost is changed to Random.")
	reload.set_source(self)
	Character.add_allied_effect(context, user, user, reload)

func ribbon_trigger(context):
	var attacker = context['owner']       # who used the Harmful skill on Ai
	var ai = context['effect'].user
	if attacker == null or ai == null or attacker.dead or attacker.banished:
		return
	if not ai.is_hostile(attacker):       # only retaliate against enemies
		return
	var qc = QueryContext.from_game_state(ai, ai.battle)
	Character.resolve_effect_damage(qc, context['effect'], attacker, 10, DamageType.Type.PIERCING)
	# Permanent, stacking vulnerability read by Pen-Light Charges (ai5): +5 Affliction per stack.
	var vuln = Effect.mark(-1, "This character permanently takes 5 more damage from Pen-Light Charges per stack.")
	vuln.set_source(ai.moveset.base_abilities[4])   # source = Pen-Light Charges, so ai5 keys on the name
	vuln.stackable = true
	vuln.display_stacks = true
	Character.add_hostile_effect(qc, ai, attacker, vuln)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 30)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
