extends Ability

# SSS Ukaku Quinque — Arima's passive (base_abilities[4]). Installs three permanent, system, death-durable
# pieces at battle start:
#   (a) a skills-used counter MARK (feeds Owl Slash's +5/skill scaling AND the every-3rd-skill swap),
#   (b) an ACTION_USE_TRIGGER that increments the counter, swaps Owl Slash over Narukami Sword for one
#       turn on every 3rd skill, and re-checks the Owl Finisher availability after each of Arima's actions,
#   (c) a START_OF_TURN_TRIGGER that keeps Owl Finisher swapped over Ixa Parry exactly while any character
#       on the field is at <=15 HP (a two-way toggle).
# "Ignores negative non-damage effects while channeling" is realised in the channel abilities (Narukami
# Blast / Ixa Shield each enroll an IGNORE_NON_DAMAGE in their cancel list, so it exists iff a channel is up).

const COUNTER := "SSS Ukaku Quinque"

func describe(user):
	return "Arima ignores all negative non-damage effects while he is channeling skills. Every 3rd skill he uses causes Owl Slash to replace Narukami Sword for 1 turn. Owl Finisher replaces Ixa Parry while any character on the field is at 15 or less HP."

func split_desc():
	return [
		["Ignores all negative non-damage effects while channeling a skill", Color.CADET_BLUE],
		["Every 3rd skill Arima uses swaps Owl Slash over Narukami Sword for 1 turn", Color.AQUAMARINE],
		["Owl Finisher replaces Ixa Parry while any character on the field is at 15 or less HP", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.has_effect(COUNTER, EffectType.Type.MARK, user) == null:
		var c = Effect.mark(-1, func(eff): return "Arima has used " + str(eff.stack_count()) + " skill(s) this game.")
		c.stackable = true
		c.display_stacks = true
		c.stacks = 0
		c.system = true
		c.display_system = true
		c.remove_on_death = false
		c.cleansable = false
		c.set_source(self)
		Character.add_allied_effect(context, user, user, c)
	if user.has_effect(COUNTER, EffectType.Type.ACTION_USE_TRIGGER, user) == null:
		var t = Effect.trigger_effect(Trigger.always(count_skill), EffectType.Type.ACTION_USE_TRIGGER, -1, "Counts Arima's skills; every 3rd swaps in Owl Slash.")
		t.set_source(self)
		t.waiting = false
		t.system = true
		t.remove_on_death = false
		t.cleansable = false
		Character.add_allied_effect(context, user, user, t)
	if user.has_effect(COUNTER, EffectType.Type.START_OF_TURN_TRIGGER, user) == null:
		var s = Effect.trigger_effect(Trigger.always(maintain_finisher), EffectType.Type.START_OF_TURN_TRIGGER, -1, "Keeps Owl Finisher available while a character is at 15 or less HP.")
		s.set_source(self)
		s.system = true
		s.invisible = true
		s.remove_on_death = false
		s.cleansable = false
		Character.add_allied_effect(context, user, user, s)
	_do_finisher_swap(user)   # immediate first evaluation

func count_skill(context):
	var arima = context['effect'].user
	if arima == null or arima.dead or arima.banished:
		return
	var counter = arima.has_effect(COUNTER, EffectType.Type.MARK, arima)
	if counter != null:
		counter.stacks += 1
		if counter.stacks % 3 == 0:
			# Owl Slash (base_abilities[5]) over Narukami Sword (display slot 0) for 1 turn (swap dur = 2N+1).
			var swap = Effect.ability_swap_effect(5, 0, arima, 3)
			swap.set_source(arima.moveset.base_abilities[5])
			swap.invisible = true
			var ctx = QueryContext.from_game_state(arima, arima.battle)
			Character.add_allied_effect(ctx, arima, arima, swap)
	_do_finisher_swap(arima)   # Arima may have just brought a character to <=15 HP

func maintain_finisher(context):
	var arima = context['effect'].user
	if arima != null:
		_do_finisher_swap(arima)

# Two-way toggle: Owl Finisher (base_abilities[6]) occupies Ixa Parry's display slot (2) iff any living
# character on the field is at <=15 HP. Re-evaluated on every turn start and after each Arima action.
func _do_finisher_swap(arima):
	if arima == null or arima.battle == null:
		return
	# Exclude Arima himself: Owl Finisher can only execute an ENEMY or an OTHER ally, so a solo-low Arima
	# must not swap his Ixa Parry (his panic button) out for an uncastable Owl Finisher.
	var any_low = false
	for c in arima.battle.all_characters():
		if c != arima and is_instance_valid(c) and not c.dead and not c.banished and c.health.hp <= 15:
			any_low = true
			break
	var present = null
	for e in arima.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		if e.effect_name() == "Owl Finisher":
			present = e
			break
	if any_low and present == null:
		var swap = Effect.ability_swap_effect(6, 2, arima, -1)
		swap.set_source(arima.moveset.base_abilities[6])
		swap.invisible = true
		swap.system = true
		swap.remove_on_death = false
		swap.cleansable = false
		var ctx = QueryContext.from_game_state(arima, arima.battle)
		Character.add_allied_effect(ctx, arima, arima, swap)
	elif not any_low and present != null:
		arima.effects.erase_effect(present)

func extra_usable(user):
	return true

func target(user, battle):
	default_self_target_function(user, battle)
