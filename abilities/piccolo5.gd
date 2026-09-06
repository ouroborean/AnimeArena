extends Ability

# Namekian Power (PASSIVE) — also the shared host for Piccolo's channel machinery (escanor5 pattern:
# the channel skills call these via user.moveset.base_abilities[4]).
#
# Owner-confirmed lifecycle (2026-08-14): a channel ends on any of three triggers, and EVERY end grants
# +5 permanent Shield per turn channeled and puts the channeled skill on cooldown 1:
#   * RE-USE the same skill  -> also fires that skill's payoff (handled in the skill's execute).
#   * USE a different skill   -> shield + CD only (the new skill's execute finishes the old channel).
#   * ENEMY disruption (stun/seal) -> shield + CD + gain 1 Green. Detected by check_cancels ending the
#     CHANNEL_CANCEL master, which fires on_interrupt (this effect's wrapup_func).
#
# "Turns channeled" is tracked on the master's `mag` (the channel tick + the initial start both bump it),
# so it survives even after check_cancels frees the stack mark.

const SHIELD_PER_TURN = 5

func describe(user):
	return ""

func split_desc():
	return [
		"Whenever Piccolo's Channeling ends, he gains 5 permanent Shield for each turn he spent Channeling and that skill goes on cooldown for 1 turn",
		["Re-using the channeled skill fires its payoff; using a different skill ends the channel with no payoff", Color.CADET_BLUE],
		["If an enemy interrupts his Channeling (Stun/Seal), he instead gains 1 Green energy", Color.AQUA]
	]

func execute(user, battle):
	pass   # passive: all behaviour is driven from the channel skills + on_interrupt

# --- shared channel end. cause in {"reuse", "switch", "interrupt"} -----------------------------------
func finish_channel(piccolo, master, cause):
	if piccolo == null or not is_instance_valid(master):
		return
	var turns = int(master.mag)
	var ctx = QueryContext.from_game_state(piccolo, piccolo.battle)
	if turns > 0:
		var sh = Effect.shield_effect(SHIELD_PER_TURN * turns, -1)
		sh.set_source(self)
		Character.add_allied_effect(ctx, piccolo, piccolo, sh)
	# The channeled skill goes on cooldown for 1 turn. Its printed cd is 0, so set the remaining
	# directly. The value differs by WHOSE turn we're on: a voluntary end runs inside Piccolo's own
	# turn, so its advance_cooldowns reclaims the +1 bookkeeping this same turn (cooldown_remaining=2
	# settles to 1 — see [[cooldown-plus-one-bookkeeping]]). An enemy INTERRUPT fires from
	# check_cancels DURING THE ENEMY'S TURN, so Piccolo's advance_cooldowns will NOT run this turn to
	# take the +1 back; setting 2 would strand it and lock the skill out for 2 Piccolo turns instead
	# of 1. So the interrupt path sets the already-settled value (1) with no stamp.
	var skill = master.source
	if skill != null and is_instance_valid(skill):
		if cause == "interrupt":
			skill.cooldown_remaining = 1
			skill.cooldown_started_turn = -1
		else:
			skill.cooldown_remaining = 2
			skill.cooldown_started_turn = int(piccolo.battle.current_turn_number)
	if cause == "interrupt":
		piccolo.gain_bonus_energy(Energy.Type.GREEN)
	else:
		# Voluntary end (re-use / switch): tear the channel effects down ourselves. The interrupt path
		# is torn down by check_cancels (_end_cancel_effects), so it must NOT double-teardown here.
		master.set_meta("voluntary_end", true)
		_teardown(master)

func _teardown(master):
	for eff in master.cancel_effects:
		if is_instance_valid(eff) and not eff.is_queued_for_deletion() and not eff.removed:
			eff.end_effect()
	if is_instance_valid(master) and not master.removed:
		master.end_effect()   # wrapup fires but the voluntary_end meta makes on_interrupt bail

# Master's wrapup_func — only reached when check_cancels ends the channel (enemy Stun/Seal), because
# Piccolo's own skills all carry "Preserves Channel" so they never route through cancel_channels().
func on_interrupt(context):
	var master = context['effect']
	if master == null or master.get_meta("voluntary_end", false):
		return
	var piccolo = master.user
	if piccolo == null or piccolo.dead or piccolo.banished:
		return
	finish_channel(piccolo, master, "interrupt")
