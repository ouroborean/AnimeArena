extends Ability

var heal_amount = 5
var damage_per_stack = 5
var aoe_threshold = 3

func describe(user):
	return "At the end of each turn in which Veldora does not use a new skill, he heals 5 HP and gains a stack of Slumbering Dragon, granting +5 damage on his Harmful skills (stacks). Once Veldora acts, all stacks of Slumbering Dragon are lost."

func split_desc():
	return [
		"At the end of each turn Veldora doesn't use a new skill:",
		["Veldora heals 5 HP.", Color.CADET_BLUE],
		["Veldora gains a stack of Slumbering Dragon (+5 damage on Harmful skills, stacks).", Color.CADET_BLUE],
		["Once Veldora acts, all stacks of Slumbering Dragon are lost.", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var idle_trig = Effect.trigger_effect(
		Trigger.always(slumber_trigger),
		EffectType.Type.END_OF_TURN_TRIGGER,
		-1,
		"Veldora is slumbering: if he doesn't act this turn, he heals 5 HP and gains a stack of Slumbering Dragon.")
	idle_trig.set_source(self)
	Character.add_allied_effect(context, user, user, idle_trig)

	var act_trig = Effect.trigger_effect(
		Trigger.always(reset_on_action),
		EffectType.Type.ACTION_USE_TRIGGER,
		-1,
		"Veldora's Slumbering Dragon stacks are lost when he acts.")
	act_trig.set_source(self)
	Character.add_allied_effect(context, user, user, act_trig)

func slumber_trigger(context):
	var veldora = context['effect'].user
	if veldora.dead or veldora.banished:
		return
	if veldora.acted:
		return

	Character.resolve_effect_healing(context, context['effect'], veldora, heal_amount)

	var stack = Effect.damage_mod_effect(damage_per_stack, -1)
	stack.set_source(self)
	stack.stackable = true
	stack.display_stacks = true
	stack.stack_mag = true
	Character.add_allied_effect(context, veldora, veldora, stack)

	var sd = veldora.has_effect("Slumbering Dragon", EffectType.Type.DAMAGE_MOD, veldora)
	if sd and sd.stacks >= aoe_threshold:
		if not veldora.has_effect("Slumbering Dragon", EffectType.Type.TARGET_CHANGE, veldora):
			var tc = Effect.target_change_effect(TargetType.Type.ALL, -1, ["Tempest Fist"])
			tc.set_source(self)
			Character.add_allied_effect(context, veldora, veldora, tc)

func reset_on_action(context):
	var veldora = context['effect'].user
	if veldora.dead or veldora.banished:
		return
	for eff in veldora.effects.get_all_effects_by_name("Slumbering Dragon", veldora):
		if eff.effect_type == EffectType.Type.DAMAGE_MOD or eff.effect_type == EffectType.Type.TARGET_CHANGE:
			veldora.effects.erase_effect(eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	return [[0, [user, "PASS", []]]]

func target(user, battle):
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
