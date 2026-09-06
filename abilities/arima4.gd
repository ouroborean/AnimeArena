extends Ability

# Ixa Shield (Channeled). Base: a channel making Arima ignore ALL damage from the target enemy for 3
# turns (directional IGNORE_DAMAGE via effect.character_target + the is_ignoring_damage engine extension).
# If used the turn after Ixa Parry, instead gives Arima's whole team 75% damage reduction for 2 turns.

func describe(user):
	return "Arima ignores all damage from target enemy for 3 turns. If used the turn after Ixa Parry, instead gives Arima's team 75% damage reduction for 2 turns."

func split_desc():
	return [
		"Arima ignores all damage from target enemy for 3 turns (Channeled)",
		["If used the turn after Ixa Parry, instead gives Arima's team 75% Damage Reduction for 2 turns", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var parry = user.marked_by("Ixa Parry", user)
	if parry != null:
		user.effects.erase_effect(parry)
		for ally in user.team.characters:
			if ally.dead or ally.banished:
				continue
			var dr = Effect.percent_dr(75, 4)   # 2 turns; fresh effect per ally (effects are Nodes)
			dr.set_source(self)
			Character.add_allied_effect(context, user, ally, dr)
		return
	# Base: directional damage immunity vs the target enemy, channeled for 3 turns.
	var target = user.targeter.main_target
	var cancels = []
	var ignore = Effect.ignore_damage_effect(6)   # 3 turns
	ignore.character_target = target
	# Directional: only the ONE targeted enemy's damage is ignored — say so instead of the generic "all damage".
	ignore.description = func(eff): return "This character is ignoring all damage from " + eff.character_target.character_name + "."
	ignore.set_source(self)
	cancels.append(ignore)
	Character.add_allied_effect(context, user, user, ignore)
	# Mark the ignored enemy so the other side can see whose damage Arima is shrugging. Torn down with the
	# channel (in cancels); non-cleansable so it can't desync from the still-active immunity on Arima.
	var tag = Effect.mark(-1, "Arima is ignoring this character's damage.")
	tag.set_source(self)
	tag.cleansable = false
	cancels.append(tag)
	Character.add_hostile_effect(context, user, target, tag, true)
	# Ignore non-damage while channeling — visible so it doubles as the "shrugs non-damage while channeling" warning.
	var ig_nd = Effect.ignore_non_damage_effect(-1)
	ig_nd.description = func(eff): return "This character is ignoring negative non-damage effects while channeling."
	ig_nd.set_source(user.moveset.base_abilities[4])
	ig_nd.system = true
	ig_nd.display_system = true
	cancels.append(ig_nd)
	Character.add_allied_effect(context, user, user, ig_nd)
	var master = Effect.channel_cancel(6, ability_name, cancels)
	master.set_source(self)
	# A cleanse/buff-strip removes the master via end_effect (not check_cancels), which would strand the
	# enemy tag. Tear the riders down from the master's own wrapup so every removal path ends them.
	master.wrapup_func = func(_ctx): user._end_cancel_effects(master)
	Character.add_allied_effect(context, user, user, master)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 25)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
