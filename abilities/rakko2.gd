extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 10 Piercing damage to target enemy, increased by 5 for each Bleed effect on them. If at least one enemy is Shattered by Wave Tracking, this skill has no cost."

func split_desc():
	return [
		"Deals 10 Piercing damage to target enemy",
		["+5 damage per Bleed effect on the target", Color.CADET_BLUE],
		["Free if any enemy is Shattered by Wave Tracking", Color.AQUAMARINE],
		["While free, it can only target those Shattered enemies", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Count Bleed effects on the target via BOTH conventions: the standard
		# damage_type==BLEED on DAMAGE-type effects (used by inosuke1, king3,
		# rengoku2, etc.) AND the eff.bleed flag (used by trigger-driven Bleed
		# DOTs like Bleeding Shot's TICKING_TRIGGER which can't carry a
		# damage_type=BLEED tag on the trigger itself).
		var bleed_count = 0
		for eff in target.effects._effects:
			if eff.effect_type == EffectType.Type.DAMAGE and eff.damage_type == DamageType.Type.BLEED:
				bleed_count += 1
			elif eff.bleed:
				bleed_count += 1
		var damage = 10 + 5 * bleed_count
		Character.resolve_damage(context, target, damage, DamageType.Type.PIERCING)

# The single source of truth for "which enemies has Wave Tracking Shattered?".
# BOTH the free-cast condition and the free-cast targeting restriction read this,
# so they can never disagree about what "free" means. The contract is by ability
# NAME, so it decouples this skill from Wave Tracking's eventual implementation
# — whoever wires the Bleed→Shatter trigger just has to source the resulting
# Effect.def_negate() from rakko5 and both halves here pick it up.
func wave_tracking_shattered(caster):
	var shattered = []
	if caster == null or caster.battle == null:
		return shattered
	for character in caster.battle.all_characters():
		if not caster.is_hostile(character):
			continue
		if character.dead or character.banished:
			continue
		for eff in character.effects.get_effects_by_type(EffectType.Type.DEF_NEGATE):
			if eff.source != null and eff.source.ability_name == "Wave Tracking":
				shattered.append(character)
				break
	return shattered

# Cost override: zero out the cost while Wave Tracking has Shattered anybody.
func cost():
	# Passive multiplayer client: server-side cost is authoritative. The
	# server runs this same logic, so the right answer ships in server_cost.
	if server_cost_set and user != null and user.battle != null and user.battle.passive:
		return server_cost.duplicate()
	if not wave_tracking_shattered(user).is_empty():
		return {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	return super.cost()

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 30)
	return variations

func target(user, battle):
	# Deliberately asks the STATE helper, never cost(): cost() short-circuits to
	# server_cost on a passive client, so routing targeting through it would make
	# the restriction invisible to the player picking a target.
	var shattered = wave_tracking_shattered(user)
	if shattered.is_empty():
		default_hostile_target_function(user, battle)
		return
	# While the skill is free it may only be aimed at the enemies Wave Tracking
	# Shattered — same targetability rules, just a narrower candidate list.
	var context = QueryContext.from_game_state(user, battle)
	for character in shattered:
		check_hostile_target(user, character, context)
