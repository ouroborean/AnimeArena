extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

const STACK_NAME = "Eye Strain"
const THRESHOLD = 5

func describe(user):
	return "Whenever an enemy uses a Harmful skill, Adam gains 1 stack of Eye Strain. At 5 stacks, Adam becomes Blinded for 1 turn, loses all stacks, and permanently deals 5 more damage. Adam cannot gain Eye Strain while Blinded."

func split_desc():
	return [
		["When an enemy uses a Harmful skill, Adam gains 1 stack of Eye Strain", Color.ORANGE_RED],
		["At 5 stacks Adam is Blinded for 1 turn, loses all stacks, and permanently deals 5 more damage", Color.CADET_BLUE],
		"Adam cannot gain Eye Strain while Blinded"
	]

func execute(user, battle):
	# Runs once via startup_passives at battle start. Plant a permanent, invisible
	# HARMFUL_USE_TRIGGER on every enemy so each Harmful skill they use feeds Adam a stack.
	var context = QueryContext.from_game_state(user, battle)
	for enemy in context.enemy_team.characters:
		var trigger = Effect.trigger_effect(Trigger.always(enemy_harmful_use), EffectType.Type.HARMFUL_USE_TRIGGER, -1, "When this character uses a Harmful skill, Adam gains 1 stack of Eye Strain.")
		trigger.set_source(self)
		trigger.invisible = true
		trigger.system = true
		Character.add_hostile_effect(context, user, enemy, trigger)

func enemy_harmful_use(context):
	# context comes from QueryContext.from_effect_end(eff): owner == eff.user == Adam.
	var adam = context['effect'].user
	if adam == null or adam.dead or adam.banished:
		return
	grant_eye_strain(adam)

# Shared entry point. adam1/adam2/adam4 all call user.moveset.base_abilities[4].grant_eye_strain(user)
# so every source merges into one "Eye Strain" mark sourced from this passive (effect_name == source
# ability name), keeping a single 0-5 counter.
func grant_eye_strain(adam):
	if adam == null or adam.dead or adam.banished:
		return
	if is_blinded(adam):
		return
	var context = QueryContext.from_game_state(adam, adam.battle)
	var mark = Effect.mark(-1, "Eye Strain: at 5 stacks Adam is Blinded for 1 turn and permanently deals 5 more damage.")
	mark.stackable = true
	mark.display_stacks = true
	mark.set_source(self)
	Character.add_allied_effect(context, adam, adam, mark)
	var current = adam.effects.has_effect(STACK_NAME, EffectType.Type.MARK, adam)
	if current != null and current.stacks >= THRESHOLD:
		fire_threshold(adam, context)

func fire_threshold(adam, context):
	adam.effects.remove_effect(STACK_NAME, EffectType.Type.MARK, adam)
	var blind = Effect.blind_effect(2)
	blind.set_source(self)
	blind.unique_render_id = 5
	Character.add_allied_effect(context, adam, adam, blind)
	# Permanent +5 damage. Sourced from this passive too, so repeated thresholds stack the magnitude.
	var boost = Effect.damage_mod_effect(5, -1)
	boost.stackable = true
	boost.stack_mag = true
	boost.display_stacks = true
	boost.set_source(self)
	Character.add_allied_effect(context, adam, adam, boost)

func is_blinded(combatant):
	return len(combatant.effects.get_effects_by_type(EffectType.Type.BLIND)) > 0 and not combatant.shrug_off_type(EffectType.Type.BLIND)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
