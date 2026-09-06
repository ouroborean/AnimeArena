extends Ability

# Whether the one-time on-death mark has already been placed. A flag on the (per-character, per-battle)
# ability instance, NOT an effect on Ichibe: at the moment on_ichibe_death fires he is already `dead`,
# so add_allied_effect's is_alive() gate would reject a marker placed on him.
var _used = false

func describe(user):
	return "The first time Ichibe dies, a random living ally is marked with Named Reconstitution. If that ally uses a new skill, Ichibe is revived with HP equal to that ally's current HP, but no longer generates energy for the rest of the match."

func split_desc():
	return [
		"The first time Ichibe dies, a random living ally is marked with Named Reconstitution.",
		["If that ally uses a new skill, Ichibe is revived with HP equal to the ally's current HP.", Color.CADET_BLUE],
		["After revival, Ichibe no longer generates energy for the rest of the match.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trig = Effect.trigger_effect(
		Trigger.always(on_ichibe_death),
		EffectType.Type.ON_DEATH_TRIGGER,
		-1,
		"On first death, a random ally is marked with Named Reconstitution.")
	trig.set_source(self)
	trig.system = true
	trig.remove_on_death = false
	Character.add_allied_effect(context, user, user, trig)

func on_ichibe_death(context):
	if _used:
		return
	var ichibe = context['effect'].user
	var candidates = []
	for ally in context.ally_team.characters:
		if ally == ichibe:
			continue
		if not (ally.dead or ally.banished):
			candidates.append(ally)
	if candidates.is_empty():
		return
	_used = true

	# Seeded engine die, not global randi(): keeps matches reproducible from their seed
	# (this was the engine's one gameplay-affecting global-RNG leak).
	var chosen = candidates[ichibe.battle.roll(0, candidates.size() - 1)]
	var revive_trig = Effect.trigger_effect(
		Trigger.always(on_ally_uses_skill),
		EffectType.Type.ACTION_USE_TRIGGER,
		-1,
		"Named Reconstitution: if this character uses a new skill, Ichibe is revived.")
	revive_trig.set_source(self)
	revive_trig.remove_on_death = false
	# Apply with the ALLY as the effect's user, so cleanse_death_effects(Ichibe) — which erases every
	# effect whose user is the dying Ichibe — leaves it intact. on_ally_uses_skill recovers Ichibe from
	# the effect's SOURCE (this ability), whose owner is always Ichibe regardless of the effect's user.
	Character.add_allied_effect(context, chosen, chosen, revive_trig)

func on_ally_uses_skill(context):
	var ally = context['owner']
	var trigger_eff = context['effect']
	var ichibe = trigger_eff.source.user   # source is this ability; its owner is Ichibe
	if ichibe == null or not ichibe.dead:
		return
	ichibe.dead = false
	ichibe.health.set_health(ally.health.hp)
	ichibe.update.emit()

	var lockout = Effect.mark(-1, "Ichibe no longer generates energy.")
	lockout.set_source(self)
	lockout.remove_on_death = false
	lockout.cleansable = false
	Character.add_allied_effect(context, ichibe, ichibe, lockout)

	ally.effects.erase_effect(trigger_eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	return [[0, [user, "PASS", []]]]

func target(user, battle):
	default_self_target_function(user, battle)
