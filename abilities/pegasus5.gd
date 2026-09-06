extends Ability

var base_shield = 40
var stun_classes = ["Harmful"]

func describe(user):
	return "Target enemy's Harmful skills are stunned for 4 turns and Pegasus gains 40 Shield. If this skill's Shield is destroyed, this effect will end and this skill will be replaced by Relinquished. Cannot be used while active."

func split_desc():
	return [
		"Target enemy's Harmful skills are stunned for 4 turns",
		"Pegasus gains 40 Shield",
		"If the Shield is destroyed, this effect ends and this skill is replaced by Relinquished"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stun = Effect.stun_effect(8, stun_classes)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)

		var shield = Effect.shield_effect(base_shield, -1)
		shield.set_source(self)
		shield.character_target = target
		shield.wrapup_func = thousand_eyes_shield_broken
		Character.add_allied_effect(context, user, user, shield)

func thousand_eyes_shield_broken(context):
	var pegasus = context['effect'].user
	var locked_target = context['effect'].character_target
	pegasus.effects.full_remove_effect_by_name("Dark-Eyes Illusionist", pegasus)
	if locked_target:
		locked_target.effects.full_remove_effect_by_name("Thousand-Eyes Restrict", pegasus)

func extra_usable(user):
	if user.has_effect("Thousand-Eyes Restrict", EffectType.Type.SHIELD, user):
		return false
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 60)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
