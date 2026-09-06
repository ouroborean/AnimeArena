extends Ability
var base_damage = 20
var per_stack = 5
var swap_every = 3

const PILE := "Death Beam"
const COUNTER := "Death Beam Focus"

# Death Beam. The engine of Frieza's kit: every cast leaves a stack on the target and scales off the
# stacks already there, so the same button gets stronger the longer it stays pointed at one enemy.
#
# The stack pile is named after THIS ability (an effect's display name is its SOURCE ability's name),
# which is why Death Beam Barrage sources its stacks from base_abilities[0] instead of from itself —
# both skills feed one pile that both can read. killua1/killua2 -> killua3 is the shipped precedent.
#
# Use counting lives in a permanent self-MARK's mag (the tsubasa3 idiom) rather than a member var: an
# Ability instance is rebuilt per match, and more importantly a plain var would not survive the
# reconnect resync the way an effect does.

func describe(user):
	return "Deals 20 Piercing damage to target enemy and gives them 1 stack of Death Beam. This skill deals 5 more damage per stack of Death Beam already on the target. Every 3rd use, this skill is replaced by Death Beam Barrage for 1 turn."

func split_desc():
	return [
		"Deals 20 Piercing damage to target enemy",
		"Applies 1 stack of Death Beam",
		["Deals 5 more damage per stack of Death Beam already on the target", Color.CADET_BLUE],
		["Every 3rd use, this skill is replaced by Death Beam Barrage for 1 turn", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Read the pile BEFORE applying, or the stack this cast adds would pay its own bonus.
		var existing = target.has_effect(PILE, EffectType.Type.MARK, user)
		var stacks: int = existing.stack_count() if existing else 0
		Character.resolve_damage(context, target, base_damage + per_stack * stacks, DamageType.Type.PIERCING)
		Character.add_hostile_effect(context, user, target, build_stack(1))
	advance_counter(context, user)

# Every 3rd use hands slot 0 to Death Beam Barrage (base_abilities[4]) for one turn.
func advance_counter(context, user):
	var counter = user.has_effect(COUNTER, EffectType.Type.MARK, user)
	var uses: int = (counter.mag if counter else 0) + 1
	if uses >= swap_every:
		# Applied unconditionally. tsubasa3 guards the equivalent swap on silence, but that guard
		# is stale: since the Silence v2 rewrite, add_allied_effect has no silence gate at all
		# (character_component.gd:2048) — Silence is purely a usability gate, and Death Beam is
		# Damaging, so a silenced Frieza can still cast it and has earned the swap.
		apply_allied(context, user, Effect.ability_swap_effect(4, 0, user, 3))
		if counter:
			user.effects.remove_effect(COUNTER, EffectType.Type.MARK, user)
		return
	if counter:
		counter.mag = uses
		counter.effect_updated.emit(counter)
	else:
		var m = Effect.mark(-1, counter_desc)
		# An effect's name is its SOURCE ability's name unless overridden, and the source here has to
		# stay Death Beam (get_active_abilities only honours swaps whose source is in base_abilities).
		# Without the override this bookkeeping mark would be called "Death Beam" too and collide with
		# the stack pile, so the lookup above would never find it and the swap would never fire.
		m.name_override = COUNTER
		m.mag = uses
		# Visible, and with the number on the badge. How close Frieza is to Death Beam Barrage is not
		# hidden information — it is the single most important read on the matchup for the defender,
		# who has one turn of warning to prepare for a team-wide beam.
		m.display_mag = true
		apply_allied(context, user, m)

## Phrased in USES SO FAR, matching the number on the badge (see display_mag in advance_counter).
## A badge reading "1" beside a tooltip saying "in 2 uses" would contradict itself, and every other
## badge in the kit (Shield mag, Death Beam stacks, Gather stacks) is a quantity — so "1" would read
## as "1 use left", the opposite of the truth.
func counter_desc(eff):
	var used: int = int(eff.mag)
	var count_word := "once" if used == 1 else ("twice" if used == 2 else str(used) + " times")
	if used >= swap_every - 1:
		return "Death Beam has been used " + count_word + ". The next use is replaced by Death Beam Barrage."
	return "Death Beam has been used " + count_word + "; " + str(swap_every) + " uses summon Death Beam Barrage."

## The stack pile. Death Beam Barrage builds an identical one so both skills feed ONE named pile;
## the name is pinned with name_override rather than inherited from the source, so neither ability
## has to reach into the other's moveset to make a stack (frieza5 did, and crashed outright when a
## copy/steal mechanic ran Barrage from a caster whose base_abilities[0] was not Death Beam).
## Deliberately not `system`: the stack count is the whole read of this matchup and both players
## need to see it. That does mean the pile is stripped by the death-cleanse when Frieza dies, but
## death TRIGGERS run first, so Last Emperor still sees it.
func build_stack(count: int):
	var stack_desc = func (eff):
		return "This character has " + str(eff.stack_count()) + " stacks of Death Beam."
	var mark = Effect.mark(-1, stack_desc)
	mark.stackable = true
	mark.display_stacks = true
	mark.stacks = count
	mark.name_override = PILE
	mark.set_source(self)
	return mark

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	for character in context['enemy_team'].characters:
		if character.is_invuln(self) or character.dead or character.banished:
			continue
		var mark = character.has_effect(PILE, EffectType.Type.MARK, context['owner'])
		var stacks: int = mark.stack_count() if mark else 0
		# Score by what the beam would actually hit for, doubled on the stack term, so the bot
		# concentrates fire instead of spreading stacks it can never cash in.
		variations.append([100 + base_damage + per_stack * stacks * 2, [user, self, [character]]])
	if variations.is_empty():
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
