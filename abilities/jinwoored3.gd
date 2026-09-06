extends Ability

# Summon - Igris (Red form). Installs a permanent watcher: any ENEMY that becomes Invulnerable takes
# 5 Piercing damage (via the engine's INVULN_RECEIVED_TRIGGER — see
# character_component.check_invuln_received_triggers). Then permanently swaps this slot for Demon
# King's Longsword (hidden index 4).

func describe(user):
	return "Permanently, Jin-woo deals 5 Piercing damage to any enemy that becomes Invulnerable. This skill is then replaced by Demon King's Longsword."

func split_desc():
	return [
		["Permanently, Jin-woo deals 5 Piercing damage to any enemy that becomes Invulnerable", Color.ORANGE_RED],
		["Replaced by Demon King's Longsword", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var watch = Effect.trigger_effect(Trigger.always(igris_trigger), EffectType.Type.INVULN_RECEIVED_TRIGGER, -1, "Jin-woo deals 5 Piercing damage to any enemy that becomes Invulnerable.")
	watch.set_source(self)
	Character.add_allied_effect(context, user, user, watch)
	var swap = Effect.ability_swap_effect(4, 2, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func igris_trigger(context):
	var jinwoo = user
	var enemy = context['target']
	if enemy == null or enemy.dead or enemy.banished:
		return
	if not jinwoo.is_hostile(enemy):
		return
	Character.resolve_effect_damage(context, context['effect'], enemy, 5, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
