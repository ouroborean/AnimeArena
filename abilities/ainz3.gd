extends Ability

var base_damage = 15

# Gravity Maelstrom. AoE Piercing + a 1-turn damage-down on all enemies; Hold-of-Ribs'd enemies are also
# stunned; and it strips energy from the primary target scaled by this skill's EXTRA energy cost.

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 15 Piercing damage to all enemies and reduces their damage by 5 for 1 turn",
		["Enemies affected by Hold of Ribs are also Stunned for 1 turn", Color.ORANGE_RED],
		["Removes 1 energy from the primary target for each extra energy this skill costs", Color.CADET_BLUE],
	]

func _extra_energy() -> int:
	var extra := 0
	var c = cost()
	for e in c:
		extra += c[e]
	for e in _cost:
		extra -= _cost[e]
	return max(0, extra)

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var dr = Effect.damage_mod_effect(-5, 2)              # -5 damage for 1 turn
		dr.set_source(self)
		Character.add_hostile_effect(context, user, target, dr)
		# "affected by Hold of Ribs" = still wearing its Isolate (sourced from Hold of Ribs).
		if target.has_effect("Hold of Ribs", EffectType.Type.ISOLATE, user) != null:
			var stun = Effect.stun_effect(2)                  # 1 turn
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
	var extra = _extra_energy()
	if extra > 0 and user.targeter.main_target != null:
		user.targeter.main_target.lose_energy(user, extra)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 30)

func target(user, battle):
	default_hostile_target_function(user, battle)
