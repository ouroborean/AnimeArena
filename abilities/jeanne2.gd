extends Ability

func describe(user):
	return "Jeanne permanently targets one enemy. While active, that enemy can only target Jeanne or themselves, and cannot be targeted by other characters. This skill is replaced by Skull and Knee Crushers while active."

func split_desc():
	return [
		"Jeanne permanently targets one enemy",
		"While active, the target can only target Jeanne or themselves, and cannot be targeted by other characters",
		["Replaced by Skull and Knee Crushers while active", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mark = Effect.mark(-1, "Gibbet: this enemy can only target Jeanne or themselves, and cannot be targeted by other characters.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)

		var death_watcher = Effect.trigger_effect(
			Trigger.always(on_gibbet_target_death),
			EffectType.Type.ON_DEATH_TRIGGER,
			-1,
			"")
		death_watcher.set_source(self)
		death_watcher.system = true
		Character.add_hostile_effect(context, user, target, death_watcher)

		var swap = Effect.ability_swap_effect(4, 1, user, -1)
		swap.set_source(self)
		Character.add_allied_effect(context, user, user, swap)

		var hp_watcher = Effect.trigger_effect(
			Trigger.always(guillotine_hp_watcher),
			EffectType.Type.TICKING_TRIGGER,
			-1,
			"")
		hp_watcher.set_source(self)
		hp_watcher.system = true
		hp_watcher.character_target = target
		Character.add_allied_effect(context, user, user, hp_watcher)

func on_gibbet_target_death(context):
	var target = context['effect'].target
	var jeanne = context['effect'].user
	for swap in jeanne.get_ability_swap_effects():
		if swap.source == self:
			jeanne.effects.erase_effect(swap)
	for trig in jeanne.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER):
		if trig.source == self:
			jeanne.effects.erase_effect(trig)

func end_all_gibbets(user):
	for enemy in user.battle.all_characters():
		if not user.is_hostile(enemy):
			continue
		var mark = enemy.effects.has_effect("Gibbet", EffectType.Type.MARK, user)
		if mark:
			enemy.effects.erase_effect(mark)
		for trig in enemy.effects.get_effects_by_type(EffectType.Type.ON_DEATH_TRIGGER):
			if trig.source == self and trig.user == user:
				enemy.effects.erase_effect(trig)
	for swap in user.get_ability_swap_effects():
		if swap.source == self:
			user.effects.erase_effect(swap)
	for trig in user.effects.get_effects_by_type(EffectType.Type.TICKING_TRIGGER):
		if trig.source == self:
			user.effects.erase_effect(trig)

func guillotine_hp_watcher(context):
	var jeanne = context['effect'].user
	var target = context['effect'].character_target
	if target == null or target.dead or target.banished:
		return
	var below = target.health.hp <= 35
	var existing = _find_guillotine_swap(jeanne)
	if below and existing == null:
		var swap = Effect.ability_swap_effect(5, 1, jeanne, -1)
		swap.set_source(self)
		swap.system = true
		Character.add_allied_effect(context, jeanne, jeanne, swap)
	elif not below and existing != null:
		jeanne.effects.erase_effect(existing)

func _find_guillotine_swap(jeanne):
	for swap in jeanne.get_ability_swap_effects():
		if swap.source == self and int(swap.mag[0]) == 5 and int(swap.mag[1]) == 1:
			return swap
	return null

func extra_usable(user):
	if user.has_effect("Iron Maiden", EffectType.Type.MARK, user):
		return false
	for enemy in user.battle.all_characters():
		if user.is_hostile(enemy) and not (enemy.dead or enemy.banished):
			if enemy.has_effect("Gibbet", EffectType.Type.MARK, user):
				return false
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 35, 1.2)

func target(user, battle):
	default_hostile_target_function(user, battle)
