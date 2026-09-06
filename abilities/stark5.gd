extends Ability
var budget = 20

const RESILIENCE := "Superhuman Resilience"
const COWARDICE := "Cowardice"

# Superhuman Resilience. Stark's identity: he stands in front of the team. Every turn he will eat up
# to 20 of the damage his allies would have taken, and the budget is SHARED — two allies hit for 15
# each move 20 total onto him, not 40, and they SPLIT it (10 each) rather than the first one hit
# taking the lot. See the sharing section at the bottom of this file.
#
# HOW THE SHARING WORKS. The engine's default DAMAGE_REDIRECT moves a fixed FRACTION of a hit to one
# character (scripts/character_component.gd check_damage_redirect), which cannot express a shared
# absolute pool: one effect per ally means one budget per ally. So a redirect whose SOURCE exposes
# take_redirect_budget() hands the decision back to the ability, and this ability keeps the single
# remaining figure. One pool, any number of protected allies.
#
# The pool refills at the start of every turn via a permanent self trigger. START_OF_TURN fires for
# both sides each turn, which is exactly the cadence "each turn" asks for.

var remaining: int = 0

func describe(user):
	return "Stark redirects up to 20 total damage his allies would take onto himself each turn, shared between everyone hit by the same skill."

func split_desc():
	return [
		["Each turn, up to 20 total damage Stark's allies would take is redirected onto him", Color.CADET_BLUE],
		["Shared between everyone hit by the same skill", Color.DIM_GRAY],
	]

# Cowardice suspends this passive while it runs. Keyed off Cowardice's own mark so the two can
# never disagree about which one is in charge.
func suppressed(stark) -> bool:
	return stark != null and is_instance_valid(stark) and stark.marked_by(COWARDICE, stark) != null

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	remaining = budget
	# One redirect brand per ally. They all name this ability as their source, so they all drain the
	# single `remaining` above.
	for ally in user.team.characters:
		if ally == user:
			continue
		_brand(context, user, ally)
	# Refill each turn, and pick up allies who were dead or banished at battle start.
	var ticker = Effect.trigger_effect(Trigger.always(refill), EffectType.Type.START_OF_TURN_TRIGGER, -1,
		"Stark's Superhuman Resilience budget refills each turn.")
	ticker.set_source(self)
	# system AND remove_on_death: the death cleanse keeps a dying character's own effects only when
	# BOTH hold (effect_storage_component.get_all_death_cleansable_effects). system alone is not
	# enough, and startup_passives never re-runs, so without this a revived Stark loses the passive
	# for the rest of the match. death5.gd is the shipped precedent.
	ticker.system = true
	ticker.remove_on_death = false
	Character.add_allied_effect(context, user, user, ticker)

func _brand(context, stark, ally):
	for eff in ally.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT):
		if eff.source == self:
			return
	# mag is unused in metered mode (take_redirect_budget decides the amount), but it must stay a
	# number: the default branch would multiply by it, and the wire serializer int()s it.
	var redirect = Effect.redirect_effect(0.0, stark, -1)
	redirect.set_source(self)
	# The factory's stock text is built from mag as a percentage, which in metered mode would read
	# the literally-false "redirects 0.0% of damage taken". Say what actually happens instead.
	redirect.description = func (eff):
		return "Damage this character takes is redirected to Stark, up to " + str(budget) + " total across his allies each turn, shared between everyone hit by the same skill."
	redirect.system = true
	redirect.remove_on_death = false   # see the ticker above
	# WHO is currently under Stark's umbrella decides who the opponent should be attacking — it is
	# public state, not machinery. system is here only for revive survival; display_system keeps that
	# and puts the brand back on both players' screens (Effect.display_system).
	redirect.display_system = true
	Character.add_allied_effect(context, stark, ally, redirect)

func refill(context):
	var stark = context['effect'].user
	if stark == null or not is_instance_valid(stark):
		return
	remaining = budget
	# Drop the previous turn's per-skill ledger with the pool it metered. The group key already
	# carries the turn number so a stale group could never be matched again — this just stops
	# _group_seen holding Character references past the turn they were relevant in.
	_group_key = ""
	_group_seen = {}
	if stark.dead or stark.banished or stark.battle == null:
		return
	var qc = QueryContext.from_game_state(stark, stark.battle)
	for ally in stark.team.characters:
		if ally == stark or ally.dead or ally.banished:
			continue
		_brand(qc, stark, ally)

## Called by the engine from check_damage_redirect. Returns the damage the ORIGINAL target should
## still take after Stark absorbs his share. Only ever fires for effects this ability sourced.
func take_redirect_budget(source, damage, target, damage_type, redirect, origin = null):
	var stark = redirect.character_target
	if stark == null or not is_instance_valid(stark):
		return damage
	# Cowardice explicitly turns this off; a dead, banished or Invulnerable Stark cannot cover
	# anyone either — the damage stays on the ally rather than vanishing.
	if suppressed(stark) or stark.dead or stark.banished or stark.is_invuln(null):
		return damage
	var moved: int = int(min(int(damage), _share_for(source, target, origin)))
	if moved <= 0:
		return damage
	remaining -= moved
	source.deal_effect_damage(redirect, moved, stark, damage_type, true)
	return damage - moved


# ---------------------------------------------------------------------------
# Sharing the pool WITHIN one skill
# ---------------------------------------------------------------------------
# Owner ruling: the 20 is shared across everyone hit by the SAME skill, not handed out
# first-come-first-served. Without this, an AoE resolves its targets in order and the first
# protected ally can swallow the entire pool — X-Burner (25 to the main target, 10 to the others)
# put 20 on the first ally's hit and left the second completely uncovered.
#
# The split is "this draw, plus everyone still queued behind it": a target draws
# floor(remaining / (1 + protected targets after it that have not drawn yet)). That is deliberately
# counted FORWARD at each draw rather than divided by a participant count fixed up front, because a
# fixed divisor is wrong in both directions:
#   * it OVER-counts anyone the damage pipeline skips entirely — an ally who is Invulnerable, is
#     ignoring damage, or gets shielded to zero never reaches this hook, and a reserved slice for
#     them would simply be stranded. Counting forward gives it to whoever is actually left.
#   * it mis-handles a skill that hits the same character twice (nonon5's Overture Barrage). A repeat
#     draw shares with the targets still behind it instead of being handed the last slice.
# An indivisible remainder therefore lands on the LAST drawer rather than being dropped, and a share
# an ally does not need (it took less damage than its slice) rolls straight on to the next one —
# anything still unspent stays in the turn's pool for whatever else lands this turn.
#
# Only a real skill is split. A DoT tick, a counter or a reactive is one hit with one victim, so
# there is nothing to share it with; those draw the whole remaining pool exactly as before. The same
# is true of a skill that damages characters OUTSIDE its own target list (tatsumaki2, shinoa5): they
# are invisible to the count, so those degrade to first-come — no worse than before this change.
var _group_key: String = ""
var _group_seen: Dictionary = {}

func _share_for(attacker, target, origin) -> int:
	if remaining <= 0:
		return 0
	var key := _group_key_for(attacker, origin)
	if key == "":
		return remaining
	if key != _group_key:
		_group_key = key
		_group_seen = {}
	var left: int = 1 + _pending_after(attacker, target)
	_group_seen[target] = true
	return int(remaining / left)


## Identity of "one execution of one skill". The Ability instance is per-character and executes once
## per turn, so instance + turn is unique; two characters can never share an instance. Effect damage
## (DoTs, reactives) deliberately returns "" — see the note above.
func _group_key_for(attacker, origin) -> String:
	if attacker == null or not is_instance_valid(attacker) or not (origin is Ability):
		return ""
	var turn: int = -1
	if attacker.battle != null and is_instance_valid(attacker.battle):
		turn = int(attacker.battle.current_turn_number)
	return str(attacker.get_instance_id()) + "@" + str(origin.get_instance_id()) + "@" + str(turn)


## Protected characters this skill has still to reach: branded, alive, positioned AFTER `target` in
## the attacker's target list, and not already metered in this group. Returns 0 when the victim is
## not in the target list at all (damage dealt outside the targeter) — there is nothing visible to
## share with, so that draw takes what is left.
func _pending_after(attacker, target) -> int:
	if attacker == null or not is_instance_valid(attacker) or attacker.targeter == null:
		return 0
	var targets: Array = attacker.targeter.targets
	var idx: int = targets.find(target)
	if idx < 0:
		return 0
	var n := 0
	for i in range(idx + 1, targets.size()):
		var t = targets[i]
		if t == null or not is_instance_valid(t) or t.dead or t.banished:
			continue
		if _group_seen.has(t):
			continue
		if _is_branded(t):
			n += 1
	return n


func _is_branded(character) -> bool:
	for eff in character.effects.get_effects_by_type(EffectType.Type.DAMAGE_REDIRECT):
		if eff.source == self:
			return true
	return false

func extra_usable(user):
	return true

func target(user, battle):
	default_self_target_function(user, battle)
