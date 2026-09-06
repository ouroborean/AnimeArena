extends Ability

# Alchemic Gold. 15 damage + a "reward window" MARK on the enemy: while it lives, any ally who damages
# that enemy deals +5 non-Affliction and gains 5 Damage Reduction for 1 turn. Ex-Drive extends the
# window by 1 turn. Berserk Mode applies the reward to Hibiki herself immediately on cast. A Gungnir
# Charge makes the whole skill resolve twice (two windows, distinct unique_render_ids).

func describe(user):
	return "Deals 15 damage to target enemy. For the rest of the turn, any ally that damages that enemy will deal 5 more non-Affliction damage and gain 5 Damage Reduction for 1 turn."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["For the rest of the turn, any ally that damages that enemy deals 5 more non-Affliction damage and gains 5 Damage Reduction for 1 turn", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var berserk = user.has_effect("Berserk Mode", EffectType.Type.MARK, user) != null
	var ex_drive = user.has_effect("Ex-Drive", EffectType.Type.MARK, user) != null
	var charge = user.has_effect("Gungnir Charge", EffectType.Type.MARK, user)
	var times = 2 if charge != null else 1
	for i in range(times):
		for target in user.targeter.targets:
			Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
			if berserk:
				_apply_gold_buff(context, user)   # self-buff on cast; no ally reward
			else:
				var dur = 3 if ex_drive else 1
				var trig = Effect.trigger_effect(Trigger.always(alchemic_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, dur, "While marked, an ally that damages this enemy deals 5 more non-Affliction damage and gains 5 Damage Reduction for 1 turn.")
				trig.set_source(self)
				trig.ability_only = true
				trig.unique_render_id = i + 1
				Character.add_hostile_effect(context, user, target, trig)
	if charge != null:
		charge.consume_stack(1)

func alchemic_trigger(context):
	var dealer = context['owner']
	if dealer == null or not is_instance_valid(dealer):
		return
	if not dealer in user.team.characters:
		return
	_apply_gold_buff(context, dealer)

# +5 non-Affliction damage + 5 DR for 1 turn on `ally`. refresh=true so repeat triggers refresh rather
# than stack; distinct unique_render_ids keep the two effects (and any double-strike) legible.
func _apply_gold_buff(context, ally):
	var boost = Effect.damage_mod_effect(5, 3, [], [], [DamageType.Type.AFFLICTION])   # dur 3 so it lasts to the ally's next turn
	boost.set_source(self)
	boost.refresh = true
	boost.unique_render_id = 1
	Character.add_allied_effect(context, ally, ally, boost)
	var dr = Effect.damage_reduction_effect(5, 2)   # DR stays dur 2 ("1 turn")
	dr.set_source(self)
	dr.refresh = true
	dr.unique_render_id = 2
	Character.add_allied_effect(context, ally, ally, dr)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 15)

func target(user, battle):
	default_hostile_target_function(user, battle)
