extends Ability

var damage_per_stack = 5
var ascension_threshold = 4
# Cap and ascension deliberately coincide (owner ruling): the 4th stack is the
# one that both maxes the damage bonus and triggers the Planet Geyser swap.
var stack_cap = 4

func describe(user):
	return "Each time Broly receives a new Harmful skill, he permanently deals 5 more damage. Once he has 4 or more, Explosive Wave is permanently replaced with Planet Geyser Wave."

func split_desc():
	return [
		"Each time Broly receives a new Harmful skill, he permanently deals 5 more damage",
		["This stacks up to 4 times", Color.DIM_GRAY],
		["Once he has 4 stacks, Explosive Wave becomes Planet Geyser Wave", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var watcher = Effect.trigger_effect(
		Trigger.always(legendary_trigger),
		EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
		-1,
		""
	)
	watcher.set_source(self)
	watcher.system = true
	Character.add_allied_effect(context, user, user, watcher)

func legendary_trigger(context):
	var broly = context['effect'].user
	if broly == null or broly.dead or broly.banished:
		return
	var qc = QueryContext.from_game_state(broly, broly.battle)

	# There is no engine-side stack ceiling — effect_storage merges stacks
	# unconditionally — so the cap has to be a guard BEFORE the add. Checked
	# after the call would be too late: the merge has already happened.
	var lss = broly.effects.has_effect("Legendary Super Saiyan", EffectType.Type.DAMAGE_MOD, broly)
	if lss == null or lss.stack_count() < stack_cap:
		var rage = Effect.damage_mod_effect(damage_per_stack, -1)
		rage.set_source(self)
		rage.stackable = true
		rage.per_stack = true
		rage.display_stacks = true
		Character.add_allied_effect(qc, broly, broly, rage)
		lss = broly.effects.has_effect("Legendary Super Saiyan", EffectType.Type.DAMAGE_MOD, broly)

	if lss and lss.stack_count() >= ascension_threshold:
		if not broly.effects.has_effect("Legendary Super Saiyan", EffectType.Type.ABILITY_SWAP, broly):
			swap_ability(qc, 5, 2, -1)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
