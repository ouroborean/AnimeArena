extends Ability

func describe(user):
	return "While not active, Jeanne heals 10 HP each turn and cannot be targeted by any character. While active, Jeanne can use her other skills. If Jeanne is the only character alive on her team, this skill is permanently activated."

func split_desc():
	return [
		"While active, Jeanne heals 10 HP each turn, cannot be targeted by any character, and any active Gibbet effects are ended",
		"While inactive, Jeanne can use her other skills",
		["Starts the game active, and becomes permanently inactive if Jeanne is the only targetable character alive on her team", Color.CADET_BLUE],
	]

# Installs the starting Iron Maiden state on Jeanne: Inactive mark + tick-heal + solo-watchers.
# Called from character/jeanne.gd.startup().
func install_initial_state(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.has_targetable_living_ally():
		_flip_to_inactive(context, user)

	# Per-turn polling backup. Catches "no targetable ally" transitions that
	# don't go through die() — e.g. an ally getting banished or having Sealed
	# King applied mid-round.
	var watcher = Effect.trigger_effect(
		Trigger.always(solo_survivor_check),
		EffectType.Type.TICKING_TRIGGER,
		-1,
		"")
	watcher.set_source(self)
	watcher.system = true
	Character.add_allied_effect(context, user, user, watcher)

	# Event-driven primary: collapse Iron Maiden the instant any teammate dies.
	# Required because TICKING_TRIGGER only fires during Jeanne's team's round
	# loop, so an ally dying on the enemy's turn could leave Jeanne stranded
	# untargetable for an entire turn. Placing an ON_DEATH_TRIGGER on every
	# team member catches the transition the moment die() runs.
	for ally in user.team.characters:
		var death_watcher = Effect.trigger_effect(
			Trigger.always(solo_survivor_check),
			EffectType.Type.ON_DEATH_TRIGGER,
			-1,
			"")
		death_watcher.set_source(self)
		death_watcher.system = true
		Character.add_allied_effect(context, user, ally, death_watcher)
	if not user.has_targetable_living_ally():
		if user.has_effect("Iron Maiden", EffectType.Type.MARK, user):
			_flip_to_active(user)

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.moveset.base_abilities[1].end_all_gibbets(user)
	if user.has_effect("Iron Maiden", EffectType.Type.MARK, user):
		_flip_to_active(user)
	else:
		_flip_to_inactive(context, user)

func _flip_to_inactive(context, user):
	if not user.has_effect("Iron Maiden", EffectType.Type.MARK, user):
		var mark = Effect.mark(-1, "Jeanne cannot be act or be targeted.")
		mark.set_source(self)
		mark.cleansable = false
		Character.add_allied_effect(context, user, user, mark)

	if not user.has_effect("Iron Maiden", EffectType.Type.HEALING, user):
		var heal = Effect.healing_effect(10, -1)
		heal.set_source(self)
		Character.add_allied_effect(context, user, user, heal)

func _flip_to_active(user):
	user.effects.remove_effect("Iron Maiden", EffectType.Type.MARK, user)
	user.effects.remove_effect("Iron Maiden", EffectType.Type.HEALING, user)

func solo_survivor_check(context):
	var jeanne = context['effect'].user
	if jeanne == null or jeanne.dead or jeanne.banished:
		return
	var dying = context.target
	for ally in jeanne.team.characters:
		if ally == jeanne:
			continue
		if ally == dying:
			continue
		if ally.dead or ally.banished:
			continue
		if ally.effects.has_effect("Iron Maiden", EffectType.Type.MARK, ally):
			continue
		if ally.effects.has_effect("Sealed King", EffectType.Type.MARK, ally):
			continue
		if ally.effects.has_effect("Sealed Nightmare", EffectType.Type.IGNORE_DAMAGE, ally):
			continue
		return  # at least one targetable living ally remains
	if jeanne.has_effect("Iron Maiden", EffectType.Type.MARK, jeanne):
		_flip_to_active(jeanne)

func extra_usable(user):
	return user.has_targetable_living_ally()

func custom_behavior(context):
	var inactive = user.has_effect("Iron Maiden", EffectType.Type.MARK, user) != null
	if inactive:
		return [[50, [user, ability_name, []]]]
	if user.health.hp < 30:
		return [[60, [user, ability_name, []]]]
	return []

func target(user, battle):
	default_self_target_function(user, battle)
