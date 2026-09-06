extends Ability

# Destructive Corrosion — NOT a castable kit skill. Like All Might's One For All (allmight5), this is a
# Passive-classed ability that exists only to (a) carry the effect's description in the kit UI and (b) be
# the SOURCE of the debuff Bakusaiga (sesshomaru1) applies, so the effect's tooltip/icon read "Destructive
# Corrosion" and Bakusaiga's own text stays clean. execute() is a no-op; it is never usable.
#
# The debuff (applied to one enemy for 3 turns, refreshing) is a visible "Destructive Corrosion" MARK that
# carries the whole description, plus four invisible riders sharing its name: a flat -10 incoming-healing
# mod, a HEALING_RECEIVED_TRIGGER that deals 10 Affliction whenever they are healed, and a
# HEALTH_CHANGE_TRIGGER + END_OF_TURN_TRIGGER pair that Execute them the instant their HP is at 20 or below
# (the toji3 execute-watcher pattern — HEALTH_CHANGE fires on direct hits AND DoT ticks; the END_OF_TURN
# backstop covers the Immortality-freeze case). All riders are gated on the MARK, so they no-op if it is gone.

const DC := "Destructive Corrosion"

func describe(user):
	return "Affected enemies have their incoming healing reduced by 10, and take 10 Affliction damage whenever they are healed. If an affected enemy's HP falls to 20 or below, they are Executed."

func split_desc():
	return [
		["Affected enemies' incoming healing is reduced by 10", Color.AQUAMARINE],
		["Affected enemies take 10 Affliction damage whenever they are healed", Color.ORANGE_RED],
		["An affected enemy at 20 or less HP is Executed", Color.ORANGE_RED],
	]

func execute(user, battle):
	pass   # Passive placeholder — never cast. The real effect is applied by Bakusaiga via apply_corrosion().

func extra_usable(user):
	return false

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])   # the bot never "uses" this
	return variations

func target(user, battle):
	pass

# ── Helper called by Bakusaiga (sesshomaru1) ───────────────────────────────
# Applies (or refreshes) Destructive Corrosion on `enemy` for 3 turns, sourced from this ability.
func apply_corrosion(context, sesshomaru, enemy):
	# Visible handle + detection key. Its tooltip describes ONLY the execute — the part with no other visible
	# rider (the heal-reduction and heal-punish riders below describe themselves; no summary).
	var mark = Effect.mark(6, "This character is Executed if their HP falls to 20 or below.")
	mark.name_override = DC
	mark.refresh = true
	mark.set_source(self)
	Character.add_hostile_effect(context, sesshomaru, enemy, mark, true)
	# -10 flat incoming healing (VISIBLE to the enemy — its own effect line).
	var heal_mod = Effect.healing_received_mod_effect(-10, 6)
	heal_mod.name_override = DC
	heal_mod.description = func(eff): return "This character's incoming healing is reduced by 10."
	heal_mod.refresh = true
	heal_mod.set_source(self)
	Character.add_hostile_effect(context, sesshomaru, enemy, heal_mod, true)
	# Take 10 Affliction damage whenever healed (fires the newly-wired HEALING_RECEIVED_TRIGGER; VISIBLE).
	var heal_punish = Effect.trigger_effect(Trigger.always(on_corroded_healed), EffectType.Type.HEALING_RECEIVED_TRIGGER, 6, "This character takes 10 Affliction damage whenever they are healed.")
	heal_punish.name_override = DC
	heal_punish.refresh = true
	heal_punish.waiting = false
	heal_punish.set_source(self)
	Character.add_hostile_effect(context, sesshomaru, enemy, heal_punish, true)
	# Execute at <=20 HP: HEALTH_CHANGE watcher (catches direct + DoT) + END_OF_TURN backstop (Immortality-freeze).
	# These are pure machinery described by the MARK above — system (hidden from BOTH players, no stray chips).
	var exec_watch = Effect.trigger_effect(Trigger.always(corroded_execute_check), EffectType.Type.HEALTH_CHANGE_TRIGGER, 6, "")
	exec_watch.name_override = DC
	exec_watch.refresh = true
	exec_watch.system = true
	exec_watch.set_source(self)
	Character.add_hostile_effect(context, sesshomaru, enemy, exec_watch, true)
	var exec_eot = Effect.trigger_effect(Trigger.always(corroded_execute_check), EffectType.Type.END_OF_TURN_TRIGGER, 6, "")
	exec_eot.name_override = DC
	exec_eot.refresh = true
	exec_eot.system = true
	exec_eot.set_source(self)
	Character.add_hostile_effect(context, sesshomaru, enemy, exec_eot, true)
	# Cast-time check: an enemy already at <=20 HP when corroded is Executed immediately.
	_execute_if_low(enemy, sesshomaru)

# True iff `enemy` currently carries Destructive Corrosion (read by Bakusaiga / Poison Claw / Whip of Light).
func is_affected(enemy, sesshomaru) -> bool:
	return enemy.has_effect(DC, EffectType.Type.MARK, sesshomaru) != null

func on_corroded_healed(context):
	var eff = context['effect']
	var enemy = eff.target
	if enemy == null or enemy.dead or enemy.banished:
		return
	if enemy.has_effect(DC, EffectType.Type.MARK, eff.user) == null:
		return
	Character.resolve_effect_damage(context, eff, enemy, 10, DamageType.Type.AFFLICTION)

func corroded_execute_check(context):
	_execute_if_low(context['target'], context['owner'])

func _execute_if_low(enemy, sesshomaru):
	if enemy == null or enemy.dead or enemy.banished:
		return
	if enemy.has_effect(DC, EffectType.Type.MARK, sesshomaru) == null:
		return
	if enemy.health.hp <= 20:
		enemy.instant_kill(sesshomaru, self)
