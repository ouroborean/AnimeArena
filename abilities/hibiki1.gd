extends Ability

# Amalgam. 15 damage + a "reward window" MARK on the enemy: while it lives, any ally who damages that
# enemy heals 10. Ex-Drive extends the window by 1 turn. Berserk Mode replaces the ally reward with an
# immediate self-heal on cast. A Gungnir Charge makes the whole skill resolve twice (two windows, given
# distinct unique_render_ids so both are visible when Ex-Drive keeps them alive).

func describe(user):
	return "Deals 15 damage to target enemy. For the rest of the turn, any ally that damages that enemy will heal 10 HP."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["For the rest of the turn, any ally that damages that enemy heals 10 HP", Color.AQUAMARINE],
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
				Character.resolve_healing(context, user, 10)   # self-buff on cast; no ally reward
			else:
				var dur = 3 if ex_drive else 1   # "rest of turn" = 1; Ex-Drive extends by 1 turn (+2)
				var trig = Effect.trigger_effect(Trigger.always(amalgam_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, dur, "While marked, an ally that damages this enemy heals 10 HP.")
				trig.set_source(self)
				trig.ability_only = true
				trig.unique_render_id = i + 1   # distinct id so a double-strike shows two separate windows
				Character.add_hostile_effect(context, user, target, trig)
	if charge != null:
		charge.consume_stack(1)

func amalgam_trigger(context):
	var dealer = context['owner']
	if dealer == null or not is_instance_valid(dealer):
		return
	if not dealer in user.team.characters:
		return   # only Hibiki's allies are rewarded
	Character.resolve_effect_healing(context, context['effect'], dealer, 10)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 15)

func target(user, battle):
	default_hostile_target_function(user, battle)
