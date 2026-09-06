extends Ability

func describe(user):
	return "Target ally wields the active Thompson Sister. This effect lasts until Transform: Demon Twin Guns is used on a new target, at which point it ends on the previous target. The Thompson Sisters gain 10 Damage Reduction, and if the targeted ally uses a new Harmful skill, the Thompson Sisters will deal 10 damage to their primary target. Allies wielding Liz have their Green costs changed to Random. Allies wielding Patty have their Blue costs changed to Random."

func split_desc():
	return [
		"Target ally wields Liz for 4 turns, and The Thompson Sisters gain 10 Damage Reduction",
		["If the targeted ally uses a new Harmful skill, the Thompson Sisters will deal 10 damage to their primary target.", Color.CADET_BLUE],
		["Allies wielding Liz have their Green costs changed to Random.", Color.DIM_GRAY],
		["Cannot target a character already wielding Patty, unless that character is Death the Kid", Color.ORANGE_RED],
		["While active, this skill is replaced by Wave Compression: Liz", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var kid_target = false
	for target in user.targeter.targets:
		var color_change = Effect.color_change_effect(4, 0, 9)
		color_change.set_source(self)
		Character.add_allied_effect(context, user, target, color_change)
		var trigger = Effect.trigger_effect(Trigger.always(harmful_use_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, 9, "If this character uses a Harmful skill, Liz will deal 10 damage to their primary target")
		trigger.set_source(self)
		Character.add_allied_effect(context, user, target, trigger)
		if target.path_name == "kid" and user.moveset.base_abilities[1].cooldown_remaining == 0:
			var color_change2 = Effect.color_change_effect(4, 1, 9)
			color_change2.set_source(user.moveset.base_abilities[1])
			Character.add_allied_effect(context, user, target, color_change2)
			var trigger2 = Effect.trigger_effect(Trigger.always(harmful_use_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, 9, "If this character uses a Harmful skill, Patty will deal 10 damage to their primary target")
			trigger2.set_source(user.moveset.base_abilities[1])
			Character.add_allied_effect(context, user, target, trigger2)
			kid_target = true
	var dr = Effect.damage_reduction_effect(10, 8)
	dr.set_source(self)
	Character.add_allied_effect(context, user, user, dr)
	var swap = Effect.ability_swap_effect(5, 0, user, 9)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	if kid_target:
		user.moveset.base_abilities[1].cooldown_remaining = 2
		var dr2 = Effect.damage_reduction_effect(10, 8)
		dr2.set_source(user.moveset.base_abilities[1])
		Character.add_allied_effect(context, user, user, dr2)
		var swap2 = Effect.ability_swap_effect(4, 1, user, 9)
		swap2.set_source(user.moveset.base_abilities[1])
		Character.add_allied_effect(context, user, user, swap2)


func harmful_use_trigger(context):
	var thompson = context['owner']
	var wielder = context['target']
	if wielder == null:
		return
	var primary = wielder.targeter.main_target
	if primary == null:
		return
	Character.resolve_effect_damage(context, context.effect, primary, 10, DamageType.Type.NORMAL)


# One character cannot wield both sisters. Death the Kid is the exemption - he dual-wields,
# which is precisely what the double-apply branch in execute() above implements, so he is
# allowed to receive Liz on top of Patty.
# The wield handle is the HARMFUL_USE_TRIGGER the transform plants, the same one
# lizandpatty3:38-39 and lizandpatty6 read. There is no wielder MARK to key on.
func _wield_conflict(user, character) -> bool:
	if character.path_name == "kid":
		return false
	return character.has_effect("Transform: Patty", EffectType.Type.HARMFUL_USE_TRIGGER, user) != null


func extra_usable(user):
	# Mirrors target(). Without it the button stays lit on a turn where every ally is
	# already holding Patty, and the skill only fails once it has been paid for.
	var context = QueryContext.from_game_state(user, user.battle)
	for character in user.team.characters:
		if _wield_conflict(user, character):
			continue
		if Condition.can_allied_target(user, character).satisfied(context):
			return true
	return false

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_helpful(context)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if _wield_conflict(user, character):
			continue
		check_allied_target(user, character, context)
