extends Node

# TSUBAKI SOUL RESONANCE's copied skill lasts until the END OF THE ALLY'S NEXT TURN.
#
# Bug: the SKILL_COPY was dur 2 (== 1 turn), but it's applied on TSUBAKI'S turn, so it ticked out at
# the end of the opponent's turn — one tick before the ally's next turn — and the ally never got to use
# the replaced skill. Fix: dur 3, so it survives the opponent's turn and is still in the slot for the
# ally's next turn, expiring at the end of it. Durations tick at each side's turn-end.
#   godot --headless --path <repo> res://training/tests/tsubaki_soul_resonance_probe.tscn

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

func _copy(ally):
	var arr = ally.effects.get_effects_by_type(EffectType.Type.SKILL_COPY)
	return arr[0] if arr.size() > 0 else null

func _ready():
	print("=== tsubaki soul resonance duration probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build("ZZ_Tsu", ["tsubaki", "gon", "gray"], false)
	var p2 = _build("ZZ_Foe", ["killua", "misaka", "byakuya"], true)
	m.random_panel_needed.connect(func(_a, _b, _c): pass)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var tsubaki = p1.team.characters[0]
	var ally = p1.team.characters[1]
	var ctx = QueryContext.from_game_state(tsubaki, m)

	# Mark the ally as wielding Tsubaki (Tsubaki Mode: Kusarigama) so the copy branch fires.
	var wield = Effect.mark(-1, "Wielding Tsubaki")
	wield.set_source(tsubaki.moveset.base_abilities[0])   # tsubaki1 = Tsubaki Mode: Kusarigama
	Character.add_allied_effect(ctx, tsubaki, ally, wield)
	_check(ally.marked_by("Tsubaki Mode: Kusarigama"), "[setup] ally is wielding Tsubaki")

	# Cast Tsubaki Soul Resonance (tsubaki3, index 2) on the ally.
	var soul = tsubaki.moveset.base_abilities[2]
	tsubaki.targeter.targets = [ally]
	tsubaki.targeter.main_target = ally
	tsubaki.used_ability = soul
	soul.execute(tsubaki, m)

	var copy = _copy(ally)
	_check(copy != null, "[cast] the ally's skill is replaced (SKILL_COPY applied)")
	if copy == null:
		print("=== probe done: %d failure(s) ===" % fails); get_tree().quit(1); return
	_check(int(copy.duration) == 3, "[cast] copy duration is 3 (was 2 — the +1 fix)", "got %d" % int(copy.duration))
	_check(copy.ability_targets != null and copy.ability_targets.ability_name == "Tsubaki Mode: Uncanny Sword",
		"[cast] the replacement is Tsubaki Mode: Uncanny Sword")

	# Tick 1 = end of Tsubaki's (cast) turn.
	ally.effects.tick_all_effects_durations()
	_check(_copy(ally) != null, "[turn] copy survives the end of Tsubaki's own turn")

	# Tick 2 = end of the OPPONENT's turn. THE FIX: a dur-2 copy would be GONE here; dur-3 survives,
	# so it's still in the ally's slot for the ally's next turn.
	ally.effects.tick_all_effects_durations()
	_check(_copy(ally) != null, "[FIX] copy still present after the opponent's turn — available on the ally's NEXT turn")

	# Tick 3 = end of the ally's next turn. It expires here ("until the end of their next turn").
	ally.effects.tick_all_effects_durations()
	_check(_copy(ally) == null, "[turn] copy expires at the end of the ally's next turn")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
