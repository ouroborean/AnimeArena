extends Ability

# Placeholder passive. The base class's startup_passives() iterates every Passive
# and calls execute() on it, so execute() must remain a no-op here. The real
# effects are applied by allmight4 (Declare Successor) using this ability as the
# source so the description on Declare Successor stays clean.

func describe(user):
	return "The affected ally has their Random costs reduced by 1 and whenever they use a new skill, they receive 10 Affliction damage. If All Might is dead, their colored costs are permanently changed to Random costs."

func split_desc():
	return [
		"The affected ally's Random costs are reduced by 1.",
		"Whenever the affected ally uses a new skill, they take 10 Affliction damage.",
		["If All Might is dead, the affected ally's remaining colored costs become Random costs.", Color.DIM_GRAY],
	]

func execute(user, battle):
	pass

func extra_usable(user):
	return false

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	pass

# ── Helpers used by allmight4 ─────────────────────────────────────────────

func apply_one_for_all(context, granter, ally):
	var cost_mod = Effect.cost_mod_effect(-1, -1, Energy.Type.RANDOM)
	cost_mod.set_source(self)
	cost_mod.remove_on_death = false
	cost_mod.cleansable = false
	Character.add_allied_effect(context, granter, ally, cost_mod)

	var trigger = Effect.trigger_effect(
		Trigger.always(on_ally_uses_skill),
		EffectType.Type.ACTION_USE_TRIGGER,
		-1,
		"This character takes 10 Affliction damage whenever they use a new skill.")
	trigger.set_source(self)
	trigger.remove_on_death = false
	Character.add_allied_effect(context, granter, ally, trigger)

func on_ally_uses_skill(context):
	var ally = context['owner']
	Character.resolve_effect_damage(context, context['effect'], ally, 10, DamageType.Type.AFFLICTION)

func apply_post_death_color_changes(context, granter, ally):
	for colored in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		var change = Effect.color_change_effect(Energy.Type.RANDOM, colored, -1)
		change.set_source(self)
		change.remove_on_death = false
		change.system = true
		Character.add_allied_effect(context, granter, ally, change)
		
