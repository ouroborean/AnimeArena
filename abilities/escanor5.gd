extends Ability

# Sunshine — Escanor's passive resource. A stacking, uncleansable self-MARK ("Sunshine") that grows
# +1 at the end of each of his own turns (capped at 12), healing 5 HP for every stack actually gained.
# EVERY stack source in the kit routes through gain_stacks() so the heal + cap always apply. The MARK's
# effect_name is this ability's name ("Sunshine"); other skills read it via has_effect("Sunshine", MARK).

const MAX_STACKS = 12
const HEAL_PER_STACK = 5

func describe(user):
	return "Escanor gains 1 stack of Sunshine at the end of each turn, up to a maximum of 12. Whenever Escanor gains a stack of Sunshine for any reason, he heals 5 HP."

func split_desc():
	return [
		"Escanor gains 1 stack of Sunshine at the end of each turn, up to a maximum of 12",
		["Whenever he gains a stack of Sunshine, Escanor heals 5 HP", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# +1 Sunshine at the end of each of Escanor's own turns. A self-hosted TICKING_TRIGGER fires only
	# at the end of the holder's turn, so no acting-team gate is needed.
	var tick = Effect.trigger_effect(Trigger.always(sunshine_tick), EffectType.Type.TICKING_TRIGGER, -1, "Escanor gains 1 stack of Sunshine at the end of each turn.")
	tick.set_source(self)
	tick.system = true
	tick.remove_on_death = false   # permanent machinery: survive Escanor's death-cleanse (passives don't re-install on revive)
	Character.add_allied_effect(context, user, user, tick)
	# Divine Spear replaces Rhitta Smash at 12 stacks — its watcher lives on the slot-0 ability so the
	# swap's source is a display ability (get_active_abilities skips swaps sourced outside base_abilities).
	user.moveset.base_abilities[0].install_divine_watcher(context, user)

func sunshine_tick(context):
	var holder = context['effect'].user
	if holder.dead or holder.banished:
		return
	gain_stacks(1)

# Canonical "gain N Sunshine, heal 5 per stack ACTUALLY gained" helper. Clamp to the cap BEFORE
# healing so a gain at 12 heals 0. Called by the passive tick AND by any other skill that grants
# Sunshine, via user.moveset.base_abilities[4].gain_stacks(n).
func gain_stacks(n):
	var u = user
	var qc = QueryContext.from_game_state(u, u.battle)
	var existing = u.has_effect("Sunshine", EffectType.Type.MARK, u)
	var before = existing.stack_count() if existing else 0
	var after = min(before + n, MAX_STACKS)
	var gained = after - before
	if gained <= 0:
		return
	if existing:
		existing.stacks = after
		existing.effect_updated.emit(existing)
	else:
		var m = Effect.mark(-1, func(eff): return "Sunshine: " + str(eff.stack_count()) + " stack(s).")
		m.set_source(self)
		m.stackable = true
		m.display_stacks = true
		m.cleansable = true
		m.remove_on_death = false
		m.stacks = after
		Character.add_allied_effect(qc, u, u, m)
	# heal 5 per stack actually gained (route through the mark so it has a valid source/user)
	var heal_eff = u.has_effect("Sunshine", EffectType.Type.MARK, u)
	Character.resolve_effect_healing(qc, heal_eff, u, gained * HEAL_PER_STACK)
	# re-check the Divine Spear threshold immediately so the swap toggles this same turn
	u.moveset.base_abilities[0]._evaluate_divine(qc, u)

func stacks(user):
	var e = user.has_effect("Sunshine", EffectType.Type.MARK, user)
	return e.stack_count() if e else 0

func extra_usable(user):
	return true

func custom_behavior(context):
	return []

func target(user, battle):
	default_self_target_function(user, battle)
