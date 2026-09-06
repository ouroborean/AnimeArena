extends Ability
var base_damage = 35

# Death Ball. A planted bomb rather than a hit: nothing happens on cast, and at the end of the
# enemy's turn it detonates unless the target went Invulnerable in the meantime. That gives the
# opponent a real, readable answer (any invuln, or killing Frieza) instead of an unavoidable delay.
#
# The trigger is hosted on the TARGET, not on Frieza: check_end_of_turn_triggers only runs for the
# ACTING team, so a self-hosted trigger would fire at the end of Frieza's own turn (immediately).
# Duration 2 -> ticks to 1 at the end of Frieza's turn, fires at the end of the enemy's turn.
#
# The stun is duration 3, not 2. tick_durations runs immediately after end-of-turn triggers, so an
# effect planted here loses a point before the enemy's next turn even begins; 2 would expire before
# they ever miss an action.

func describe(user):
	return "At the end of the following turn, if target enemy is not Invulnerable, they take 35 damage and are stunned for 1 turn."

func split_desc():
	return [
		"At the end of the following turn, target enemy takes 35 damage and is stunned for 1 turn",
		["This has no effect if they are Invulnerable when it resolves", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var bomb = Effect.trigger_effect(Trigger.always(detonate), EffectType.Type.END_OF_TURN_TRIGGER, 2,
			"At the end of this turn, takes 35 damage and is stunned for 1 turn, unless Invulnerable.")
		# Stamp the turn it was planted on, so detonate() can refuse to fire on that same turn.
		# The hostile-host trick alone is not enough: a bounce-reflect re-aims the skill onto
		# Frieza's own side, and a trigger sitting there fires at the end of the very turn it lands.
		bomb.mag = battle.current_turn_number
		apply_hostile(context, target, bomb)

func detonate(context):
	var eff = context['effect']
	var target = context['target']
	if target == null or not is_instance_valid(target):
		return
	var frieza = eff.user
	if frieza == null or not is_instance_valid(frieza) or frieza.battle == null:
		return
	# Never on the turn it was planted (see execute).
	if frieza.battle.current_turn_number <= int(eff.mag):
		return
	# One-shot from here on. tick_durations SKIPS banished characters, so a bomb riding one that
	# gets banished and returns could otherwise still be alive for a second end-of-turn firing.
	eff.triggered = true
	if not (target.dead or target.banished):
		# resolve_effect_damage does not gate on Invulnerability the way add_hostile_effect does, so
		# the check has to be explicit, and at resolve time rather than cast time. Passing `self`
		# matters: Character.is_invuln(null) short-circuits to true for ANY invuln and never reaches
		# the per-effect class_targets / exclusion_targets / cost_color tests, so a Death Ball would
		# fizzle against invulnerability that does not actually cover it.
		if not Condition.is_invuln(target, self).satisfied(context):
			Character.resolve_effect_damage(context, eff, target, base_damage, DamageType.Type.NORMAL)
			if not target.dead:
				var stun = Effect.stun_effect(3)
				stun.set_source(self)
				Character.add_hostile_effect(context, frieza, target, stun)
	target.effects.consume_effect(eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_stun(context, base_damage)

func target(user, battle):
	default_hostile_target_function(user, battle)
