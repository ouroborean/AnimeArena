extends Node
# Runtime checks for Piccolo's channel kit (owner-confirmed lifecycle). Stacks accrue via an
# END_OF_TURN_TRIGGER at the end of Piccolo's turn (start at 0), not a ticking effect.
#   godot --headless --path <repo> res://training/tests/piccolo_probe.tscn

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
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "pic": p1.team.characters[0], "foes": p2.team.characters}

func _cast(caster, ab, targets, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

const EOT := EffectType.Type.END_OF_TURN_TRIGGER

func _green(pic) -> int:
	return int(pic.team.energy.pool.get(Energy.Type.GREEN, 0))

func _ready():
	print("=== PICCOLO probe ===")

	# ---------- Special Beam Cannon: start (0 stacks) -> end-of-turn +1 -> re-use ----------
	var s = _fresh(); var m = s["m"]; var pic = s["pic"]; var foe = s["foes"][0]
	var sbc = pic.moveset.base_abilities[0]
	_cast(pic, sbc, [foe], m)
	var mark = pic.has_effect("Special Beam Cannon", EffectType.Type.MARK, pic)
	var master = pic.has_effect("Special Beam Cannon", EffectType.Type.CHANNEL_CANCEL, pic)
	_check(mark != null and mark.stack_count() == 0, "SBC start: stacks begin at 0 (no free start stack)")
	_check(master != null and int(master.mag) == 0, "SBC start: turns channeled = 0")
	_check(pic.has_effect("Special Beam Cannon", EOT, pic) != null, "SBC start: END_OF_TURN_TRIGGER installed (not ticking)")
	# end of Piccolo's turn -> +1
	sbc.sbc_tick(QueryContext.from_effect_end(pic.has_effect("Special Beam Cannon", EOT, pic)))
	_check(mark.stack_count() == 1 and int(master.mag) == 1, "SBC end-of-turn: stacks=1, turns=1")
	# re-use -> 25 + 25*1 = 50 Piercing; permanent shield 5*1=5; SBC on cd; channel gone
	var hp0 = int(foe.health.hp)
	_cast(pic, sbc, [foe], m)
	_check(hp0 - int(foe.health.hp) == 45, "SBC re-use: 25 + 20/stack = 45 damage (had 1 stack)")
	var sh = pic.has_effect("Namekian Power", EffectType.Type.SHIELD, pic)
	_check(sh != null and sh.mag == 5 and sh.duration < 0, "SBC re-use: +5 PERMANENT shield (5 x 1 turn)")
	_check(sbc.cooldown_remaining >= 2, "SBC re-use: skill goes on cooldown")
	_check(pic.has_effect("Special Beam Cannon", EffectType.Type.CHANNEL_CANCEL, pic) == null, "SBC re-use: channel torn down")
	_check(pic.has_effect("Special Beam Cannon", EOT, pic) == null, "SBC re-use: the end-of-turn trigger is gone (no extra stack that turn)")

	# ---------- re-use costs 1 Green (not free); start also 1 Green ----------
	var s1b = _fresh(); var m1b = s1b["m"]; var picb = s1b["pic"]
	var sbcb = picb.moveset.base_abilities[0]
	_check(int(sbcb.cost().get(0, 0)) == 1, "SBC (first use) costs 1 Green")
	_cast(picb, sbcb, [s1b["foes"][0]], m1b)   # start channel
	_check(int(sbcb.cost().get(0, 0)) == 1, "SBC re-use STILL costs 1 Green (override removed)")

	# ---------- SBC targeting: first use = self, re-use = an enemy ----------
	var st = _fresh(); var mt = st["m"]; var pict = st["pic"]; var foet = st["foes"][0]
	var sbct = pict.moveset.base_abilities[0]
	mt.reset_character_targeted()
	sbct.target(pict, mt)
	_check(pict.targeted and not foet.targeted, "SBC first use targets Piccolo (self)")
	_cast(pict, sbct, [pict], mt)   # begin channel
	mt.reset_character_targeted()
	sbct.target(pict, mt)
	_check(foet.targeted, "SBC re-use targets an enemy")

	# ---------- Enemy interrupt: shield + 1 Green, no payoff ----------
	var s2 = _fresh(); var m2 = s2["m"]; var pic2 = s2["pic"]; var foe2 = s2["foes"][0]
	var sbc2 = pic2.moveset.base_abilities[0]
	var g0 = _green(pic2)
	_cast(pic2, sbc2, [foe2], m2)
	sbc2.sbc_tick(QueryContext.from_effect_end(pic2.has_effect("Special Beam Cannon", EOT, pic2)))   # channel 1 turn
	var stun = Effect.stun_effect(2)
	stun.set_source(foe2.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(foe2, m2), foe2, pic2, stun)
	pic2.check_cancels()
	_check(pic2.has_effect("Special Beam Cannon", EffectType.Type.CHANNEL_CANCEL, pic2) == null, "interrupt: channel ended")
	_check(pic2.has_effect("Namekian Power", EffectType.Type.SHIELD, pic2) != null, "interrupt: still gains shield (channeled 1 turn)")
	_check(_green(pic2) == g0 + 1, "interrupt: gains 1 Green energy")

	# ---------- Hellzone Grenade: AoE stacks at end of turn -> re-use ----------
	var s3 = _fresh(); var m3 = s3["m"]; var pic3 = s3["pic"]; var foes3 = s3["foes"]
	var hz = pic3.moveset.base_abilities[1]
	_cast(pic3, hz, foes3, m3)
	_check(foes3[0].has_effect("Hellzone Grenade", EffectType.Type.MARK, pic3) == null, "Hellzone start: no stacks yet (they land at end of turn)")
	hz.hellzone_tick(QueryContext.from_effect_end(pic3.has_effect("Hellzone Grenade", EOT, pic3)))
	var em = foes3[0].has_effect("Hellzone Grenade", EffectType.Type.MARK, pic3)
	_check(em != null and em.stack_count() == 1, "Hellzone end-of-turn: enemy stack at 1")
	var ehp0 = int(foes3[0].health.hp)
	_cast(pic3, hz, foes3, m3)
	_check(ehp0 - int(foes3[0].health.hp) == 10, "Hellzone re-use: 10/stack x 1 = 10 to each enemy")

	# ---------- Regeneration: heal ½ missing + 10/stack ----------
	var s4 = _fresh(); var m4 = s4["m"]; var pic4 = s4["pic"]
	pic4.health.hp = 40   # missing 60
	var regen = pic4.moveset.base_abilities[2]
	_cast(pic4, regen, [pic4], m4)
	regen.regen_tick(QueryContext.from_effect_end(pic4.has_effect("Regeneration", EOT, pic4)))   # stacks=1
	_cast(pic4, regen, [pic4], m4)   # heal: 60/2 + 10*1 = 40 -> 40 -> 80
	_check(int(pic4.health.hp) == 80, "Regen re-use: heal 30 (½ of 60 missing) + 10 (10/stack) = 80 HP")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
