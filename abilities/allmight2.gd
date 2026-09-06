extends Ability

func describe(user):
	return "For 1 turn, All Might ignores Harmful non-damage effects and is Immortal. If All Might is under 40 HP, his skills deal 10 more damage on the following turn, increased to 20 if he received new damage during this time."

func split_desc():
	return [
		"For 1 turn, All Might ignores negative non-damage effects and is Immortal (Invisible).",
		["If All Might is under 40 HP, his skills deal 10 more damage on the following turn.", Color.CADET_BLUE],
		["Increased to 20 if All Might took new damage during the buff.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = make_context(battle)
	var ignore = Effect.ignore_non_damage_effect(2)
	ignore.set_source(self)
	ignore.invisible = true
	ignore.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, ignore)

	var immortal = Effect.immortality_effect(2)
	immortal.set_source(self)
	immortal.invisible = true
	Character.add_allied_effect(context, user, user, immortal)

	if user.health.hp < 40:
		var damage_mod = Effect.damage_mod_effect(10, 3)
		damage_mod.set_source(self)
		damage_mod.invisible = true
		Character.add_allied_effect(context, user, user, damage_mod)

		var watcher = Effect.trigger_effect(
			Trigger.always(on_damage_received),
			EffectType.Type.DAMAGE_RECEIVE_TRIGGER,
			2,
			"If All Might takes damage during United Resolve, his next-turn damage bonus is doubled.")
		watcher.set_source(self)
		watcher.invisible = true
		Character.add_allied_effect(context, user, user, watcher)

func on_damage_received(context):
	var allmight = context['effect'].user
	var boost = allmight.has_effect("United Resolve", EffectType.Type.DAMAGE_MOD, allmight)
	if boost:
		boost.mag = 20
		boost.description = func (eff): return "This character will deal 20 more damage."
		boost.effect_updated.emit(boost)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 30, 1.5)

func target(user, battle):
	default_self_target_function(user, battle)
