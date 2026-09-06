extends Ability

func describe(user):
	return "Warp Digivolve to Beelzemon. Only usable at or below 60 HP. For 3 turns, Impmon receives double healing and all of his skills are replaced by Heartbreak Shot."

func split_desc():
	return [
		"Impmon Warp Digivolves to Beelzemon for 3 turns",
		["All of Impmon's skills are replaced by Heartbreak Shot while active", Color.AQUAMARINE],
		["Impmon receives double healing while active", Color.CADET_BLUE],
		["Only usable while Impmon is at or below 60 HP", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Replace all four visible skill slots (0-3) with Heartbreak Shot (impmon6 == moveset.abilities[5]).
	# SKILL_COPY is resolved in moveset_component.get_active_abilities(). Mirrors renamon3.gd.
	for i in range(4):
		var copy = Effect.copy_effect(user.moveset.abilities[5], i, 7, user)
		copy.system = true
		copy.set_source(self)
		Character.add_allied_effect(context, user, user, copy)
	# Beelzemon form marker. Its mag (200 = 200%) is read in Character.receive_healing to grant
	# double healing while active; it also serves as the visible transformation badge.
	var form = Effect.mark(7, "Impmon has Warp Digivolved to Beelzemon: it receives double healing and all of its skills are Heartbreak Shot.")
	form.mag = 200
	form.set_source(self)
	Character.add_allied_effect(context, user, user, form)
	# Swap to the Beelzemon portrait (alt portrait index 0 == impmonaltprof.png).
	var portrait = Effect.portrait_change_effect(0, 7)
	portrait.set_source(self)
	Character.add_allied_effect(context, user, user, portrait)

func extra_usable(user):
	return user.health.hp <= 60

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 250)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
