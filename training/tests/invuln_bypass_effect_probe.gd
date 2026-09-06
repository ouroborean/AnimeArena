extends Node
# Regression probe for the bypass/invuln effect-application bug (2026-08-14):
# a skill whose target() bypasses invuln must ALSO pass bypassing=true to add_hostile_effect, or its
# non-damage effect silently drops on an invulnerable target even though the skill was used on them.
# Genius Sniper (mine3) is the named case; cell8 / yubel4 / yuno7 got the identical one-arg fix.
#   godot --headless --path <repo> res://training/tests/invuln_bypass_effect_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy: bool = (u == "BotEnemy")
	for cn in names: p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _fresh(allies, foes) -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", allies)
	var p2 := _build_player("BotEnemy", foes)
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _cast(caster, ab, targets, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _ready():
	print("=== invuln-bypass effect probe ===")
	var s = _fresh(["mine", "naruto", "sakura"], ["misaka", "eren", "gray"])
	var m = s["m"]
	var mine = s["allies"][0]
	var foe = s["foes"][0]

	# Make the foe invulnerable to everything (a plain, non-cost-restricted invuln).
	var ctx = QueryContext.from_game_state(foe, m)
	var inv = Effect.invuln_effect(2)
	inv.set_source(mine.moveset.base_abilities[3])   # any source; invuln is a self-buff
	Character.add_allied_effect(ctx, foe, foe, inv)
	_check(foe.effects.get_effects_by_type(EffectType.Type.INVULN).size() >= 1, "foe is invulnerable")

	# Genius Sniper = mine3 = base_abilities[2]. Cast it on the invulnerable foe.
	var gs = mine.moveset.base_abilities[2]
	_cast(mine, gs, [foe], m)

	# THE FIX: the vulnerability effect must land on the invuln target (name == source ability name).
	var vuln = foe.has_effect("Genius Sniper", EffectType.Type.VULNERABILITY, mine)
	_check(vuln != null, "Genius Sniper's vulnerability effect LANDS on the invulnerable target (bypass fix)")

	# Sanity: the same call WITHOUT bypass would be dropped — confirm add_hostile_effect drops a
	# non-bypassing harmful effect on this invuln foe, so the test above is actually exercising the gate.
	var ctx2 = QueryContext.from_game_state(mine, m)
	var plain = Effect.vulnerability_effect(5, 2, ["Roman Artillery - Pumpkin"])
	plain.set_source(mine.moveset.base_abilities[0])   # source = Roman Artillery (mine1), name differs from Genius Sniper
	Character.add_hostile_effect(ctx2, mine, foe, plain)   # bypassing defaults to FALSE
	_check(foe.has_effect("Roman Artillery - Pumpkin", EffectType.Type.VULNERABILITY, mine) == null,
		"control: a NON-bypassing harmful effect is still correctly dropped on the invuln foe")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
