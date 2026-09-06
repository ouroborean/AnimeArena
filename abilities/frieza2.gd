extends Ability
var base_shield = 35
var decay_per_use = 5

# Nova Strike. Frieza shields himself, and at the end of his next turn whatever is LEFT of that
# shield is hurled at a random enemy — so the skill pays out most when the enemy declined to swing
# into it, and pays little when it actually did its job absorbing a hit.
#
# TIMING. The payout is a TICKING_TRIGGER, the engine's primitive for "on your turn":
#   * A side's ticking effects are gathered BEFORE that turn's abilities run
#     (battle_manager.process_turn_package:1601 → start_round_loop:1619), so a ticker planted here
#     can never fire on its own cast turn. That is exactly what this skill wants — the shield has to
#     survive the ENEMY's turn first for the payout to mean anything.
#   * Ticking keys are appended AFTER the acting player's ability steps in true_execution_order
#     (battle_manager.gd:1613), so it resolves at the END of Frieza's next turn, not the start.
#   * get_ticking_effects only collects effects whose user is on the ACTING side, so it needs no
#     side-gate of its own — which is why this is a ticker and not the START_OF_TURN_TRIGGER it used
#     to be (that fires for BOTH teams every turn and had to be hand-gated, and it landed at the
#     start of Frieza's turn rather than the end).
#
# Duration 3 on both the Shield and the ticker: applied on turn T they tick to 2 at the end of T and
# to 1 at the end of T+1, so on T+2 — Frieza's next turn — the ticker fires with the Shield still
# standing. The Shield therefore also covers Frieza's own next turn right up until he throws it,
# which is what "whatever is left" means.
#
# The decay is stored in a permanent self-MARK's mag rather than a member var: an Ability instance is
# rebuilt per match and, more importantly, a plain var would not survive a reconnect resync.

const SHIELD_NAME := "Nova Strike"
const COUNTER := "Nova Strike Decay"

func describe(user):
	return "Frieza gains 35 Shield. At the end of his next turn, whatever remains of that Shield is dealt as damage to a random enemy. The Shield this skill grants is reduced by 5 each time it is used."

func split_desc():
	return [
		"Frieza gains 35 Shield",
		["At the end of his next turn, any of that Shield still standing is dealt as damage to a random enemy", Color.CADET_BLUE],
		["The Shield this skill grants is reduced by 5 each time it is used", Color.DIM_GRAY],
	]

# Also read by the bot hint and by the client-side description, so keep it side-effect free.
func shield_amount(check_user) -> int:
	if check_user == null:
		return base_shield
	var counter = check_user.has_effect(COUNTER, EffectType.Type.MARK, check_user)
	var used: int = counter.mag if counter else 0
	return maxi(0, base_shield - decay_per_use * used)

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var amount := shield_amount(user)
	if amount > 0:
		apply_allied(context, user, Effect.shield_effect(amount, 3))

	# The defender needs to know that the shield in front of them becomes a projectile at the end of
	# Frieza's next turn — hence display_system. But it is ALSO `system`, and that is what keeps it out
	# of the end-turn reorder preview (_serialize_execution_preview): that list is player-authored, so
	# a draggable ticking step could be moved ahead of Frieza's own skills and break the "at the end of
	# his next turn" this skill promises. A system ticking key the client never sends is appended last
	# by process_turn_package, so it always resolves where the text says it does.
	var payout = Effect.trigger_effect(Trigger.always(nova_payout), EffectType.Type.TICKING_TRIGGER, 3,
		"Frieza's remaining Nova Strike Shield will be dealt as damage to a random enemy.")
	payout.system = true
	payout.display_system = true
	payout.damage_type = DamageType.Type.NORMAL
	apply_allied(context, user, payout)

	var counter = user.has_effect(COUNTER, EffectType.Type.MARK, user)
	if counter:
		counter.mag += 1
		counter.effect_updated.emit(counter)
	else:
		var m = Effect.mark(-1, decay_desc)
		# Named explicitly: without the override an effect takes its SOURCE ability's name, so this
		# would be "Nova Strike" — the same name as the Shield it is supposed to be sizing.
		m.name_override = COUNTER
		m.mag = 1
		# Visible. How much Shield the next Nova Strike will actually grant is not hidden
		# information, and it changes how both players value the skill.
		# Not cleansable. This counter only ever makes Nova Strike WORSE, so leaving it strippable
		# would mean an enemy buff-strip resets the shield to a full 35 — a hostile skill handing
		# Frieza an upgrade. ("Cleanse what re-earns, protect what stripping permanently kills"
		# cuts the other way for a decay counter.)
		m.cleansable = false
		apply_allied(context, user, m)

func decay_desc(eff):
	return "Nova Strike will grant " + str(maxi(0, base_shield - decay_per_use * int(eff.mag))) + " Shield."

func nova_payout(context):
	var eff = context['effect']
	var frieza = eff.user
	if frieza == null or not is_instance_valid(frieza):
		return
	var battle = frieza.battle
	if battle == null or not is_instance_valid(battle):
		return
	# A one-shot promise about ONE specific shield. The duration arithmetic already gives it exactly
	# one firing, but latch anyway: a ticker left armed would pay out again on the turn after next.
	if eff.triggered:
		return
	eff.triggered = true
	_pay_out(context, eff, frieza, battle)
	# Consumed LAST, and on every path — resolve_effect_damage above still reads this effect.
	frieza.effects.consume_effect(eff)

func _pay_out(context, eff, frieza, battle) -> void:
	if frieza.dead or frieza.banished:
		return
	# Read only THIS shield, not the team total — an ally's shield on Frieza is not Nova Strike's to spend.
	var shield = frieza.has_effect(SHIELD_NAME, EffectType.Type.SHIELD, frieza)
	if shield == null or shield.mag <= 0:
		return
	# PICK THE TARGET FIRST. Zeroing the Shield before checking would burn it for nothing if there is
	# nobody left to throw it at.
	var candidates = []
	for c in battle.all_characters():
		if c in frieza.team.characters:
			continue
		if c.dead or c.banished:
			continue
		candidates.append(c)
	if candidates.is_empty():
		return
	var payload := int(shield.mag)
	# Spend it: the stored energy becomes the projectile.
	shield.mag = 0
	frieza.effects.consume_effect(shield)
	# battle.roll is the seeded RNG; a raw randi would desync the authoritative shadow.
	var pick = candidates[battle.roll(0, len(candidates) - 1)]
	Character.resolve_effect_damage(context, eff, pick, payload, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	# behavior_self_panic_button scores -30 + base_mod + (100 - hp). Nova Strike is not a pure panic
	# button — the shield it does not spend becomes damage — so it has to stay POSITIVE at full
	# health or the bot would never open with it (base_mod 20 scored -10 at 100 HP and lost to
	# every alternative, including PASS at 0).
	return behavior_self_panic_button(context, 45)

func target(user, battle):
	default_self_target_function(user, battle)
