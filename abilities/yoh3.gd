extends Ability

func describe(user):
	return "For 3 turns, damage to Yoh is capped to 20 and Halo Blade now deals 20 damage, stealing up to 20 HP. If Amidamaru Over Soul is also active, The Absence of Ignorance replaces Halo Blade. Spirit of Sword cannot be used while active."

func split_desc():
	return [
		"For 3 turns, damage dealt to Yoh is capped at 20",
		"Halo Blade deals 20 damage and steals up to 20 HP",
		["If Amidamaru Over Soul is also active, The Absence of Ignorance replaces Halo Blade", Color.CADET_BLUE],
		["Spirit of Sword cannot be used while active", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var cap = Effect.damage_cap_receive(20, 6)
	cap.set_source(self)
	Character.add_allied_effect(context, user, user, cap)

	var mark = Effect.mark(6, "Halo Blade deals 20 damage and steals up to 20 HP.")
	mark.set_source(self)
	mark.wrapup_func = on_buff_end
	Character.add_allied_effect(context, user, user, mark)

	refresh_swaps(context, user)

func on_buff_end(context):
	var yoh = context.effect.user
	refresh_swaps(context, yoh, "White Swan Over Soul")

func refresh_swaps(context, yoh, ignore_name = ""):
	var yoh_buffs = ["Amidamaru Over Soul", "Spirit of Sword", "White Swan Over Soul"]
	var swaps_to_clear = []
	for eff in yoh.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		if eff.source and eff.source.ability_name in yoh_buffs:
			swaps_to_clear.append(eff)
	for eff in swaps_to_clear:
		yoh.effects.erase_effect(eff)

	var has_ami = yoh.has_effect("Amidamaru Over Soul", EffectType.Type.MARK, yoh) != null and ignore_name != "Amidamaru Over Soul"
	var has_spirit = yoh.has_effect("Spirit of Sword", EffectType.Type.MARK, yoh) != null and ignore_name != "Spirit of Sword"
	var has_swan = yoh.has_effect("White Swan Over Soul", EffectType.Type.MARK, yoh) != null and ignore_name != "White Swan Over Soul"

	if has_ami and has_spirit:
		var swap = Effect.ability_swap_effect(4, 3, yoh, 20)
		swap.set_source(self)
		Character.add_allied_effect(context, yoh, yoh, swap)
	elif has_ami and has_swan:
		var swap = Effect.ability_swap_effect(5, 3, yoh, 20)
		swap.set_source(self)
		Character.add_allied_effect(context, yoh, yoh, swap)

func extra_usable(user):
	if user.has_effect("Spirit of Sword", EffectType.Type.MARK, user):
		return false
	return user.has_effect("White Swan Over Soul", EffectType.Type.MARK, user) == null

func custom_behavior(context):
	return behavior_self_panic_button(context, 30, 1.2)

func target(user, battle):
	default_self_target_function(user, battle)
