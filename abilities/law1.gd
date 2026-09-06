extends Ability

# ROOM. Law's opener: it unlocks the rest of his kit, permanently swaps its own slot to Shambles,
# and installs the per-turn "operating theatre" — at the start of each of Law's turns a random ally
# AND a random enemy are tagged with ROOM, the marks Amputate / Surgeon of Death / Shambles read.

func describe(user):
	return "For the rest of the game, Law can use his other skills and this skill is replaced by Shambles. At the start of each of his turns, a random ally and a random enemy will be marked with ROOM for 1 turn."

func split_desc():
	return [
		"Unlocks Law's other skills for the rest of the game",
		["This skill is replaced by Shambles", Color.AQUAMARINE],
		"At the start of each of his turns, a random ally AND a random enemy are marked with ROOM for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Slot 0 permanently becomes Shambles (base_abilities[4]).
	var swap = Effect.ability_swap_effect(4, 0, user, -1)
	swap.set_source(self)
	swap.remove_on_death = false   # "for the rest of the game" — survives Law dying + being revived
	Character.add_allied_effect(context, user, user, swap)
	# The per-turn marking machine. It doubles as the "ROOM is active" token the other skills gate on
	# (has_effect ROOM/START_OF_TURN_TRIGGER). START_OF_TURN fires for BOTH sides each turn, so the
	# callback gates to Law's team (mavis5 pattern). System-hidden — the visible state is the marks.
	var room = Effect.trigger_effect(
		Trigger.always(room_tick),
		EffectType.Type.START_OF_TURN_TRIGGER, -1,
		"At the start of each of Law's turns, a random ally and a random enemy are marked with ROOM.")
	room.system = true
	room.remove_on_death = false   # permanent machinery must survive the death cleanse (see stark5)
	room.set_source(self)
	Character.add_allied_effect(context, user, user, room)

func room_tick(context):
	var law = context['effect'].user
	if law.dead or law.banished:
		return
	var mbattle = law.battle
	# waiting_for_turn is the player/enemy SIDE split, not "Law's team" — derive the acting team and
	# require Law to be on it, so this fires on Law's turns whether he is player 1 or player 2.
	var acting_team = mbattle.enemy.team if mbattle.waiting_for_turn else mbattle.player.team
	if not law in acting_team.characters:
		return
	var qc = QueryContext.from_game_state(law, mbattle)
	var allies = []
	var enemies = []
	for c in mbattle.all_characters():
		if c.dead or c.banished:
			continue
		if c in law.team.characters:
			allies.append(c)
		else:
			enemies.append(c)
	if not allies.is_empty():
		var a = allies[mbattle.roll(0, allies.size() - 1)]
		var mark = Effect.mark(2, "Marked with ROOM.")
		mark.set_source(self)
		mark.refresh = true
		mark.unique_render_id = 1   # distinct render, so it's obvious when Law himself is the marked ally
		Character.add_allied_effect(qc, law, a, mark, true)
	if not enemies.is_empty():
		var e = enemies[mbattle.roll(0, enemies.size() - 1)]
		var mark = Effect.mark(2, "Marked with ROOM.")
		mark.set_source(self)
		mark.refresh = true
		mark.unique_render_id = 1
		# bypassing: the ROOM mark lands through Invulnerability (add_hostile_effect would otherwise drop it).
		Character.add_hostile_effect(qc, law, e, mark, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 130)

func target(user, battle):
	default_self_target_function(user, battle)
