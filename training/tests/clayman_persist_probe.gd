extends Node

# CLAYMAN SURVIVES HIS OWN SHIELD BREAKING.
#
# Owner ruling (2026-08-02, revising the earlier Q27 answer): Clayman must NOT be removed when his
# Shield is destroyed. He keeps the TICKING_TRIGGER that grows the team's Shield by 5 per turn for the
# effect's full duration, and that ticker — not the Shield — is what jaden6 / jaden7 gate their
# fusions on. (Clayman is now a TEAM buff: 10 Shield to every ally, +5 each turn.)
#
# TWO halves, and the first is useless without the second:
#   1. "Elemental HERO Clayman" is absent from character_component.HERO_SHIELD_BOUND, so breaking the
#      Shield no longer calls break_hero (which wipes every same-named effect off EVERY character,
#      ticker included).
#   2. clayman_tick REBUILDS the Shield when none is left. It used to only top up an EXISTING Clayman
#      Shield, so after a break the surviving ticker would have spun uselessly for the rest of its
#      window — the card would technically be alive while delivering nothing.
#   godot --headless --path <repo> res://training/tests/clayman_persist_probe.tscn

var fails := 0

func _check(c, l, detail := ""):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l + ("  (" + detail + ")" if detail != "" else ""))

func _build(u, names, is_enemy):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _clayman_shield(jaden):
	for s in jaden.get_shield_effects():
		if s.source and s.source.ability_name == "Elemental HERO Clayman":
			return s
	return null

func _clayman_ticker(jaden):
	return jaden.has_effect("Elemental HERO Clayman", EffectType.Type.TICKING_TRIGGER, jaden)

func _ready():
	print("=== clayman persistence probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Jaden", ["jaden", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["killua", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	var jaden = p1.team.characters[0]
	var foe = p2.team.characters[0]

	# Cast Clayman.
	var clayman = jaden.moveset.base_abilities[2]
	jaden.targeter.targets = [jaden]
	jaden.targeter.main_target = jaden
	jaden.used_ability = clayman
	clayman.execute(jaden, m)

	_check(_clayman_shield(jaden) != null, "[setup] Clayman grants a Shield")
	_check(_clayman_ticker(jaden) != null, "[setup] ...and installs the regen ticker")
	# Clayman is now a TEAM buff — every ally receives the 10 Shield, not just Jaden.
	var teammate = p1.team.characters[1]
	_check(_clayman_shield(teammate) != null, "[setup] a TEAMMATE also receives a Clayman Shield (team-wide)")

	# ==================================================================================
	# A — BREAKING THE SHIELD MUST NOT REMOVE CLAYMAN.
	#     shatter_shields is the engine's real teardown entry point and is what fires the
	#     contingent check_effect_breaking hook; erasing the effect by hand would skip it
	#     and prove nothing.
	# ==================================================================================
	jaden.shatter_shields(foe)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(_clayman_shield(jaden) == null, "[A] the Shield is genuinely gone after shatter_shields")
	_check(_clayman_ticker(jaden) != null,
		"[A] but the REGEN TICKER survives — Clayman is not torn down with his Shield")

	# ==================================================================================
	# B — AND THE SURVIVING TICKER STILL DOES ITS JOB. This is the half that a
	#     HERO_SHIELD_BOUND-only fix would miss: the ticker used to top up an existing
	#     Shield and no-op when there was none.
	# ==================================================================================
	var ticker = _clayman_ticker(jaden)
	ticker.trigger.check(QueryContext.from_effect_end(ticker))
	await get_tree().process_frame

	var regrown = _clayman_shield(jaden)
	_check(regrown != null, "[B] the ticker REBUILDS the Shield from nothing after a break")
	if regrown != null:
		_check(regrown.mag == 5, "[B] ...at 5, the per-turn growth amount", str(regrown.mag))
		_check(regrown.duration <= ticker.duration,
			"[B] ...and it cannot outlive the ticker that maintains it",
			"shield %d vs ticker %d" % [regrown.duration, ticker.duration])

	# A second tick tops the rebuilt Shield up rather than stacking a second one.
	ticker.trigger.check(QueryContext.from_effect_end(ticker))
	await get_tree().process_frame
	var count := 0
	for s in jaden.get_shield_effects():
		if s.source and s.source.ability_name == "Elemental HERO Clayman":
			count += 1
	_check(count == 1, "[B] a second tick tops up rather than creating a duplicate Shield", str(count))

	# ==================================================================================
	# C — THE FUSIONS. jaden6 / jaden7 now gate on the ingredient ABILITY_SWAP (which, like the
	#     ticker, is not shield-bound), so a broken Shield must not lock them out. (The gate moved
	#     from the ticker to the swap so a Helpful cleanse can't strip the ingredient handle.)
	# ==================================================================================
	_check(jaden.has_effect("Elemental HERO Clayman", EffectType.Type.TICKING_TRIGGER, jaden) != null,
		"[C] the Clayman ticker still present after the break")
	_check(jaden.has_effect("Elemental HERO Clayman", EffectType.Type.ABILITY_SWAP, jaden) != null,
		"[C] the ABILITY_SWAP the fusions now gate on also survives the break")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
