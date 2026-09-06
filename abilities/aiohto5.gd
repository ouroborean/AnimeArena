extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Whenever Ai deals damage to an enemy, she also deals 5 Affliction damage. Ai heals for any damage dealt by this passive effect."

func split_desc():
	return [
		["Whenever Ai deals damage to an enemy, she also deals 5 Affliction damage", Color.CADET_BLUE],
		["Ai heals for the damage dealt by this passive", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(charge_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, "Whenever Ai deals damage to an enemy, she also deals 5 Affliction damage and heals for it.")
	trigger.set_source(self)
	trigger.system = true
	trigger.cleansable = false
	Character.add_allied_effect(context, user, user, trigger)

func charge_trigger(context):
	var ai = context['effect'].user
	var target = context['target']
	var source = context['source']
	if ai == null or target == null:
		return
	# Only proc on Ai's own ABILITY damage — never on effect damage (this prevents the passive from
	# looping on its own Affliction).
	if source is Effect:
		return
	if not ai.is_hostile(target) or target.dead or target.banished:
		return
	var amount = 5
	# Gymnastics Ribbon's counter permanently stacks +5 more damage from this passive on the enemy.
	var vuln = target.has_effect("Pen-Light Charges", EffectType.Type.MARK, ai)
	if vuln:
		amount += 5 * vuln.stack_count()
	var qc = QueryContext.from_game_state(ai, ai.battle)
	Character.resolve_effect_damage(qc, context['effect'], target, amount, DamageType.Type.AFFLICTION)
	Character.resolve_healing(qc, ai, amount)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
