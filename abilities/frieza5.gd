extends Ability
var base_damage = 10
var per_stack = 5
var stacks_applied = 2

const PILE := "Death Beam"

# Death Beam Barrage. The hidden swap-in that Death Beam hands slot 0 every 3rd cast (see frieza1).
# It hits every enemy already carrying Death Beam stacks and doubles the rate the pile grows, so the
# reward for staying on one target is a burst that also spreads to anyone else Frieza has tagged.
#
# Its stacks carry name_override = "Death Beam" so they merge into the one pile that frieza1 scales
# off and Last Emperor reads. Pinning the NAME rather than borrowing frieza1 as the source is what
# keeps this safe when a copy/steal mechanic runs Barrage from someone else: reaching into
# `user.moveset.base_abilities[0]` for the stack factory crashed outright on any non-Frieza caster.

func describe(user):
	return "Deals 10 Piercing damage to any enemy with stacks of Death Beam, dealing 5 more damage per stack. Applies 2 more stacks of Death Beam to each enemy hit."

func split_desc():
	return [
		"Deals 10 Piercing damage to every enemy with a stack of Death Beam",
		["Deals 5 more damage per stack of Death Beam on that enemy", Color.CADET_BLUE],
		"Applies 2 stacks of Death Beam to each enemy hit",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var existing = target.has_effect(PILE, EffectType.Type.MARK, user)
		if existing == null:
			continue
		# Read before applying: the stacks this cast adds must not pay their own bonus.
		var stacks: int = existing.stack_count()
		Character.resolve_damage(context, target, base_damage + per_stack * stacks, DamageType.Type.PIERCING)
		# A fresh mark with stacks = 2; add_effect merges into the existing pile by summing.
		Character.add_hostile_effect(context, user, target, build_stack(stacks_applied))

# Mirrors frieza1.build_stack. Kept local (rather than delegating) so the ability never assumes
# anything about the caster's own moveset — see the header note.
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
	var context = QueryContext.from_game_state(user, user.battle)
	for character in user.battle.all_characters():
		if character in user.team.characters:
			continue
		if character.dead or character.banished:
			continue
		if Condition.has_effect(character, PILE, EffectType.Type.MARK, user).satisfied(context):
			return true
	return false

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, base_damage + per_stack)

# Only enemies already carrying stacks are valid; target_type ALL then sweeps in every one of them.
func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if Condition.has_effect(character, PILE, EffectType.Type.MARK, user).satisfied(context):
			check_hostile_target(user, character, context)
