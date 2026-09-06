extends Ability
var heal_per_turn = 10
var budget = 20

const COWARDICE := "Cowardice"

# Cowardice. Stark stops shielding the team and starts hiding behind it: Superhuman Resilience goes
# dark for three turns, he regenerates, and up to 20 of the damage HE takes each turn is pushed back
# onto his allies, split evenly. It is the release valve for a Stark who has soaked too much — and
# the cost is that everyone else pays for it.
#
# The mark IS the state. stark5.suppressed() and this ability's own metering both key off it, so the
# passive going dark and the reverse redirect can never be out of step.
#
# Duration 6 = three of Stark's turns (durations tick at the end of EVERY player's turn).

var remaining: int = 0

func describe(user):
	return "For 3 turns, Stark's Superhuman Resilience is disabled. During this time he heals 10 HP per turn and redirects up to 20 damage he takes each turn to his allies, split equally."

func split_desc():
	return [
		["For 3 turns, Superhuman Resilience is disabled", Color.DIM_GRAY],
		["Stark heals 10 HP per turn", Color.LIGHT_GREEN],
		["Up to 20 damage he takes each turn is redirected to his allies, split equally", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	remaining = budget
	# Effect tooltips: mechanically explicit, brief, and never repeating what a sibling effect or the
	# effect type already says. The heal belongs to the ticking effect's own tooltip, so this one
	# carries only what nothing else does — the suppression and the exact reflection.
	var mark = Effect.mark(6, "Superhuman Resilience is disabled. Up to 20 damage Stark takes each turn is reflected to his allies, split equally.")
	apply_allied(context, user, mark)
	# The reverse redirect sits on STARK, because he is the one taking the damage. character_target
	# is left null: take_redirect_budget splits across whoever is still standing at the moment of
	# the hit rather than a list captured at cast time.
	var redirect = Effect.redirect_effect(0.0, null, 6)
	redirect.set_source(self)
	# The factory's stock description does character_target.character_name -- which is null here by
	# design, since the receivers are recomputed per hit. Override it, and mark the effect system so
	# the wire serializer skips it entirely rather than baking a description for machinery.
	redirect.description = func (eff):
		return "Up to 20 damage Stark takes each turn is redirected to his allies, split equally."
	redirect.system = true
	redirect.invisible = true
	Character.add_allied_effect(context, user, user, redirect)
	# THE REGEN IS A TICKING_TRIGGER — the primitive for anything that happens on each of the
	# caster's turns. It fires only for the acting side, so it needs no side-gate, and it does not
	# fire on the turn it was planted (a side's ticking effects are snapshotted before that turn's
	# abilities run), so the first heal is dealt by hand below. Duration 5 supplies the two later
	# ones: [+0, +2, +4], the same three turns the mark and the redirect cover.
	# "on each of his turns" and "while Cowardice lasts" are both implied — every ticking effect runs
	# on its user's turns, and every effect stops when it ends.
	var regen = Effect.trigger_effect(Trigger.always(heal_tick), EffectType.Type.TICKING_TRIGGER, 5,
		"Stark will heal 10 HP.")
	regen.set_source(self)
	Character.add_allied_effect(context, user, user, regen)
	# The first of the three heals, on the turn it was cast.
	Character.resolve_effect_healing(context, regen, user, heal_per_turn)
	# The reverse redirect's budget is separate machinery: it has to reset on EVERY turn, not just
	# Stark's, because he can be attacked on either side's turn. START_OF_TURN fires for both teams,
	# which a TICKING_TRIGGER deliberately does not.
	var refill = Effect.trigger_effect(Trigger.always(budget_tick), EffectType.Type.START_OF_TURN_TRIGGER, 6, "")
	refill.set_source(self)
	refill.invisible = true
	refill.system = true
	Character.add_allied_effect(context, user, user, refill)

## Ticking effects only run for the acting side, so this is already once per Stark turn.
func heal_tick(context):
	var eff = context['effect']
	var stark = eff.user
	if stark == null or not is_instance_valid(stark) or stark.battle == null:
		return
	if stark.dead or stark.banished:
		return
	var qc = QueryContext.from_game_state(stark, stark.battle)
	Character.resolve_effect_healing(qc, eff, stark, heal_per_turn)


## Refills the reverse redirect's per-turn allowance. Every turn, both sides.
func budget_tick(context):
	remaining = budget

## Engine hook — see stark5.take_redirect_budget. Here the flow is reversed: Stark is the target and
## his allies are the receivers. `origin` is unused: this direction already splits every single hit
## across all of Stark's living allies, so there is no per-skill sharing left to arrange.
func take_redirect_budget(source, damage, target, damage_type, redirect, origin = null):
	var receivers := []
	for ally in target.team.characters:
		if ally == target or ally.dead or ally.banished:
			continue
		receivers.append(ally)
	# Nobody left to hide behind — Stark eats it himself.
	if receivers.is_empty():
		return damage
	var moved: int = int(min(int(damage), remaining))
	if moved <= 0:
		return damage
	# Split evenly; a remainder that will not divide is dropped rather than dumped on one ally, so
	# "split equally" is literally true and the numbers always add up.
	var share: int = int(moved / receivers.size())
	if share <= 0:
		return damage
	var actually_moved: int = share * receivers.size()
	remaining -= actually_moved
	for r in receivers:
		source.deal_effect_damage(redirect, share, r, damage_type, true)
	return damage - actually_moved

func extra_usable(user):
	return true

func custom_behavior(context):
	# A panic button that trades the team's health for his own — worth more the lower he is.
	return behavior_self_panic_button(context, 35)

func target(user, battle):
	default_self_target_function(user, battle)
