extends Ability

func describe(user):
	return "Target enemy gains 25 points of Nullify for 1 turn. If this Nullify expires without being broken, the affected enemy takes 15 Piercing damage and is stunned for 1 turn. While Empowered, this skill costs 1 more Random energy and its effects last an additional turn."

func split_desc():
	return [
		"Target enemy gains 25 points of Nullify for 1 turn",
		"If the Nullify expires without being broken, the enemy takes 15 Piercing damage and is stunned for 1 turn",
		["While Empowered, costs 1 more Random energy and its trigger effects last an additional turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.marked_by("Rokudo Takeover")

	var shield_dur = 2
	var stun_dur = 2
	if empowered:
		stun_dur = 4

	for target in user.targeter.targets:
		var shield = Effect.barrier_effect(25, shield_dur)
		shield.set_source(self)
		shield.description = func (eff):
			return "This character has " + str(eff.mag) + " points of Nullify. If this Nullify expires, this character will take 15 Piercing damage and be stunned."
		shield.wrapup_func = snake_bind_expire.bind(stun_dur)
		Character.add_hostile_effect(context, user, target, shield)

func snake_bind_expire(context, stun_dur):
	if context['effect'].breaker != null:
		return
	var target_char = context['target']
	if not target_char.dead and not target_char.banished:
		Character.resolve_effect_damage(context, context['effect'], target_char, 15, DamageType.Type.PIERCING)
		var stun = Effect.stun_effect(stun_dur)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target_char, stun)
		if stun_dur == 4:
			var damage = Effect.damage_effect(15, DamageType.Type.PIERCING, 3)
			damage.set_source(self)
			Character.add_hostile_effect(context, user, target_char, damage)

func cost():
	var output = super.cost()
	if user and user.marked_by("Rokudo Takeover"):
		output[4] = output.get(4, 0) + 1
	return output

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context, 10)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
