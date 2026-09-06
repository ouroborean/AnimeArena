extends Node

# ============================================================================
# INDEPENDENT VERIFICATION of the four Phase B claims most likely to be fake.
# Written from the roadmap's Verify list, NOT derived from the build stages'
# own probes, so a shared mistake in those cannot be inherited here.
#
#   godot --headless --path <repo> res://training/tests/verify_phaseb_probe.tscn
#
# (a) counter.on: "outgoing" cancels the ENEMY'S skill through the LIVE path.
#     Driven through BattleManager.execute_ability, which is the only caller of
#     Character.countered() ("new multiplayer/battle_manager.gd":1204). The
#     assertion is on the VICTIM'S HP, never on the effect — a counter wired to
#     check_counter_use_effects / check_counter_receive_effects (both zero
#     callers repo-wide) would leave the effect looking perfect and the damage
#     landing anyway.
# (b) `holder` on an ENEMY-held trigger is the ENEMY, not the caster.
# (c) `affected` on on_damage_dealt is the VICTIM, not the dealer.
# (d) a holder killed mid-payload yields [] and causes NO self-damage.
#
# Every negative is paired with a positive control on the same board, so an
# assertion that could not fail is visible as such.
# ============================================================================

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

# A fresh board per group: effects persist and HP does not reset, so a shared
# board would let one group decide another's answer.
func _fresh() -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _mk(spec: Dictionary, owner, harmful := true) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Verify Probe"))
	a.classes = {"Physical": harmful, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": not harmful, "Harmful": harmful, "Helpful": not harmful, "Instant": true,
		"Action": false, "Control": false, "Channeled": false, "Uncounterable": false,
		"Bypassing": false, "Stealthed": false, "Passive": false, "Preserves Channel": false,
		"Damaging": harmful}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

# Direct execute — used only where the live turn path is not what is under test.
func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

# THE LIVE PATH. execute_ability is what a real turn runs; it is the function
# that calls countered() and skips ability.execute entirely when it returns true.
func _live_cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.acted = false
	m.execute_ability(ab)
	caster.used_ability = null

func _plant(applier, bearer, m, eff: Dictionary) -> void:
	var ab := _mk({"name": "Plant %s" % str(eff.get("kind", "?")), "target": "enemy",
		"blocks": [{"op": "apply", "to": "target", "effect": eff}]}, applier)
	_cast(applier, ab, [bearer], m)


func _ready():
	print("=== INDEPENDENT Phase B verification (a)-(d) ===")

	# =================================================================================
	# (a) counter.on: "outgoing" — the muzzle.
	#
	# A counter is planted on an ENEMY. That enemy then attacks one of my characters
	# through BattleManager.execute_ability. The claim is that countered()'s FIRST loop
	# (COUNTER_USE, character_component.gd:433) fires and execute_ability never reaches
	# ability.execute — so THE VICTIM TAKES NOTHING.
	#
	# The positive control is the same attacker, the same skill, the same victim, one
	# turn later with no counter on the board: it must land in full. Without that
	# control "the victim took nothing" could pass because the attack never happened.
	# =================================================================================
	var ga := _fresh()
	var ma = ga["m"]
	var me = ga["allies"][0]
	var victim = ga["allies"][1]
	var attacker = ga["foes"][0]
	var attacker2 = ga["foes"][1]

	# The muzzle: an OUTGOING counter on the enemy, whose payload marks the bearer so
	# the payload's own firing is observable separately from the cancel.
	_plant(me, attacker, ma, {"kind": "counter", "on": "outgoing", "scope": "harmful",
		"turns": 20, "then": [{"op": "damage", "amount": 7, "to": "holder"}]})

	var atk := _mk({"name": "Enemy Swing", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20}]}, attacker)
	var atk2 := _mk({"name": "Enemy Swing Two", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20}]}, attacker2)

	var v_hp: int = victim.health.hp
	var atk_hp: int = attacker.health.hp
	_live_cast(attacker, atk, [victim], ma)
	_check(victim.health.hp == v_hp,
		"(a) THE CLAIM: the muzzled enemy's 20 damage NEVER LANDED (%d -> %d)" % [v_hp, victim.health.hp])
	_check(attacker.health.hp == atk_hp - 7,
		"(a) ...and the counter's payload fired on the bearer via `holder` (%d -> %d, -7)" % [atk_hp, attacker.health.hp])

	# POSITIVE CONTROL, same board: an UNMUZZLED enemy's identical skill does land.
	var v_hp2: int = victim.health.hp
	_live_cast(attacker2, atk2, [victim], ma)
	_check(victim.health.hp == v_hp2 - 20,
		"(a) CONTROL: the same skill from an UNMUZZLED enemy lands in full (%d -> %d, -20)" % [v_hp2, victim.health.hp])

	# ...and the muzzle is spent, so the SAME attacker now connects. This is what
	# separates "countered" from "this character can never act".
	var v_hp3: int = victim.health.hp
	_live_cast(attacker, atk, [victim], ma)
	_check(victim.health.hp == v_hp3 - 20,
		"(a) CONTROL: once the counter is spent the same attacker connects (%d -> %d, -20)" % [v_hp3, victim.health.hp])

	# =================================================================================
	# (b) `holder` on an ENEMY-held trigger is the ENEMY.
	#
	# The failure mode being ruled out is a silent fallback to the caster. So the
	# assertion is a PAIR: the enemy bearer loses the HP *and* the caster loses none.
	# =================================================================================
	var gb := _fresh()
	var mb = gb["m"]
	var caster = gb["allies"][0]
	var foe = gb["foes"][0]
	var foe_ctrl = gb["foes"][1]

	_plant(caster, foe, mb, {"kind": "trigger", "trigger": "on_skill_received", "turns": 20,
		"then": [{"op": "damage", "amount": 13, "to": "holder"}]})
	# The control twin: identical, but written `to: "user"`. If `holder` fell back to
	# the caster the two would be indistinguishable and this pair would agree.
	_plant(caster, foe_ctrl, mb, {"kind": "trigger", "trigger": "on_skill_received", "turns": 20,
		"then": [{"op": "damage", "amount": 13, "to": "user"}]})

	var poke := _mk({"name": "Poke", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 0}]}, caster)

	var c_hp: int = caster.health.hp
	var f_hp: int = foe.health.hp
	foe.check_ability_receive_triggers(mb, poke)
	_check(foe.health.hp == f_hp - 13,
		"(b) THE CLAIM: `holder` on an ENEMY-held trigger hit the ENEMY (%d -> %d, -13)" % [f_hp, foe.health.hp])
	_check(caster.health.hp == c_hp,
		"(b) ...and the CASTER took nothing — no silent fallback (%d unchanged)" % caster.health.hp)

	# CONTROL on the same board: `to: "user"` really does still mean the applier.
	c_hp = caster.health.hp
	var fc_hp: int = foe_ctrl.health.hp
	foe_ctrl.check_ability_receive_triggers(mb, poke)
	_check(caster.health.hp == c_hp - 13,
		"(b) CONTROL: the twin written `to: \"user\"` hit the CASTER (%d -> %d, -13)" % [c_hp, caster.health.hp])
	_check(foe_ctrl.health.hp == fc_hp,
		"(b) ...and left its own bearer alone (%d unchanged)" % foe_ctrl.health.hp)

	# =================================================================================
	# (c) `affected` on on_damage_dealt is the VICTIM.
	#
	# This is the hook where holder != affected, so it is the one that proves two
	# selectors were needed. Both are planted on the SAME dealer, aimed at DIFFERENT
	# amounts, and fired by ONE damage event — so the two numbers are read off one
	# board with nothing else varying.
	# =================================================================================
	var gc := _fresh()
	var mc = gc["m"]
	var dealer = gc["allies"][0]
	var bystander = gc["allies"][1]
	var target_of_hit = gc["foes"][0]

	_plant(bystander, dealer, mc, {"kind": "trigger", "trigger": "on_damage_dealt", "turns": 20,
		"then": [{"op": "damage", "amount": 9, "to": "affected"},
				 {"op": "damage", "amount": 4, "to": "holder"}]})

	var swing := _mk({"name": "Dealer Swing", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 6}]}, dealer)
	var d_hp: int = dealer.health.hp
	var t_hp: int = target_of_hit.health.hp
	var by_hp: int = bystander.health.hp
	dealer.used_ability = swing
	dealer.deal_ability_damage(swing, 6, target_of_hit, DamageType.Type.NORMAL)
	dealer.used_ability = null

	_check(target_of_hit.health.hp == t_hp - 6 - 9,
		"(c) THE CLAIM: `affected` landed on the VICTIM (%d -> %d: 6 hit + 9 payload)" % [t_hp, target_of_hit.health.hp])
	_check(dealer.health.hp == d_hp - 4,
		"(c) CONTROL: `holder` on the SAME hook landed on the DEALER (%d -> %d, -4)" % [d_hp, dealer.health.hp])
	_check(bystander.health.hp == by_hp,
		"(c) ...and the APPLIER, who is neither, took nothing (%d unchanged)" % bystander.health.hp)

	# =================================================================================
	# (d) a holder killed mid-payload yields [] — and NOT the caster.
	#
	# Two blocks. The first kills the holder; the second must find nobody. The whole
	# point is the direction of the failure: a fallback to `user` would show up as the
	# APPLIER taking the second block's damage, which is the run-07 defect in reverse.
	# =================================================================================
	var gd := _fresh()
	var md = gd["m"]
	var applier = gd["allies"][0]
	var doomed = gd["foes"][0]
	var survivor = gd["foes"][1]

	# Bring the bearer down to a known sliver so the first block is lethal by exactly
	# the amount authored, not by luck.
	doomed.health.hp = 8

	_plant(applier, doomed, md, {"kind": "trigger", "trigger": "on_skill_received", "turns": 20,
		"then": [{"op": "damage", "amount": 30, "to": "holder"},
				 {"op": "damage", "amount": 25, "to": "holder"}]})
	# CONTROL: the identical two-block payload on a HEALTHY bearer must take both.
	_plant(applier, survivor, md, {"kind": "trigger", "trigger": "on_skill_received", "turns": 20,
		"then": [{"op": "damage", "amount": 30, "to": "holder"},
				 {"op": "damage", "amount": 25, "to": "holder"}]})

	var poke_d := _mk({"name": "Poke D", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 0}]}, applier)

	var ap_hp: int = applier.health.hp
	doomed.check_ability_receive_triggers(md, poke_d)
	_check(doomed.dead or doomed.health.hp <= 0,
		"(d) the first block killed the holder (hp %d, dead=%s)" % [doomed.health.hp, str(doomed.dead)])
	_check(applier.health.hp == ap_hp,
		"(d) THE CLAIM: the second block hit NOBODY — the applier took 0 (%d unchanged)" % applier.health.hp)

	# CONTROL: a LIVING holder takes BOTH blocks, so the assertion above can fail.
	ap_hp = applier.health.hp
	var s_hp: int = survivor.health.hp
	survivor.check_ability_receive_triggers(md, poke_d)
	_check(survivor.health.hp == s_hp - 55,
		"(d) CONTROL: a LIVING holder takes BOTH blocks (%d -> %d, -55)" % [s_hp, survivor.health.hp])
	_check(applier.health.hp == ap_hp,
		"(d) ...and the applier still takes nothing (%d unchanged)" % applier.health.hp)

	print("=== independent verify done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
