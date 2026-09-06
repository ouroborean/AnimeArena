extends Ability

var base_damage = 20

func describe(user):
	return "Deals 20 damage to a random enemy and applies 1 Morphin Mark. Next turn, Lyserg can select the target of this skill."

func split_desc():
	return [
		"Deals 20 damage to a random enemy",
		"Applies 1 Morphin Mark to the target",
		"Next turn, Lyserg can select the target of this skill",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var directed = user.effects.has_effect("Homing Pendulum", EffectType.Type.TARGET_CHANGE, user) != null

	var chosen = null
	if directed:
		if not user.targeter.targets.is_empty():
			chosen = user.targeter.targets[0]
		user.effects.remove_effect("Homing Pendulum", EffectType.Type.TARGET_CHANGE, user)
	else:
		var valid = []
		for ch in battle.all_characters():
			if Condition.can_hostile_target(user, ch, self).satisfied(context):
				valid.append(ch)
		if valid.size() > 0:
			chosen = valid[battle.roll(0, valid.size() - 1)]

	if chosen != null:
		Character.resolve_damage(context, chosen, base_damage, DamageType.Type.NORMAL)
		apply_morphin_mark(context, user, chosen)

	if not directed and chosen != null:
		var tc = Effect.target_change_effect(TargetType.Type.SINGLE, 3, ["Homing Pendulum"])
		tc.set_source(self)
		tc.refresh = true
		Character.add_allied_effect(context, user, user, tc)

	install_big_ben_watcher(context, user)

# Morphin Mark is a stackable, permanent mark shared across Lyserg's pendulum
# skills. To keep the effect_name stable for has_effect lookups regardless of
# which skill applied it, every apply sources from slot 0 (Homing Pendulum).
func apply_morphin_mark(context, user, target):
	var canonical = user.moveset.base_abilities[0]
	var existing = target.effects.has_effect("Homing Pendulum", EffectType.Type.MARK, user)
	if existing:
		existing.stacks += 1
		existing.effect_updated.emit(existing)
	else:
		var m = Effect.mark(-1, "Morphin Mark — consumed by Lyserg's pendulum skills.")
		m.set_source(canonical)
		m.stackable = true
		m.display_stacks = true
		m.stacks = 1
		Character.add_hostile_effect(context, user, target, m)
	canonical.install_big_ben_watcher(context, user)
	canonical._evaluate_big_ben(context, user)

func install_big_ben_watcher(context, user):
	if user.effects.has_effect("Homing Pendulum", EffectType.Type.TICKING_TRIGGER, user):
		return
	var watcher = Effect.trigger_effect(
		Trigger.always(check_big_ben),
		EffectType.Type.TICKING_TRIGGER,
		-1,
		"")
	watcher.set_source(self)
	watcher.system = true
	Character.add_allied_effect(context, user, user, watcher)

func check_big_ben(context):
	var lyserg = context['effect'].user
	_evaluate_big_ben(context, lyserg)

func _evaluate_big_ben(context, lyserg):
	if lyserg.dead or lyserg.banished:
		return
	var total = 0
	for e in lyserg.battle.all_characters():
		if lyserg.is_hostile(e) and not (e.dead or e.banished):
			var m = e.effects.has_effect("Homing Pendulum", EffectType.Type.MARK, lyserg)
			if m:
				total += m.stacks
	if total >= 3:
		_install_big_ben_swap(lyserg, context)
	else:
		_remove_big_ben_swap(lyserg)

func _install_big_ben_swap(lyserg, context):
	for swap in lyserg.get_ability_swap_effects():
		if swap.source == self and int(swap.mag[0]) == 4 and int(swap.mag[1]) == 1:
			return
	var swap = Effect.ability_swap_effect(4, 1, lyserg, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, lyserg, lyserg, swap)

func _remove_big_ben_swap(lyserg):
	for swap in lyserg.get_ability_swap_effects():
		if swap.source == self and int(swap.mag[0]) == 4 and int(swap.mag[1]) == 1:
			lyserg.effects.erase_effect(swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 30)

func target(user, battle):
	if user.effects.has_effect("Homing Pendulum", EffectType.Type.TARGET_CHANGE, user):
		default_hostile_target_function(user, battle)
	else:
		default_self_target_function(user, battle)
