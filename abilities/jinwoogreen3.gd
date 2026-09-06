extends Ability

# Summon - Beru (Green form). Installs a permanent per-turn engine that deals 10 Piercing to all
# enemies each turn (fires once immediately), then permanently swaps this slot for Impossible Speed.

func describe(user):
	return "Permanently, Jin-woo deals 10 Piercing damage to all enemies each turn. This skill is then replaced by Impossible Speed."

func split_desc():
	return [
		["Permanently, Jin-woo deals 10 Piercing damage to all enemies each turn", Color.AQUAMARINE],
		["Replaced by Impossible Speed", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var tick = Effect.trigger_effect(Trigger.always(beru_tick), EffectType.Type.TICKING_TRIGGER, -1, "Jin-woo deals 10 Piercing damage to all enemies each turn.")
	tick.set_source(self)
	tick.damage_type = DamageType.Type.PIERCING
	Character.add_allied_effect(context, user, user, tick)
	context['effect'] = tick
	beru_tick(context)
	var swap = Effect.ability_swap_effect(4, 2, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func beru_tick(context):
	var jinwoo = user
	if jinwoo.dead or jinwoo.banished:
		return
	for enemy in jinwoo.battle.all_characters():
		if not jinwoo.is_hostile(enemy):
			continue
		if enemy.dead or enemy.banished or enemy.is_invuln(self):
			continue   # Piercing skips Shield/DR but NOT Invulnerability, and Beru isn't Bypassing
		Character.resolve_effect_damage(context, context['effect'], enemy, 10, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
