extends Ability
var base_damage = 10
var aoe_base = 10
var aoe_per_energy = 5

const MANA := "Mana Control"

# Zoltraak Blasts. TWO DIFFERENT SHAPES depending on the stance:
#
#   * unenhanced - a three-turn barrage of chip damage on a random enemy. A lingering
#     TICKING_TRIGGER whose first instance is fired by hand (see below).
#   * under Mana Control - ONE team-wide burst, right now, sized by Fern's unspent mana. It plants
#     NOTHING: no volley, nothing to tick, nothing to stack (owner ruling). Mana Control turns the
#     skill from a slow barrage into a single all-in detonation, which is what makes spending the
#     whole bank on it a real decision rather than a strict upgrade.
#
# The burst goes through Character.resolve_damage (ability damage) rather than resolve_effect_damage:
# with no effect to source it from it IS a direct hit from the skill, and that is the primitive fern1
# uses for the same kind of AoE. resolve_damage takes an EXPLICIT target, so this skill staying
# self-targeted does not restrict who the burst can reach.
#
# For the unenhanced barrage the per-tick number is baked into the effect when it is planted: `mag`
# carries the damage, so a later stance change cannot retroactively alter a volley already in
# flight. Recasting STACKS rather than refreshing (owner ruling): the trigger is not `stackable` and
# not `refresh`, so effect_storage's add_effect stores a second copy and both tick.
#
# THE FIRST INSTANCE IS FIRED BY HAND. A side's ticking effects are snapshotted BEFORE that turn's
# abilities run, so a volley planted here can never appear in its own cast turn's batch. Duration 5
# supplies the two LATER instances (TICKING_TRIGGERs fire only on the caster's turns, 2 duration per
# fire) and execute() deals the opening one directly — the shipped "N for K turns" idiom of an
# immediate hit plus duration 2K-1 (squalo1, genos3). Measured [10, 10, 10] from the cast turn.
# Planting dur 7 with no manual instance instead gives [0, 10, 10, 10]: the right total, a turn late.

func describe(user):
	return "For 3 turns, Fern deals 10 damage to a random enemy. If Mana Control is active, this skill instead deals 10 Piercing damage to all enemies one time, increased by 5 for each energy left in Fern's pool when it executes (after all skills are paid for), consuming all of that energy."

func split_desc():
	return [
		"For 3 turns, Fern deals 10 damage to a random enemy",
		["If Mana Control is active, instead deals 10 Piercing damage to all enemies a single time", Color.CADET_BLUE],
		["That burst is increased by 5 per energy left in Fern's pool after all skills are paid for", Color.CADET_BLUE],
		["That energy is all consumed", Color.DIM_GRAY],
	]

func mana_control_active(fern) -> bool:
	return fern != null and is_instance_valid(fern) and fern.marked_by(MANA, fern) != null

# See fern1.leftover_energy for the derivation.
func leftover_energy(fern) -> int:
	if fern == null or fern.team == null or fern.team.energy == null:
		return 0
	var ep = fern.team.energy
	var total: int = 0
	for color in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		total += int(ep.pool.get(color, 0))
		total -= maxi(int(ep.promised_pool.get(color, 0)), 0)
	total -= maxi(int(ep.promised_pool.get(Energy.Type.RANDOM, 0)), 0)
	return maxi(total, 0)

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if mana_control_active(user):
		# ONE burst, no lingering volley. Sized from the pool BEFORE it is burned - the damage IS the bank.
		var burst: int = aoe_base + aoe_per_energy * leftover_energy(user)
		for foe in _live_enemies(user):
			Character.resolve_damage(context, foe, burst, DamageType.Type.PIERCING)
		burn_pool(user)
		return

	var per_tick: int = base_damage
	# Duration 5, not 7: the engine SNAPSHOTS a side's ticking effects before that turn's abilities
	# execute (process_turn_package gathers get_ticking_effect_information, then runs start_round_loop),
	# so a volley created here cannot tick on the turn it was cast. Duration 5 supplies the two LATER
	# instances and the first is fired by hand below — the shipped "N for K turns" idiom of an
	# immediate hit plus duration 2K-1 (squalo1, genos3). Measured: 10/10/10 on the cast turn and the
	# two after it. Without the manual first instance the whole window lands a turn late.
	var volley = Effect.trigger_effect(
		Trigger.always(tick_single), EffectType.Type.TICKING_TRIGGER, 5,
		"Fern will deal " + str(per_tick) + " damage to a random enemy.")
	volley.mag = per_tick
	volley.display_mag = true
	volley.damage_type = DamageType.Type.NORMAL
	apply_allied(context, user, volley)
	# The first of the three instances, right now.
	_fire(user, volley)

## Mana Control converts the whole remaining pool into output — and SPENDS it. Zeroing the storable
## colours is what stops one Mana Control turn from also funding the next, and it is why the
## enhanced modes are a deliberate all-in rather than a strict upgrade.
func burn_pool(fern) -> void:
	if fern == null or not is_instance_valid(fern) or fern.team == null or fern.team.energy == null:
		return
	var ep = fern.team.energy
	for color in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		var have: int = int(ep.pool.get(color, 0))
		if have > 0:
			fern.team.change_energy(color, -have)


func _live_enemies(fern) -> Array:
	var out := []
	if fern == null or fern.battle == null or not is_instance_valid(fern.battle):
		return out
	for c in fern.battle.all_characters():
		if c in fern.team.characters:
			continue
		if c.dead or c.banished:
			continue
		out.append(c)
	return out

## One instance of the unenhanced volley. Shared by the manual first instance in execute() and by
## the tick callback, so the opening salvo can never drift from the two that follow it. The Mana
## Control burst does NOT come through here - it plants no effect and resolves inline in execute().
func _fire(fern, eff) -> void:
	if fern == null or not is_instance_valid(fern) or fern.dead or fern.banished:
		return
	if fern.battle == null or not is_instance_valid(fern.battle):
		return
	var foes := _live_enemies(fern)
	if foes.is_empty():
		return
	var qc = QueryContext.from_game_state(fern, fern.battle)
	# battle.roll is the seeded RNG; randi would desync the authoritative shadow.
	var pick = foes[fern.battle.roll(0, len(foes) - 1, "Zoltraak Blasts target")]
	Character.resolve_effect_damage(qc, eff, pick, int(eff.mag), DamageType.Type.NORMAL)

func tick_single(context):
	_fire(context['effect'].user, context['effect'])

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	var fern = context['owner']
	# Enhanced: ONE hit on every living enemy. Unenhanced: three ticks on one enemy at a time.
	var worth: int = 0
	if mana_control_active(fern):
		worth = (aoe_base + aoe_per_energy * leftover_energy(fern)) * maxi(_live_enemies(fern).size(), 1)
	else:
		worth = base_damage * 3
	variations.append([20 + worth, [user, self, [user]]])
	return variations

# Self-targeted: the volley is an effect Fern carries, not a skill aimed at anyone.
func target(user, battle):
	default_self_target_function(user, battle)
