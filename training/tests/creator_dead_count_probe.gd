extends Node

# ============================================================================
# CREATOR — the `dead_count` READING.
#
# dead_count counts the FALLEN members of the team named by `of` (saitama7's
# "+25 per dead ally"). It is the ONE reading that cannot be spelled with the
# live selection: every other read folds _resolve_targets, which DROPS the dead
# — the very population this counts. So the runner arm builds the roster straight
# (valid + dead + not banished, mirroring the dead_allies pool), and the
# validator restricts `of` to the three team pools (all_allies/other_allies/
# all_enemies): a dead-count over a single target could only answer 0 or 1.
#
#   godot --headless --path <repo> res://training/tests/creator_dead_count_probe.tscn
#
# HAND-REVERSAL (turns the K assertions red; quoted in the writeup):
#   * runner arm: in block_runner._count_dead, invert the membership test to
#     `not c.dead` (count the LIVING instead) => a 2-dead team reads 1 (the one
#     survivor of the 3-char roster) and the scaling amount yields 50+25*1=75,
#     not 100. Every dead_count assertion below flips.
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

func _fresh() -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _mk(spec: Dictionary, owner, harmful := true) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Authored Probe"))
	a.classes = {"Physical": harmful, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": not harmful, "Harmful": harmful, "Helpful": not harmful, "Instant": true,
		"Action": false, "Control": false, "Channeled": false, "Uncounterable": false,
		"Bypassing": false, "Stealthed": false, "Passive": false, "Preserves Channel": false,
		"Damaging": harmful}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _runner(caster, m) -> BlockRunner:
	var ab := _mk({"name": "Reader", "target": "enemy", "blocks": [{"op": "damage", "amount": 0}]}, caster)
	return BlockRunner.new(ab, m, caster)

func _ab_spec(blocks: Array) -> Dictionary:
	return {"name": "Probe", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Harmful", "Damaging"], "blocks": blocks, "requires": []}

func _has_err(errs: Array, needle: String) -> bool:
	for e in errs:
		if needle in str(e):
			return true
	return false

func _ready():
	print("=== CREATOR — dead_count reading ===")

	# self_check() stays green — READINGS grew by one member; the constant-vs-constant invariants must
	# not break.
	_check(BlockSchema.self_check().is_empty(), "self_check() is green after adding dead_count")
	_check("dead_count" in BlockSchema.READINGS, "dead_count is a member of the closed READINGS enum")

	# ==================================================================================
	# 1. RUNTIME — over a team with K dead members, dead_count resolves to K.
	# ==================================================================================
	var s = _fresh(); var m = s["m"]; var caster = s["allies"][0]
	var allies = s["allies"]; var foes = s["foes"]
	var r := _runner(caster, m)

	# other_allies excludes the caster. Start: 0 dead among the other two allies.
	_check(r._resolve_reading({"read": "dead_count", "of": "other_allies"}) == 0,
		"dead_count(other_allies) reads 0 with no fallen allies")
	# alive_count is the complement — a positive control that the roster is intact.
	_check(r._resolve_reading({"read": "alive_count", "of": "other_allies"}) == 2,
		"control: alive_count(other_allies) reads 2 living allies")

	# Kill one OTHER ally (allies[1]) -> K=1.
	allies[1].dead = true
	_check(r._resolve_reading({"read": "dead_count", "of": "other_allies"}) == 1,
		"dead_count(other_allies) reads 1 after one ally dies")
	# Kill the second other ally (allies[2]) -> K=2.
	allies[2].dead = true
	_check(r._resolve_reading({"read": "dead_count", "of": "other_allies"}) == 2,
		"dead_count(other_allies) reads 2 after both other allies die")
	# all_allies INCLUDES the caster; the caster is alive, so still 2.
	_check(r._resolve_reading({"read": "dead_count", "of": "all_allies"}) == 2,
		"dead_count(all_allies) reads 2 (living caster not counted among the dead)")
	# The caster itself dies -> all_allies=3, but other_allies stays 2 (excludes the caster).
	caster.dead = true
	_check(r._resolve_reading({"read": "dead_count", "of": "all_allies"}) == 3,
		"dead_count(all_allies) reads 3 once the caster also dies")
	_check(r._resolve_reading({"read": "dead_count", "of": "other_allies"}) == 2,
		"dead_count(other_allies) still reads 2 (the dead caster is excluded)")

	# BANISHED is not counted: a banished character is off the board, not merely dead. Revive-flag one
	# dead ally as banished and confirm the count drops by one.
	allies[1].banished = true
	_check(r._resolve_reading({"read": "dead_count", "of": "all_allies"}) == 2,
		"dead_count skips a banished member (3 dead, 1 banished -> 2)")
	allies[1].banished = false

	# The ENEMY team: kill two of three foes -> dead_count(all_enemies) = 2.
	foes[0].dead = true
	foes[1].dead = true
	_check(r._resolve_reading({"read": "dead_count", "of": "all_enemies"}) == 2,
		"dead_count(all_enemies) reads 2 fallen enemies")

	# ==================================================================================
	# 2. SCALING amount — {base:50, per:25, each:{read:dead_count, of:other_allies}} yields 50+25*K.
	#    This is saitama7's shape. K=2 dead other-allies -> 100.
	# ==================================================================================
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; allies = s["allies"]; foes = s["foes"]
	allies[1].dead = true
	allies[2].dead = true  # K=2 dead among the other allies
	# cap 150 sits ABOVE the resolved 100 so the cap does not clamp the payload — the assertion is on the
	# reading maths (50 + 25*K), not the cap. (saitama7's real ceiling scales with team size.)
	var scaling := {"base": 50, "per": 25, "cap": 150,
		"each": {"read": "dead_count", "of": "other_allies"}}
	# Round-trip: it must validate clean.
	var rt := BlockValidator.validate_ability(_ab_spec([{"op": "damage", "amount": scaling, "to": "target"}]))
	_check(rt.is_empty(), "saitama7-shape scaling amount validates clean: %s" % str(rt))
	# Raise the victim's HP well above 100 so 100 damage neither kills nor clamps the measured `dealt`.
	var victim = foes[1]
	victim.health.max_hp = 9999
	victim.health.hp = 9999
	var hp0: int = int(victim.health.hp)
	var dmg_ab := _mk({"name": "Omni Punch", "target": "enemy",
		"blocks": [{"op": "damage", "amount": scaling, "to": "target"}]}, caster)
	_cast(caster, dmg_ab, [victim], m)
	var dealt: int = hp0 - int(victim.health.hp)
	_check(dealt == 100, "scaling amount yields 50 + 25*2 = 100 — dealt %d" % dealt)
	# Bot hint scores a scaling amount at its CAP (never 0 — the classic revert-fails case): the scaling
	# path is live for scoring.
	_check(dmg_ab.bot_damage_hint() == 150, "bot_damage_hint scores the dead_count scaling at cap 150 — got %d" % dmg_ab.bot_damage_hint())

	# ==================================================================================
	# 3. VALIDATOR — `of` must name a team pool. of:target REJECTED, of:other_allies ACCEPTED.
	# ==================================================================================
	# NEGATIVE: of:target is a single selector -> rejected (a dead-count of one head lies).
	var neg := BlockValidator.validate_ability(_ab_spec([{"op": "damage",
		"amount": {"base": 50, "per": 25, "cap": 999, "each": {"read": "dead_count", "of": "target"}}, "to": "target"}]))
	_check(_has_err(neg, "team pool"), "ILLEGAL: dead_count of:target is rejected (must name a team pool) — %s" % str(neg))
	# NEGATIVE: of:user (also singular) -> rejected.
	var neg2 := BlockValidator.validate_ability(_ab_spec([{"op": "damage",
		"amount": {"base": 50, "per": 25, "cap": 999, "each": {"read": "dead_count", "of": "user"}}, "to": "target"}]))
	_check(_has_err(neg2, "team pool"), "ILLEGAL: dead_count of:user is rejected — %s" % str(neg2))
	# NEGATIVE: absent `of` (would default to a single head) -> rejected.
	var neg3 := BlockValidator.validate_ability(_ab_spec([{"op": "damage",
		"amount": {"base": 50, "per": 25, "cap": 999, "each": {"read": "dead_count"}}, "to": "target"}]))
	_check(_has_err(neg3, "team pool"), "ILLEGAL: dead_count with no `of` is rejected — %s" % str(neg3))
	# POSITIVE CONTROL: the SAME shape with of:other_allies validates clean, so the rejection is the
	# scope, not the read itself.
	var pos := BlockValidator.validate_ability(_ab_spec([{"op": "damage",
		"amount": {"base": 50, "per": 25, "cap": 999, "each": {"read": "dead_count", "of": "other_allies"}}, "to": "target"}]))
	_check(pos.is_empty(), "control: dead_count of:other_allies validates clean — %s" % str(pos))
	# POSITIVE: all_allies and all_enemies both accepted (the full team-pool set).
	var pos2 := BlockValidator.validate_ability(_ab_spec([{"op": "damage",
		"amount": {"base": 50, "per": 25, "cap": 999, "each": {"read": "dead_count", "of": "all_enemies"}}, "to": "target"}]))
	_check(pos2.is_empty(), "control: dead_count of:all_enemies validates clean — %s" % str(pos2))

	# ==================================================================================
	# 4. PROSE — the scaling tail reads "per dead ally" / "per dead enemy" naturally.
	# ==================================================================================
	var sa := ScriptedAbility.new()
	var ally_noun: String = sa._reading_noun({"read": "dead_count", "of": "other_allies"})
	var enemy_noun: String = sa._reading_noun({"read": "dead_count", "of": "all_enemies"})
	sa.free()
	_check(ally_noun == "dead ally", "prose: dead_count(other_allies) reads 'dead ally' — got '%s'" % ally_noun)
	_check(enemy_noun == "dead enemy", "prose: dead_count(all_enemies) reads 'dead enemy' — got '%s'" % enemy_noun)

	print("=== DONE: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
