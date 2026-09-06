extends Ability

func describe(user):
	return "For 5 turns, Halo Blade deals double damage and Yoh heals 5 HP each turn, increased to 10 HP if Yoh was not targeted with a Harmful skill last turn."

func split_desc():
	return [
		"For 5 turns, Halo Blade deals double damage",
		"Yoh heals 5 HP each turn, starting the turn after this skill is used",
		"Healing is increased to 10 HP if Yoh was not targeted by a Harmful skill last turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	var mark = Effect.mark(10, "Halo Blade deals double damage.")
	mark.set_source(self)
	mark.wrapup_func = on_buff_end
	Character.add_allied_effect(context, user, user, mark)

	var heal_trig = Effect.trigger_effect(
		Trigger.always(tick_heal),
		EffectType.Type.TICKING_TRIGGER,
		10,
		"Yoh heals 5 HP (10 HP if not targeted by a Harmful skill last turn).")
	heal_trig.set_source(self)
	Character.add_allied_effect(context, user, user, heal_trig)

	var hit_watch = Effect.trigger_effect(
		Trigger.always(note_hit),
		EffectType.Type.HARMFUL_RECEIVE_TRIGGER,
		10,
		"Tracks when Yoh is hit with a Harmful skill.")
	hit_watch.set_source(self)
	hit_watch.system = true
	hit_watch.mag = 0
	Character.add_allied_effect(context, user, user, hit_watch)
	
	refresh_swaps(context, user)

func tick_heal(context):
	var yoh = context['owner']
	var hit = yoh.has_effect("Amidamaru Over Soul", EffectType.Type.HARMFUL_RECEIVE_TRIGGER, yoh)
	var amount = 10
	if hit and hit.mag > 0:
		amount = 5
		hit.mag = 0
	Character.resolve_effect_healing(context, hit, yoh, amount)

func note_hit(context):
	context.effect.mag = 1

func on_buff_end(context):
	var yoh = context.effect.user
	refresh_swaps(context, yoh, "Amidamaru Over Soul")

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
	return user.has_effect("Amidamaru Over Soul", EffectType.Type.MARK, user) == null

func custom_behavior(context):
	return behavior_self_panic_button(context, 25)

func target(user, battle):
	default_self_target_function(user, battle)
