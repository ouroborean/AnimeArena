extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Once Mayuri uses 5 skills, he releases his Bankai for 4 turns. During this time, all enemies receive 5 more damage from Affliction skills and effects, and an enemy that targets him with a non-Mental skill will take 5 Affliction damage for 2 turns. During this time, Ashisogi Jizo is replaced by Deadly Gas."

func split_desc():
	return [
		"After Mayuri uses 5 skills, releases Bankai for 4 turns:",
		"   - All enemies take +5 Affliction damage",
		"   - Non-Mental attackers on Mayuri suffer 5 Affliction damage for 2 turns",
		"   - Ashisogi Jizo is replaced by Deadly Gas",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# === Bankai charge counter ===
	# Each skill use ticks this counter via ACTION_USE_TRIGGER. The trigger is
	# invisible and lives on Mayuri for the whole match.
	var use_trigger_desc = func (eff):
		return "Each skill Mayuri uses charges toward Bankai (5 needed)."
	var use_trigger = Effect.trigger_effect(
		Trigger.always(record_skill_use),
		EffectType.Type.ACTION_USE_TRIGGER,
		-1,
		use_trigger_desc
	)
	use_trigger.set_source(self)
	Character.add_allied_effect(context, user, user, use_trigger)

	# === Drug cycler ===
	# Sourced from kurotsuchi3 (canonical Drug slot) so the tooltip reads under
	# "Flesh-Healing Drug" instead of "Bankai - Konjiki Ashisogi Jizo" — the
	# cycling is conceptually a Drug-system mechanic, even though the passive
	# is what initializes it.
	var drug_anchor = user.moveset.base_abilities[2]
	var cycle_desc = func (eff):
		return "Mayuri's Drug slot swaps to a random other Drug skill at the end of each turn."
	var cycle_trigger = Effect.trigger_effect(
		Trigger.always(cycle_drugs),
		EffectType.Type.TICKING_TRIGGER,
		-1,
		cycle_desc
	)
	cycle_trigger.set_source(drug_anchor)
	# Effects cluster by (effect_name, unique_render_id, user), and effect_name is
	# the SOURCE's ability_name — so this cycler reads as "Flesh-Healing Drug" and
	# collapsed into the same tooltip as the DR + heal-over-time Mayuri gets when
	# he casts Flesh-Healing Drug ON HIMSELF. A distinct id keeps the permanent
	# rotation marker in its own panel; the per-cast drug effects keep the default
	# 0 so they still group together as one tooltip.
	cycle_trigger.unique_render_id = 31
	Character.add_allied_effect(context, user, user, cycle_trigger)

func record_skill_use(context):
	# ACTION_USE_TRIGGER fires when the trigger holder uses an action. For an
	# allied trigger on Mayuri, context.owner is Mayuri himself.
	var mayuri = context['owner']
	if mayuri != user:
		return

	# The counter is a MARK with this same source — but a different effect_type
	# than the Bankai-active EMPTY effect, so has_effect lookups can distinguish
	# them despite sharing source.ability_name.
	var counter = mayuri.has_effect("Bankai - Konjiki Ashisogi Jizo", EffectType.Type.MARK, mayuri)
	if counter == null:
		var fresh = Effect.mark(-1, "Mayuri has used a skill.")
		fresh.set_source(self)
		fresh.stackable = true
		fresh.display_stacks = true
		fresh.stacks = 1
		Character.add_allied_effect(QueryContext.from_game_state(mayuri, mayuri.battle), mayuri, mayuri, fresh, true)
		counter = fresh
	else:
		counter.stacks += 1
		counter.effect_updated.emit(counter)

	if counter.stack_count() >= 5:
		release_bankai(mayuri)

func release_bankai(mayuri):
	var context = QueryContext.from_game_state(mayuri, mayuri.battle)

	# Consume the counter so the next 5 uses can trigger another Bankai cycle.
	var counter = mayuri.has_effect("Bankai - Konjiki Ashisogi Jizo", EffectType.Type.MARK, mayuri)
	if counter != null:
		mayuri.effects.erase_effect(counter)

	# Visible display marker — EMPTY not MARK so it doesn't collide with the
	# (now-deleted) counter on the has_effect lookup.
	var bankai_desc = func (eff):
		return "Mayuri has released his Bankai."
	var bankai_state = Effect.empty(8, bankai_desc)
	bankai_state.set_source(self)
	Character.add_allied_effect(context, mayuri, mayuri, bankai_state)

	# +5 vulnerability to Affliction damage on each living enemy for 4 turns.
	for enemy in mayuri.battle.all_characters():
		if mayuri.is_hostile(enemy) and not (enemy.dead or enemy.banished):
			var vuln = Effect.vulnerability_effect(5, 8, [], [DamageType.Type.AFFLICTION])
			vuln.set_source(self)
			Character.add_hostile_effect(context, mayuri, enemy, vuln, true)

	# Non-Mental attacker riposte. Class filtering happens inside the callback
	# since HARMFUL_RECEIVE_TRIGGER's dispatcher doesn't consult class_targets.
	var riposte_desc = func (eff):
		return "Any non-Mental Harmful skill targeting Mayuri makes the attacker take 5 Affliction damage for 2 turns."
	var riposte = Effect.trigger_effect(
		Trigger.always(bankai_riposte),
		EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
		8,
		riposte_desc
	)
	riposte.set_source(self)
	Character.add_allied_effect(context, mayuri, mayuri, riposte)

	# Slot 0 (Ashisogi Jizo) → slot 5 (Deadly Gas) for 4 turns.
	var swap = Effect.ability_swap_effect(5, 0, mayuri, 8)
	swap.set_source(self)
	Character.add_allied_effect(context, mayuri, mayuri, swap)

func bankai_riposte(context):
	# Filter Mental skills out — Mental targeters don't trip the gas riposte.
	var received_ability = context['source']
	if received_ability != null and received_ability.classes.get("Mental", false):
		return

	var mayuri = context['target']
	var attacker = context['owner']
	if attacker == null or attacker == mayuri:
		return

	var dot = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 5)
	dot.set_source(self)
	Character.add_hostile_effect(context, mayuri, attacker, dot, true)

func cycle_drugs(context):
	var mayuri = user
	var drug_anchor = mayuri.moveset.base_abilities[2]

	# Read slot 2's current ability BEFORE we tear down the previous swap —
	# otherwise it would always read as Flesh-Healing Drug (the base ability).
	var active_abilities = mayuri.moveset.get_active_abilities(mayuri)
	if active_abilities.size() <= 2:
		return
	var current = active_abilities[2].ability_name

	# Remove the previous cycle's slot-2 swap (if any). The cycler trigger
	# itself shares effect_name with the swap, but has a different type
	# (TICKING_TRIGGER vs ABILITY_SWAP) so has_effect picks out only the swap.
	var prior_swap = mayuri.has_effect("Flesh-Healing Drug", EffectType.Type.ABILITY_SWAP, mayuri)
	if prior_swap != null:
		mayuri.effects.erase_effect(prior_swap)

	var drugs = ["Flesh-Healing Drug", "Superhuman Drug", "Postcognition Drug"]
	drugs.erase(current)
	if drugs.is_empty():
		return
	var chosen = drugs[mayuri.battle.roll(0, drugs.size() - 1)]

	var swap_in = -1
	match chosen:
		"Flesh-Healing Drug":
			swap_in = 2
		"Superhuman Drug":
			swap_in = 6
		"Postcognition Drug":
			swap_in = 7

	# When the cycle lands on Flesh-Healing Drug we don't install a swap —
	# that's the base ability at slot 2 already. Otherwise install a new
	# permanent swap and let the next cycle tick replace it.
	if swap_in != 2 and swap_in != -1:
		var swap = Effect.ability_swap_effect(swap_in, 2, mayuri, -1)
		swap.set_source(drug_anchor)
		Character.add_allied_effect(QueryContext.from_game_state(mayuri, mayuri.battle), mayuri, mayuri, swap)

func extra_usable(user):
	return true

func target(user, battle):
	pass
