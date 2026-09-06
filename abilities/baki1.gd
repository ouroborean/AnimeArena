extends Ability

# Whip Strike. 15 Piercing, then riders that apply ONLY when the hit actually deals damage (i.e. is not
# fully absorbed by Shield / Damage Reduction / Nullify, not invuln-blocked, not reflected): a delayed
# 10 Affliction next turn, and a Strategic-skill stun whenever EITHER hit leaves the target at 25 or
# less HP.
#
# "Takes damage from this skill" is read directly from the target's HP before vs after the hit. This is
# both simpler and safer than arming a hostile detector effect on the target — such an effect would be
# stripped (or profited from) by enemy anti-debuff passives (Ainz's negation, "ignore non-damage").

func describe(user):
	return "Deals 15 Piercing damage to target enemy. If the target takes damage from this skill, they also take 10 Affliction damage on the following turn. If either hit drops the target to 25 or less HP, their Strategic skills are Stunned for 1 turn."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy",
		["If it deals damage, the target takes 10 Affliction damage next turn", Color.ORANGE_RED],
		["If either hit leaves the target at 25 or less HP, their Strategic skills are Stunned for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var hp_before = target.health.hp
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
		if target.health.hp < hp_before:
			# Delayed 10 Affliction on Baki's next turn. damage_type = AFFLICTION makes it (a) survive
			# ignore-non-damage / Ainz's negate at application, and (b) pierce Invulnerability at tick time —
			# both via the engine's ticking-trigger damage_type handling, like a real Affliction DoT.
			var dot = Effect.trigger_effect(Trigger.always(delayed_affliction), EffectType.Type.TICKING_TRIGGER, 3, "This character will take 10 Affliction damage.")
			dot.set_source(self)
			dot.last_turn_only = true
			dot.damage_type = DamageType.Type.AFFLICTION
			Character.add_hostile_effect(context, user, target, dot)
			_low_hp_stun(context, user, target)

func delayed_affliction(context):
	var target = context.target
	if target.dead or target.banished:
		return
	Character.resolve_effect_damage(context, context.effect, target, 10, DamageType.Type.AFFLICTION)
	_low_hp_stun(context, context.effect.user, target)

# "If either hit drops the target to 25 or less HP" -> stun their Strategic skills for 1 turn.
func _low_hp_stun(context, user, target):
	if target.dead or target.banished:
		return
	if target.health.hp <= 25:
		var stun = Effect.stun_effect(2, ["Strategic"])
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 15)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
