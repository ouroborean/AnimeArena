extends Ability

func describe(user):
	return "Denji ignores damage for 1 turn (Invisible). Any enemy that uses a skill on Denji during this time takes 10 Bleed damage on the following turn."

func split_desc():
	return [
		"Denji ignores all damage for 1 turn (Invisible)",
		["Enemies who use a skill on Denji take 10 Bleed damage next turn", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ignore = Effect.ignore_damage_effect(2)   # dur 2 = 1 turn
	ignore.set_source(self)
	ignore.invisible = true
	Character.add_allied_effect(context, user, user, ignore)
	# Reactive (NOT a counter — it must not abort the enemy's skill): any enemy Harmful skill on Denji
	# during the window bleeds that attacker next turn.
	var trig = Effect.trigger_effect(Trigger.always(block_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "Enemies who use a skill on Denji take 10 Bleed damage next turn.")
	trig.set_source(self)
	trig.invisible = true
	Character.add_allied_effect(context, user, user, trig)

func block_trigger(context):
	var attacker = context['owner']
	# dur 2 (not 3): this fires reactively DURING the enemy's turn, so — unlike a bleed applied on
	# Denji's own turn — it needs one less duration to land its single tick on Denji's next turn.
	var bleed = Effect.damage_effect(10, DamageType.Type.BLEED, 2)
	bleed.set_source(self)
	bleed.last_turn_only = true
	Character.add_hostile_effect(context, context['effect'].user, attacker, bleed)

func extra_usable(user):
	return user.has_effect("Devil Transformation", EffectType.Type.MARK, user) != null

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 10)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
