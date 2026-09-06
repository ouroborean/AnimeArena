extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Yubel is permanently Isolated. As long as Yubel has targetable allies, she ignores all Harmful non-damage effects. Each time Yubel is the primary target of a Harmful skill, she gains 1 stack of Terror Incarnate."

func split_desc():
	return [
		["While Yubel has targetable allies, she ignores all Harmful non-damage effects", Color.CADET_BLUE],
		"Each Harmful skill that targets Yubel grants her 1 stack of Terror Incarnate",
		["This effect is not cleansable or removable", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Yubel no longer starts at / is capped to 5 HP, and no longer ignores damage —
	# she takes damage normally now (the health-cap and ignore-damage effects were removed).
	# She still ignores non-damage Harmful effects while she has targetable allies.
	var non_damage = Effect.ignore_non_damage_effect(-1)
	non_damage.cleansable = false
	non_damage.set_source(self)
	Character.add_allied_effect(context, user, user, non_damage)

	# Yubel is no longer permanently Isolated (patch 2026-08-02). is_isolated() gates
	# Helpful targeting and both healing entry points, so dropping it is what makes her
	# a legal heal / shield / buff target for the first time.

	var receive_trigger = Effect.trigger_effect(Trigger.always(gain_terror_stack), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "Yubel receives a stack of Terror Incarnate whenever she receives a Harmful skill.")
	receive_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, receive_trigger)
	
	for ally in user.team.characters:
		var death_watcher = Effect.trigger_effect(
			Trigger.always(death_trigger),
			EffectType.Type.ON_DEATH_TRIGGER,
			-1,
			"")
		death_watcher.set_source(self)
		death_watcher.system = true
		Character.add_allied_effect(context, user, ally, death_watcher)
	death_trigger(context)

func death_trigger(context):
	if user.has_targetable_living_ally():
		return
	# Alone: she loses even her non-damage immunity (the damage-ignore is gone entirely now).
	var mark2 = user.has_effect("Sealed Nightmare", EffectType.Type.IGNORE_NON_DAMAGE)
	if mark2:
		user.effects.erase_effect(mark2)


func gain_terror_stack(context):
	var terror_ability = user.moveset.base_abilities[2]
	var existing = user.has_effect("Terror Incarnate", EffectType.Type.MARK, user)
	if existing:
		existing.stacks += 1
		existing.effect_updated.emit(existing)
	else:
		var stack_desc = func (eff):
			return "Yubel has " + str(eff.stack_count()) + " stack(s) of Terror Incarnate."
		var m = Effect.mark(-1, stack_desc)
		m.set_source(terror_ability)
		m.stackable = true
		m.display_stacks = true
		m.stacks = 1
		Character.add_allied_effect(context, user, user, m, true)

func extra_usable(user):
	return true

func target(user, battle):
	pass
