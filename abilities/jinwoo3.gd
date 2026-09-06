extends Ability

# Shadow Summon (default form). Gains 1 stack (a stacking self-MARK named "Shadow Summon"). On the
# first cast it installs a permanent per-turn engine: each turn it tops Jin-woo's Shield up to 10 per
# stack; any stack already covered by existing Shield instead deals 10 damage to a random enemy,
# preferring the one marked by Hand of the Monarch.

func describe(user):
	return "Jin-woo gains 1 stack of Shadow Summon. Permanently, Jin-woo gains 10 Shield each turn for each stack of Shadow Summon he has (max 10 per stack). If he already has the maximum amount of Shield, he deals 10 damage to a random enemy for each excess stack (prioritizes enemies marked by Hand of the Monarch)."

func split_desc():
	return [
		["Jin-woo gains 1 stack of Shadow Summon", Color.CADET_BLUE],
		"Each turn, gains 10 Shield per stack (max 10 per stack)",
		"While at max Shield, deals 10 damage per excess stack to a random enemy (Hand of the Monarch's target first)",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var first = user.has_effect("Shadow Summon", EffectType.Type.MARK, user) == null
	var stack = Effect.mark(-1, "Shadow Summon.")
	stack.set_source(self)
	stack.stackable = true
	stack.display_stacks = true
	Character.add_allied_effect(context, user, user, stack)
	if first:
		var tick = Effect.trigger_effect(Trigger.always(shadow_tick), EffectType.Type.TICKING_TRIGGER, -1, "Shadow Summon shields Jin-woo and strikes each turn.")
		tick.set_source(self)
		Character.add_allied_effect(context, user, user, tick)
		# Fire once now so the summon shields on the turn it is raised.
		context['effect'] = tick
		shadow_tick(context)

func shadow_tick(context):
	var jinwoo = context['owner']
	if jinwoo.dead:
		return
	var stacks = _stacks(jinwoo)
	if stacks <= 0:
		return
	var cap = 10 * stacks
	var cur = _total_shield(jinwoo)
	if cur < cap:
		var shield = Effect.shield_effect(cap - cur, -1)
		shield.set_source(self)
		shield.unique_render_id = "shadow_summon_shield"
		Character.add_allied_effect(context, jinwoo, jinwoo, shield)
	var excess = mini(stacks, int(cur / 10.0))   # stacks already covered by Shield -> convert to damage
	for i in range(excess):
		var tgt = _pick_target(jinwoo, context)
		if tgt != null:
			Character.resolve_effect_damage(context, context['effect'], tgt, 10, DamageType.Type.NORMAL)

func _stacks(jinwoo):
	var e = jinwoo.has_effect("Shadow Summon", EffectType.Type.MARK, jinwoo)
	return e.stacks if e != null else 0

func _total_shield(jinwoo):
	var t = 0
	for s in jinwoo.get_shield_effects():
		t += s.mag
	return t

func _pick_target(jinwoo, context):
	var enemies := []
	var marked := []
	for enemy in context['enemy_team'].characters:
		if enemy.dead or enemy.banished or enemy.is_invuln(self):
			continue   # non-bypassing NORMAL damage can't hit Invulnerable/off-field enemies
		enemies.append(enemy)
		if enemy.has_effect("Hand of the Monarch", EffectType.Type.MARK, jinwoo) != null:
			marked.append(enemy)
	var pool = marked if not marked.is_empty() else enemies
	if pool.is_empty():
		return null
	return pool[jinwoo.battle.roll(0, pool.size() - 1)]

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
