extends Ability

var gamuza_duration = 9

func describe(user):
	return "For 4 turns, allies who become Stunned are instead Invulnerable for 1 turn, enemies who become Invulnerable are Shattered for 1 turn, Lanzador Verde deals 5 more damage, and Protector's Reiatsu has double effect."

func split_desc():
	return [
		"For 4 turns:",
		"Allies who become Stunned become Invulnerable for 1 turn",
		"Enemies who become Invulnerable become Shattered for 1 turn",
		["Lanzador Verde deals 5 more damage", Color.CADET_BLUE],
		["Protector's Reiatsu has double effect", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var parent = Effect.mark(gamuza_duration, "Declare, Gamuza is active.")
	parent.set_source(self)
	Character.add_allied_effect(context, user, user, parent)

	for ally in context.ally_team.characters:
		if ally.dead or ally.banished:
			continue
		var stun_trig = Effect.trigger_effect(
			Trigger.always(ally_stun_trigger),
			EffectType.Type.STUN_RECEIVED_TRIGGER,
			gamuza_duration,
			"If this character becomes Stunned, they become Invulnerable for 1 turn instead.")
		stun_trig.set_source(self)
		Character.add_allied_effect(context, user, ally, stun_trig)

	for enemy in context.enemy_team.characters:
		if enemy.dead or enemy.banished:
			continue
		var invuln_trig = Effect.trigger_effect(
			Trigger.always(enemy_invuln_trigger),
			EffectType.Type.MISSION_TRIGGER_ON_INVULN,
			gamuza_duration,
			"If this character becomes Invulnerable, they become Shattered for 1 turn.")
		invuln_trig.set_source(self)
		Character.add_hostile_effect(context, user, enemy, invuln_trig)
	
	var portrait_swap = Effect.portrait_change_effect(0, gamuza_duration)
	portrait_swap.set_source(self)
	Character.add_allied_effect(context, user, user, portrait_swap)

func ally_stun_trigger(context):
	var ally = context['target']
	var nel = context['effect'].user
	if ally.dead or ally.banished:
		return
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, nel, ally, invuln)

func enemy_invuln_trigger(context):
	var enemy = context['target']
	var nel = context['effect'].user
	if enemy.dead or enemy.banished:
		return
	var shatter = Effect.def_negate(2)
	shatter.set_source(self)
	Character.add_hostile_effect(context, nel, enemy, shatter, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 60)

func target(user, battle):
	default_self_target_function(user, battle)
