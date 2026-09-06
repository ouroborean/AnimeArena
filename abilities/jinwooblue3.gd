extends Ability

# Summon - Tusk (Blue form). Installs a permanent end-of-turn engine: 15 Affliction damage to every
# Stunned or Silenced enemy at the end of each of Jin-woo's turns. Then permanently swaps this slot for
# Hymn of Fire. (Affliction bypasses Invulnerability by design, so no is_invuln guard — only dead/banished.)

func describe(user):
	return "Permanently, Jin-woo deals 15 Affliction damage to any Stunned or Silenced enemy at the end of each turn. This skill is then replaced by Hymn of Fire."

func split_desc():
	return [
		["Permanently, Jin-woo deals 15 Affliction damage to any Stunned or Silenced enemy at the end of each turn", Color.MEDIUM_PURPLE],
		["Replaced by Hymn of Fire", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trig = Effect.trigger_effect(Trigger.always(tusk_tick), EffectType.Type.END_OF_TURN_TRIGGER, -1, "Jin-woo deals 15 Affliction damage to Stunned or Silenced enemies at the end of each turn.")
	trig.set_source(self)
	Character.add_allied_effect(context, user, user, trig)
	var swap = Effect.ability_swap_effect(4, 2, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func tusk_tick(context):
	var jinwoo = user
	if jinwoo.dead or jinwoo.banished:
		return
	for enemy in jinwoo.battle.all_characters():
		if not jinwoo.is_hostile(enemy):
			continue
		if enemy.dead or enemy.banished:
			continue
		var stunned = enemy.effects.get_effects_by_type(EffectType.Type.STUN).size() > 0
		if stunned or enemy.is_silenced():
			Character.resolve_effect_damage(context, context['effect'], enemy, 15, DamageType.Type.AFFLICTION)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
