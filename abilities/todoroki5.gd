extends Ability


func describe(user):
	return "Half-Hot Half-Cold. Todoroki tracks Hot and Cold stacks. Hot skills add Half-Hot and remove Half-Cold; cold skills do the reverse. If he ends his turn with more than 1 Half-Hot stack, he takes 10 Affliction damage per excess stack. While he has more than 1 Half-Cold stack, his skills cost 1 more Random energy per excess stack."

func split_desc():
	return [
		"If Todoroki ends his turn with more than 1 Half-Hot stack, he takes 10 Affliction damage per excess stack.",
		["While Todoroki has more than 1 Half-Cold stack, his skills cost 1 more Random energy per excess stack.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = make_context(battle)
	_ensure_mark(user, context, "hot")
	_ensure_mark(user, context, "cold")
	_ensure_hot_burn_trigger(user, context)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)

func _hot_desc(eff):
	return "Todoroki has " + str(eff.stacks) + " stack(s) of Half-Hot."

func _cold_desc(eff):
	return "Todoroki has " + str(eff.stacks) + " stack(s) of Half-Cold. Above 1 stack, his skills cost 1 more Random energy per excess stack."

func _cost_penalty_desc(eff):
	return "Half-Cold overload: Todoroki's skills cost " + str(eff.mag) + " more Random energy."

func _make_mark(tag):
	var desc = _hot_desc if tag == "hot" else _cold_desc
	var mark = Effect.mark(-1, desc)
	mark.mag = tag
	mark.stacks = 0
	mark.stackable = false
	mark.refresh = false
	mark.display_stacks = true
	mark.unique_render_id = 1 if tag == "hot" else 2
	mark.cleansable = false
	mark.set_source(self)
	return mark

func _find_mark(user, tag):
	for eff in user.effects.get_effects_by_type(EffectType.Type.MARK):
		if eff.source == self and eff.mag == tag:
			return eff
	return null

func _ensure_mark(user, context, tag):
	var mark = _find_mark(user, tag)
	if mark == null:
		mark = _make_mark(tag)
		Character.add_allied_effect(context, user, user, mark)
	return mark

func _find_cost_penalty(user):
	for eff in user.effects.get_effects_by_type(EffectType.Type.COST_MOD):
		if eff.source == self:
			return eff
	return null

func _sync_cost_penalty(user):
	var cold = get_cold_stacks(user)
	var penalty = max(0, cold - 1)
	var pen = _find_cost_penalty(user)
	if penalty == 0:
		if pen != null:
			user.effects.erase_effect(pen)
		return
	if pen == null:
		pen = Effect.cost_mod_effect(penalty, -1, Energy.Type.RANDOM)
		pen.description = _cost_penalty_desc
		pen.cleansable = false
		pen.set_source(self)
		Character.add_allied_effect(make_context(user.battle), user, user, pen)
	else:
		pen.mag = penalty
		pen.effect_updated.emit(pen)

func _find_hot_burn_trigger(user):
	for eff in user.effects.get_effects_by_type(EffectType.Type.END_OF_TURN_TRIGGER):
		if eff.source == self:
			return eff
	return null

func _ensure_hot_burn_trigger(user, context):
	var trig = _find_hot_burn_trigger(user)
	if trig != null:
		return trig
	var desc = func (eff):
		return "If Todoroki ends his turn with more than 1 Half-Hot stack, he takes 10 Affliction damage per excess stack."
	trig = Effect.trigger_effect(Trigger.always(hot_burn_trigger), EffectType.Type.END_OF_TURN_TRIGGER, -1, desc)
	trig.cleansable = false
	trig.set_source(self)
	Character.add_allied_effect(context, user, user, trig)
	return trig

func hot_burn_trigger(context):
	var todoroki = context['target']
	var hot = get_hot_stacks(todoroki)
	if hot <= 1:
		return
	var damage = 10 * (hot - 1)
	Character.resolve_effect_damage(context, context['effect'], todoroki, damage, DamageType.Type.AFFLICTION)

func add_hot_stack(user, n := 1):
	var mark = _ensure_mark(user, make_context(user.battle), "hot")
	mark.stacks += n
	mark.effect_updated.emit(mark)

func remove_hot_stack(user, n := 1):
	var mark = _ensure_mark(user, make_context(user.battle), "hot")
	mark.stacks = max(0, mark.stacks - n)
	mark.effect_updated.emit(mark)

func add_cold_stack(user, n := 1):
	var mark = _ensure_mark(user, make_context(user.battle), "cold")
	mark.stacks += n
	mark.effect_updated.emit(mark)
	_sync_cost_penalty(user)

func remove_cold_stack(user, n := 1):
	var mark = _ensure_mark(user, make_context(user.battle), "cold")
	mark.stacks = max(0, mark.stacks - n)
	mark.effect_updated.emit(mark)
	_sync_cost_penalty(user)

func get_hot_stacks(user) -> int:
	var mark = _find_mark(user, "hot")
	return 0 if mark == null else mark.stacks

func get_cold_stacks(user) -> int:
	var mark = _find_mark(user, "cold")
	return 0 if mark == null else mark.stacks

func _get_passive(user):
	for ab in user.moveset.abilities:
		if ab.ability_name == "Half-Hot Half-Cold":
			return ab
	return null
