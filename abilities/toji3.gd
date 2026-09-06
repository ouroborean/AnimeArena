extends Ability

# Inverted Spear of Heaven — 5 Piercing damage plus a permanent, stacking mark. A standing
# HEALTH_CHANGE_TRIGGER on the marked enemy re-checks the execute condition on EVERY HP change
# (from ANY source, not just this skill — check_health_change_triggers fires from receive_damage
# and receive_healing), so the enemy dies the instant their HP drops below the threshold of
# 15 per stack. (Uses the general HEALTH_CHANGE_TRIGGER, not the Muichiro-hardcoded check_beheading.)
# A second invisible END_OF_TURN_TRIGGER re-checks each turn-end as a backstop for the case where HP
# stops moving below the threshold (Immortality saves the target at 1 HP via set_health, which fires
# no HP-change event) — so the execute still lands once that save wears off.

var base_damage = 5

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 5 Piercing damage to target enemy and applies a permanent stacking mark",
		["If that enemy's HP ever falls below the threshold (15 per stack), they are executed", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Permanent stacking mark: each cast raises the execute threshold by 15.
		var mark = Effect.mark(-1, mark_desc)
		mark.stackable = true
		mark.display_stacks = true
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
		# Install the standing execute-watcher once — any later HP change re-checks the threshold.
		if not target.has_effect("Inverted Spear of Heaven", EffectType.Type.HEALTH_CHANGE_TRIGGER, user):
			var watcher = Effect.trigger_effect(Trigger.always(spear_execute_check), EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, "")
			watcher.set_source(self)
			watcher.cleansable = true
			watcher.system = true
			watcher.invisible = true
			Character.add_hostile_effect(context, user, target, watcher, true)
		# Backstop END_OF_TURN re-check: the HP-change watcher can't re-fire when HP is stuck — e.g.
		# a target dropped below the threshold but saved by Immortality is left at 1 HP (a set_health,
		# not a modify_hp, so no HP-change event). This re-checks each turn-end so once the Immortality
		# ends the execute still lands, even though the target's HP never moved again.
		if not target.has_effect("Inverted Spear of Heaven", EffectType.Type.END_OF_TURN_TRIGGER, user):
			var eot = Effect.trigger_effect(Trigger.always(spear_execute_check), EffectType.Type.END_OF_TURN_TRIGGER, -1, "")
			eot.set_source(self)
			eot.cleansable = true
			eot.system = true
			eot.invisible = true
			Character.add_hostile_effect(context, user, target, eot, true)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		# Cast-time check: covers a new stack raising the threshold above current HP with no HP change.
		_spear_check(target, user)

func spear_execute_check(context):
	_spear_check(context['target'], context['owner'])

func _spear_check(enemy, toji):
	if enemy == null or enemy.dead or enemy.banished:
		return
	var mark = enemy.has_effect("Inverted Spear of Heaven", EffectType.Type.MARK, toji)
	if mark == null:
		return
	if enemy.health.hp < 15 * mark.stack_count():
		enemy.instant_kill(toji, self)

func mark_desc(eff):
	return "Pierced by the Inverted Spear of Heaven. Executed any time its HP is below " + str(15 * eff.stack_count()) + "."

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 30)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
