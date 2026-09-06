extends Ability
var base_damage = 45
var per_energy = 20
var enhanced_base = 10

const MANA := "Mana Control"

# Zoltraak Beam. Flat and reliable on its own; under Mana Control it stops being a fixed number and
# becomes a payout on Fern's unspent mana — which turns her whole turn into a budgeting decision,
# because every other skill her team casts eats into it.
#
# TIMING — why "the energy left after all skills are paid for" is readable from inside execute():
# process_turn_package reserves EVERY queued cost into promised_pool ("new multiplayer/
# battle_manager.gd" team.pay_for_ability, inside the character_actions loop), then commits the whole
# turn's spend via receive_generic_allocation_offer (clear promised, drain pool), and only THEN
# reaches start_round_loop(). So by the time any ability executes, the team pool already reflects
# the entire turn. Subtracting promised as well makes the read correct at either point.
#
# NOTE: the four bot drivers (scripts/player_component.gd) execute FIRST and pay AFTER, so a
# bot-controlled Fern would read her own cost as still available. Fern is deliberately excluded from
# bot team selection (components/server_connection.gd's `excluded` list), so that path is unreachable.

func describe(user):
	return "Deals 45 Piercing damage to target enemy. If Mana Control is active, this skill instead deals 10 Piercing damage plus 20 Piercing damage for each energy left in Fern's pool when it executes (after all skills are paid for), consuming all of that energy."

func split_desc():
	return [
		"Deals 45 Piercing damage to target enemy",
		["If Mana Control is active, instead deals 10 Piercing plus 20 Piercing per energy left in Fern's pool after all skills are paid for", Color.CADET_BLUE],
		["That energy is all consumed", Color.DIM_GRAY],
	]

func mana_control_active(fern) -> bool:
	return fern != null and is_instance_valid(fern) and fern.marked_by(MANA, fern) != null

## Storable energy still available to Fern's team at this instant. RANDOM is never summed out of
## `pool` — it is a cost token, not a storable colour (components/energypool.gd) — but a RANDOM
## PROMISE does hold real colours hostage, so it is subtracted. maxi() on each promise because
## lose_promised_energy has no floor and a refund without a matching payment could otherwise drive
## a promise negative and inflate the read.
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
	# Read once, before the first hit can change anything, so a blind-retargeted multi-hit is even.
	var dmg: int = base_damage
	var enhanced := mana_control_active(user)
	if enhanced:
		dmg = enhanced_base + per_energy * leftover_energy(user)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, dmg, DamageType.Type.PIERCING)
	# Read the pool BEFORE burning it, then spend it: the damage above is the whole bank.
	if enhanced:
		burn_pool(user)

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


func extra_usable(user):
	return true

func custom_behavior(context):
	var fern = context['owner']
	var dmg: int = (enhanced_base + per_energy * leftover_energy(fern)) if mana_control_active(fern) else base_damage
	return behavior_single_target_damage(context, dmg)

func target(user, battle):
	default_hostile_target_function(user, battle)
