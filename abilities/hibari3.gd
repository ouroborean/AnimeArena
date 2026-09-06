extends Ability

var tick_damage = 5
var punish_damage = 10

func describe(user):
	return "For 3 turns, all enemies take 5 Piercing damage. During this time, any enemy that uses a Harmful skill takes 10 Piercing damage, and Cloud Tonfa has no cooldown."

func split_desc():
	return [
		"All enemies take 5 Piercing damage for 3 turns",
		["Enemies that use a Harmful skill during this time take 10 Piercing damage", Color.CADET_BLUE],
		["Cloud Tonfa has no cooldown during this time", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if user.is_hostile(character) and not (character.dead or character.banished):
			var quill_dot = Effect.damage_effect(tick_damage, DamageType.Type.PIERCING, 5)
			quill_dot.set_source(self)
			Character.add_hostile_effect(context, user, character, quill_dot)
			Character.resolve_effect_damage(context, quill_dot, character, tick_damage, DamageType.Type.PIERCING)

			var punish = Effect.trigger_effect(
				Trigger.always(needle_trigger),
				EffectType.Type.HARMFUL_USE_TRIGGER,
				6,
				"If this character uses a Harmful skill, they will take 10 Piercing damage."
			)
			punish.set_source(self)
			Character.add_hostile_effect(context, user, character, punish)

	var tonfa_free = Effect.cooldown_mod(-1, 5, ["Cloud Tonfa"])
	tonfa_free.set_source(self)
	Character.add_allied_effect(context, user, user, tonfa_free)

func needle_trigger(context):
	var struck = context['target']
	if struck == null or struck.dead or struck.banished:
		return
	Character.resolve_effect_damage(context, context['effect'], struck, punish_damage, DamageType.Type.PIERCING)

func bot_damage_hint() -> float:
	return 15.0

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 45)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
