extends Ability

# Rhitta Smash (display slot 0). Damage scales with Sunshine; at 4+ stacks it also stuns the target's
# non-Strategic skills. This ability ALSO hosts the Divine Spear swap machinery: because a swap's
# source must be a base ability that is currently a display ability (get_active_abilities skips others),
# the watcher/evaluator live here on slot 0. base_abilities[5] (Divine Spear) replaces slot 0 at 12 Sunshine.

var base_damage = 10

func describe(user):
	return "Escanor deals 10 damage to target enemy. Deals 5 more damage per stack of Sunshine on Escanor, and if he has at least 4 stacks, also stuns their non-Strategic skills for 1 turn."

func split_desc():
	return [
		"Escanor deals 10 damage to target enemy",
		["Deals 5 more damage per stack of Sunshine on Escanor", Color.CADET_BLUE],
		["With 4 or more Sunshine, also stuns the target's non-Strategic skills for 1 turn", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stacks = sunshine_stacks(user)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + 5 * stacks, DamageType.Type.NORMAL)
		if stacks >= 4:
			var stun = Effect.stun_effect(2, [], ["Strategic"])   # dur 2 = 1 turn; [] include, ["Strategic"] exclude => non-Strategic
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)

func sunshine_stacks(u):
	var e = u.has_effect("Sunshine", EffectType.Type.MARK, u)
	return e.stack_count() if e else 0

# --- Divine Spear swap machinery. install_divine_watcher() is called by the Sunshine passive at
# startup; _evaluate_divine() is re-run after every Sunshine change (Sunshine.gain_stacks and Divine
# Spear's consume) so the slot flips/reverts the same turn instead of waiting for the next tick. ---
func install_divine_watcher(context, u):
	if u.effects.has_effect("Rhitta Smash", EffectType.Type.TICKING_TRIGGER, u):
		return
	var w = Effect.trigger_effect(Trigger.always(check_divine), EffectType.Type.TICKING_TRIGGER, -1, "")
	w.set_source(self)
	w.system = true
	w.remove_on_death = false   # permanent machinery: survive Escanor's death-cleanse (not re-installed on revive)
	Character.add_allied_effect(context, u, u, w)

func check_divine(context):
	_evaluate_divine(context, context['effect'].user)

func _evaluate_divine(context, u):
	if u.dead or u.banished:
		return
	if sunshine_stacks(u) >= 12:
		_install_divine_swap(context, u)
	else:
		_remove_divine_swap(u)

func _install_divine_swap(context, u):
	for s in u.get_ability_swap_effects():
		if s.source == self and int(s.mag[0]) == 5 and int(s.mag[1]) == 0:
			return   # already swapped in — idempotent
	var swap = Effect.ability_swap_effect(5, 0, u, -1)   # base_abilities[5] (Divine Spear) replaces display slot 0, permanent
	swap.set_source(self)
	Character.add_allied_effect(context, u, u, swap)

func _remove_divine_swap(u):
	for s in u.get_ability_swap_effects():
		if s.source == self and int(s.mag[0]) == 5 and int(s.mag[1]) == 0:
			u.effects.erase_effect(s)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, base_damage)

func target(user, battle):
	default_hostile_target_function(user, battle)
