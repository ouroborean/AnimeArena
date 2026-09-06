extends Ability

# Hippogriff (passive). Astolfo gets Stun immunity + 15 Damage Reduction while he hasn't been damaged
# for 2 turns. Implemented with a "recently damaged" mark (2-turn duration): taking damage (re)applies
# the mark and strips the protection; each turn start, if the mark has expired, the protection returns.

const HIPPO = "Hippogriff"

func describe(user):
	return "Astolfo ignores Stuns and has 15 Damage Reduction if he hasn't been damaged in the last 2 turns."

func split_desc():
	return [
		["While Astolfo hasn't been damaged for 2 turns: he ignores Stuns and gains 15 Damage Reduction", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dmg_trigger = Effect.trigger_effect(Trigger.always(on_damaged), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "When Astolfo is damaged, Hippogriff's protection is suspended for 2 turns.")
	dmg_trigger.set_source(self)
	dmg_trigger.system = true
	Character.add_allied_effect(context, user, user, dmg_trigger)
	var turn_trigger = Effect.trigger_effect(Trigger.always(on_turn_start), EffectType.Type.START_OF_TURN_TRIGGER, -1, "Hippogriff's protection returns after 2 turns without damage.")
	turn_trigger.set_source(self)
	turn_trigger.system = true
	Character.add_allied_effect(context, user, user, turn_trigger)
	apply_protection(user)   # undamaged at battle start

func on_damaged(context):
	var astolfo = context['effect'].user
	if astolfo.dead or astolfo.banished:
		return
	var existing = astolfo.has_effect(HIPPO, EffectType.Type.MARK)
	if existing:
		astolfo.effects.erase_effect(existing)
	var m = Effect.mark(4, "Astolfo was damaged recently; Hippogriff's protection is suspended.")
	m.set_source(self)
	Character.add_allied_effect(QueryContext.from_game_state(astolfo, astolfo.battle), astolfo, astolfo, m)
	remove_protection(astolfo)

func on_turn_start(context):
	var astolfo = context['effect'].user
	if astolfo.dead or astolfo.banished:
		return
	if not astolfo.marked_by(HIPPO):   # no recent-damage mark => 2 clean turns
		apply_protection(astolfo)

func apply_protection(astolfo):
	var context = QueryContext.from_game_state(astolfo, astolfo.battle)
	if not astolfo.has_effect(HIPPO, EffectType.Type.DAMAGE_REDUCTION):
		var dr = Effect.damage_reduction_effect(15, -1)
		dr.set_source(self)
		Character.add_allied_effect(context, astolfo, astolfo, dr)
	if not astolfo.has_effect(HIPPO, EffectType.Type.IGNORE_EFFECT):
		var si = Effect.ignore_effect_effect(-1, EffectType.Type.STUN)
		si.set_source(self)
		si.cleansable = false
		Character.add_allied_effect(context, astolfo, astolfo, si)

func remove_protection(astolfo):
	var dr = astolfo.has_effect(HIPPO, EffectType.Type.DAMAGE_REDUCTION)
	if dr:
		astolfo.effects.erase_effect(dr)
	var si = astolfo.has_effect(HIPPO, EffectType.Type.IGNORE_EFFECT)
	if si:
		astolfo.effects.erase_effect(si)

func extra_usable(user):
	return true

func target(user, battle):
	default_self_target_function(user, battle)
