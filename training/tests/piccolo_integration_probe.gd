extends Node
# DEEPER Piccolo test: drives the REAL turn pipeline (BattleManager.execute_ability +
# end_of_turn_effect_handling) across actual turns, rather than calling ability.execute() directly.
# This is what exercises "Preserves Channel" (cancel_channels is skipped in execute_ability), the
# team-gated END_OF_TURN_TRIGGER, the enemy-interrupt cooldown, and the invuln-respecting payoff —
# none of which the unit probe (piccolo_probe.gd) touches.
#   godot --headless --path <repo> res://training/tests/piccolo_integration_probe.tscn

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

func _fresh() -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["piccolo", "naruto", "sakura"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "gray"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)   # first=true -> Piccolo (p1) acts turn 1
	return {"m": m, "pic": p1.team.characters[0], "foes": p2.team.characters}

# Stage + execute one skill through the REAL server path (cancel_channels / Preserves-Channel,
# start_cooldown, invuln-target-drop, use-triggers).
func _cast(m, caster, ab, targets):
	caster.used_ability = ab
	caster.targeter.targets = targets.duplicate()
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	m.execute_ability(ab)

# End the current side's turn: fires the acting team's end-of-turn triggers + cooldown advance, ticks
# all durations, and hands the turn to the other side (turn_over -> start_new_turn/wait_for_turn).
func _end_turn(m):
	m.end_of_turn_effect_handling()

func _chan(pic, name):
	return pic.has_effect(name, EffectType.Type.CHANNEL_CANCEL, pic)

func _mark(c, name, src):
	return c.has_effect(name, EffectType.Type.MARK, src)

func _shield(pic) -> int:
	var t := 0
	for s in pic.get_shield_effects(): t += int(s.mag)
	return t

func _green(pic) -> int:
	return int(pic.team.energy.pool.get(Energy.Type.GREEN, 0))

func _invuln(target, m, dur):
	var inv = Effect.invuln_effect(dur)
	inv.set_source(target.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(target, m), target, target, inv)

func _ready():
	print("=== PICCOLO integration probe (real turns) ===")

	# ============================================================================================
	# A. Special Beam Cannon full cycle over real turns: start -> team-gated accrue -> re-use.
	# ============================================================================================
	var s = _fresh(); var m = s["m"]; var pic = s["pic"]; var foe = s["foes"][0]
	var sbc = pic.moveset.base_abilities[0]
	# Turn 1 (Piccolo): begin channel (first use targets self)
	_cast(m, pic, sbc, [pic])
	_check(_chan(pic, "Special Beam Cannon") != null, "A. turn 1: SBC channel started (via execute_ability, Preserves Channel kept it alive)")
	_check(_mark(pic, "Special Beam Cannon", pic).stack_count() == 0, "A. turn 1: 0 stacks at start")
	_end_turn(m)   # end of Piccolo's turn -> +1 stack
	_check(_mark(pic, "Special Beam Cannon", pic).stack_count() == 1, "A. end of Piccolo turn 1: 1 stack (END_OF_TURN_TRIGGER fired)")
	_check(int(sbc.cooldown_remaining) == 0, "A. SBC is off cooldown (printed cd 0) for the coming re-use")
	# Turn 2 (enemy): end it WITHOUT any Piccolo action -> his trigger must NOT fire (team-gated)
	_end_turn(m)
	_check(_mark(pic, "Special Beam Cannon", pic).stack_count() == 1, "A. end of ENEMY turn: still 1 stack (trigger is team-gated, no phantom accrual)")
	# Turn 3 (Piccolo): re-use SBC (now targets an enemy) -> 25 + 25*1 = 50 Piercing
	var hp0 = int(foe.health.hp)
	_cast(m, pic, sbc, [foe])
	_check(hp0 - int(foe.health.hp) == 45, "A. turn 3 re-use: 25 + 20/stack = 45 damage (1 stack)")
	_check(_shield(pic) == 5, "A. re-use: +5 permanent Shield (5 x 1 turn channeled)")
	_check(_chan(pic, "Special Beam Cannon") == null, "A. re-use: channel torn down")
	_end_turn(m)
	_check(int(sbc.cooldown_remaining) == 1, "A. after re-use turn ends: SBC on cooldown 1 (voluntary end settles to 1)")

	# ============================================================================================
	# B. Multi-turn accrual (2 stacks) + Energy Deflection preserves the channel + shield scales.
	# ============================================================================================
	s = _fresh(); m = s["m"]; pic = s["pic"]; foe = s["foes"][0]
	sbc = pic.moveset.base_abilities[0]
	var ed = pic.moveset.base_abilities[3]
	_cast(m, pic, sbc, [pic]); _end_turn(m)          # turn 1: start, +1 stack
	_end_turn(m)                                       # enemy turn
	_check(_mark(pic, "Special Beam Cannon", pic).stack_count() == 1, "B. 1 stack after first cycle")
	# Turn 3 (Piccolo): Energy Deflection mid-channel must NOT cancel the channel
	_cast(m, pic, ed, [pic])
	_check(_chan(pic, "Special Beam Cannon") != null, "B. Energy Deflection used mid-channel does NOT end the channel (Preserves Channel)")
	_check(pic.effects.get_effects_by_type(EffectType.Type.INVULN).size() >= 1, "B. Energy Deflection still grants Invulnerability")
	_end_turn(m)                                       # +1 stack -> 2
	_end_turn(m)                                       # enemy turn
	_check(_mark(pic, "Special Beam Cannon", pic).stack_count() == 2, "B. 2 stacks after channeling a second Piccolo turn")
	# Turn 5 (Piccolo): re-use with 2 stacks -> 25 + 25*2 = 75, shield 5*2 = 10
	hp0 = int(foe.health.hp)
	_cast(m, pic, sbc, [foe])
	_check(hp0 - int(foe.health.hp) == 65, "B. re-use with 2 stacks: 25 + 40 = 65 damage")
	_check(_shield(pic) == 10, "B. re-use: shield scales with turns channeled (5 x 2 = 10)")

	# ============================================================================================
	# C. Switch: using a DIFFERENT channel skill ends the current one (shield + CD, NO payoff).
	# ============================================================================================
	s = _fresh(); m = s["m"]; pic = s["pic"]; foe = s["foes"][0]
	sbc = pic.moveset.base_abilities[0]
	var hz = pic.moveset.base_abilities[1]
	_cast(m, pic, sbc, [pic]); _end_turn(m)          # turn 1: SBC channel, 1 stack
	_end_turn(m)                                       # enemy turn
	hp0 = int(foe.health.hp)
	_cast(m, pic, hz, [foe])                           # turn 3: switch to Hellzone
	_check(_chan(pic, "Special Beam Cannon") == null, "C. switch: SBC channel ended")
	_check(_chan(pic, "Hellzone Grenade") != null, "C. switch: Hellzone channel started")
	_check(_shield(pic) == 5, "C. switch: SBC end granted +5 shield (1 turn channeled)")
	_check(int(foe.health.hp) == hp0, "C. switch: NO payoff damage from SBC or Hellzone-start")
	_end_turn(m)
	_check(int(sbc.cooldown_remaining) == 1, "C. switched-away SBC settled to cooldown 1")

	# ============================================================================================
	# D. Realistic enemy interrupt: a Stun applied on the ENEMY's turn ends the channel via
	#    check_cancels (auto). Shield + 1 Green, and cooldown is exactly 1 (finding-1 regression).
	# ============================================================================================
	s = _fresh(); m = s["m"]; pic = s["pic"]; foe = s["foes"][0]
	sbc = pic.moveset.base_abilities[0]
	_cast(m, pic, sbc, [pic]); _end_turn(m)          # turn 1: channel, 1 stack, mag 1
	# Turn 2 (enemy): apply a Stun to Piccolo. add_effect auto-fires check_cancels -> on_interrupt.
	var g_before = _green(pic)
	var stun = Effect.stun_effect(2); stun.set_source(foe.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(foe, m), foe, pic, stun)
	_check(_chan(pic, "Special Beam Cannon") == null, "D. interrupt: channel ended by the enemy Stun")
	_check(_shield(pic) == 5, "D. interrupt: +5 shield (1 turn channeled)")
	_check(_green(pic) == g_before + 1, "D. interrupt: gained 1 Green energy")
	_check(int(sbc.cooldown_remaining) == 1, "D. interrupt: SBC cooldown is 1, not 2 (enemy-turn end won't reclaim the +1)")
	_end_turn(m)   # rest of enemy turn 2 -> Piccolo NOT in acting team, cooldown unchanged
	_check(int(sbc.cooldown_remaining) == 1, "D. after enemy turn ends: SBC cooldown still 1 (Piccolo not advanced on enemy turn)")
	# Turn 3 (Piccolo): SBC should be locked out this one turn, then free.
	_check(int(sbc.cooldown_remaining) == 1, "D. Piccolo's next turn: SBC still on cooldown (1 Piccolo-turn lockout)")
	_end_turn(m)   # Piccolo's turn ends -> advance -> 1 -> 0
	_check(int(sbc.cooldown_remaining) == 0, "D. SBC usable again after exactly ONE Piccolo turn (matches voluntary ends)")

	# ============================================================================================
	# E1. Hellzone payoff must NOT damage an Invulnerable enemy (non-Bypassing skill; finding 2).
	# ============================================================================================
	s = _fresh(); m = s["m"]; pic = s["pic"]
	var foes = s["foes"]
	hz = pic.moveset.base_abilities[1]
	_cast(m, pic, hz, [foes[0]]); _end_turn(m)       # turn 1: Hellzone channel; tick stacks all enemies (1 each)
	_check(_mark(foes[0], "Hellzone Grenade", pic) != null and _mark(foes[0], "Hellzone Grenade", pic).stack_count() == 1, "E1. Hellzone: enemy 0 has 1 stack after first tick")
	_check(_mark(foes[1], "Hellzone Grenade", pic) != null and _mark(foes[1], "Hellzone Grenade", pic).stack_count() == 1, "E1. Hellzone: enemy 1 has 1 stack after first tick")
	_invuln(foes[1], m, 4)                             # enemy 1 becomes Invulnerable
	_end_turn(m)                                       # enemy turn
	var eh0 = int(foes[0].health.hp)
	var eh1 = int(foes[1].health.hp)
	_cast(m, pic, hz, [foes[0]])                       # turn 3: re-use AoE payoff
	_check(eh0 - int(foes[0].health.hp) == 10, "E1. Hellzone payoff hits the targetable enemy (10 = 1 stack)")
	_check(int(foes[1].health.hp) == eh1, "E1. Hellzone payoff deals NO damage to the Invulnerable enemy")

	# ============================================================================================
	# E2. Hellzone tick must NOT keep stacking on an enemy that is Invulnerable at tick time (finding 3).
	# ============================================================================================
	s = _fresh(); m = s["m"]; pic = s["pic"]; foes = s["foes"]
	hz = pic.moveset.base_abilities[1]
	_cast(m, pic, hz, [foes[0]]); _end_turn(m)       # turn 1: 1 stack on each
	_invuln(foes[1], m, 6)                             # enemy 1 Invulnerable, survives to the next tick
	_end_turn(m)                                       # enemy turn
	_end_turn(m)                                       # turn 3 (Piccolo) end -> Hellzone ticks again
	_check(_mark(foes[0], "Hellzone Grenade", pic).stack_count() == 2, "E2. targetable enemy accrued a 2nd stack")
	_check(_mark(foes[1], "Hellzone Grenade", pic).stack_count() == 1, "E2. Invulnerable enemy did NOT accrue a 2nd stack (still 1)")

	# ============================================================================================
	# F. Regeneration real-turn heal: start -> accrue 1 -> re-use heals half missing + 10/stack.
	# ============================================================================================
	s = _fresh(); m = s["m"]; pic = s["pic"]
	pic.health.hp = 40                                 # missing 60
	var regen = pic.moveset.base_abilities[2]
	_cast(m, pic, regen, [pic]); _end_turn(m)        # turn 1: channel, 1 stack
	_end_turn(m)                                       # enemy turn
	_cast(m, pic, regen, [pic])                        # turn 3: re-use -> 60/2 + 10*1 = 40 -> 80
	_check(int(pic.health.hp) == 80, "F. Regeneration re-use heals 30 (half of 60) + 10/stack = 80 HP")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
