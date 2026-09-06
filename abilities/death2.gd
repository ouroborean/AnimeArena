extends Ability

# Death Claws. AoE DoT: 10 (or 15 if the cost was taxed with Random) to every enemy each turn for 4
# turns, via an immediate hit on the cast turn + a TICKING_TRIGGER for the following 3 turns (the
# TICKING_TRIGGER never fires on the turn it is applied). Each affected enemy also has all cooldowns
# raised by 1 for the window, and is executed the moment its HP drops to 10 or below.

var base_damage = 10
var boosted_damage = 15
const EXECUTE_THRESHOLD = 10   # execute_attempt kills at hp <= threshold, i.e. "10 or less"

func describe(user):
	return "Deals 10 damage to all enemies each turn for 4 turns. While affected, their cooldowns are increased by 1 and any enemy whose health falls to 10 or less is executed. Deals 15 damage instead if this skill costs at least 1 Random energy."

func split_desc():
	return [
		"Deals 10 damage to all enemies each turn for 4 turns",
		["While affected, their cooldowns are increased by 1 and they are executed at 10 HP or less", Color.ORANGE_RED],
		["Deals 15 damage instead if this skill costs at least 1 Random energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Damage locked at cast: base cost has no Random, so 15 only fires when an enemy taxed the cost.
	var dmg = boosted_damage if cost()[Energy.Type.RANDOM] >= 1 else base_damage
	for target in user.targeter.targets:
		# Turn 1 of 4: the immediate hit + execute check (TICKING doesn't tick on its apply turn).
		Character.resolve_damage(context, target, dmg, DamageType.Type.NORMAL)
		if not target.dead and not target.is_invuln(self):
			target.execute_attempt(EXECUTE_THRESHOLD, user, self)
		# Turns 2-4: one TICKING_TRIGGER that deals dmg THEN execute-checks (guaranteed ordering).
		# dur 7 = 2N-1 for N=4 -> 3 more ticks. mag carries the locked cast-time damage.
		var claw = Effect.trigger_effect(Trigger.always(claw_trigger), EffectType.Type.TICKING_TRIGGER, 7, "Death Claws deals " + str(dmg) + " damage; this enemy is executed at " + str(EXECUTE_THRESHOLD) + " HP or less.")
		claw.set_source(self)
		claw.damage_type = DamageType.Type.NORMAL
		claw.mag = dmg
		Character.add_hostile_effect(context, user, target, claw)
		# +1 to ALL of this enemy's cooldowns for the window (targets=[] -> every skill). dur 8 = "4 turns".
		var cd = Effect.cooldown_mod(1, 8)
		cd.set_source(self)
		Character.add_hostile_effect(context, user, target, cd)

func claw_trigger(context):
	var target = context['effect'].target
	var executioner = context['effect'].user
	if target.dead or target.banished or target.is_invuln(self):
		return
	Character.resolve_effect_damage(context, context['effect'], target, context['effect'].mag, DamageType.Type.NORMAL)
	if not target.dead:
		target.execute_attempt(EXECUTE_THRESHOLD, executioner, self)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 60, 1.0)
	return variations

func target(user, battle):
	# AoE all-enemies.
	default_hostile_target_function(user, battle, false)
