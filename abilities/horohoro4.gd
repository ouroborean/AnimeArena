extends Ability

func describe(user):
	return "Horohoro becomes Invulnerable for 1 turn. For 4 turns, if Horohoro stuns an enemy, he will become Invulnerable for 1 turn and this effect's duration will be reset."

func split_desc():
	return [
		"Horohoro becomes Invulnerable for 1 turn",
		"For 4 turns, whenever Horohoro stuns an enemy he becomes Invulnerable for 1 turn",
		"Triggering this effect also refreshes its duration",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var watcher = Effect.trigger_effect(
		Trigger.always(on_stun_applied),
		EffectType.Type.MISSION_TRIGGER_ON_STUN,
		8,
		"If Horohoro stuns an enemy, he becomes Invulnerable for 1 turn and this effect's duration resets.")
	watcher.set_source(self)
	Character.add_allied_effect(context, user, user, watcher)

	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

func on_stun_applied(context):
	var horohoro = context.effect.user
	var victim = context['target']
	if victim == null or victim in horohoro.team.characters:
		return
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, horohoro, horohoro, invuln)
	context.effect.set_duration(8)
	context.effect.effect_updated.emit(context.effect)

func extra_usable(user):
	return user.has_effect("Impeccable Power", EffectType.Type.MISSION_TRIGGER_ON_STUN, user) == null

func custom_behavior(context):
	return behavior_self_panic_button(context, 30, 1.1)

func target(user, battle):
	default_self_target_function(user, battle)
