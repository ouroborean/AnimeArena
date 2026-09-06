extends Node

# ============================================================================
# CREATOR RULING 3 — the `redirect` effect kind (DAMAGE_REDIRECT via a SELECTOR).
#
# A redirect moves `amount`% of every hit its holder takes to a character a Phase F
# SELECTOR chooses. The destination is authored as a selector OBJECT (pool x where x
# pick) — never a live Character — and is resolved AT REDIRECT TIME by a resolver
# closure the block layer builds, run from Character.check_damage_redirect. That is
# what lets "a random living ally" re-pick each hit, and what makes a destination that
# now resolves to a DEAD / absent character no-op the redirect (the hit lands normally)
# instead of black-holing it.
#
#   godot --headless --path <repo> res://training/tests/creator_redirect_probe.tscn
#
# HAND-REVERSALS (each turns exactly its section red; quoted in the writeup):
#   * DROP THE DEAD-ABSORBER GUARD: in Character.check_damage_redirect, delete the
#           `if absorber == null or ... or absorber.dead ...: continue` arm.
#           => section 3 (dead absorber) goes red: the holder is spared its slice while
#              the damage is dealt to a corpse — the black-hole the guard exists to stop.
#              Sections 1/2 (live absorber) stay green.
#   * NEUTER THE RESOLVER: in BlockRunner._build_redirect, make the resolver
#           `return null` always.
#           => section 1/2 go red (nothing absorbs; with the guard the holder just takes
#              the full hit), section 4 (validator) stays green.
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

# Plant a redirect on `holder` (applied to itself). `dest` is the destination selector object.
func _plant_redirect(holder, dest: Dictionary, pct: int, m) -> void:
	var ab := _mk({"name": "Guard", "target": "ally",
		"blocks": [{"op": "apply", "to": "user",
			"effect": {"kind": "redirect", "amount": pct, "destination": dest, "turns": 5}}]}, holder, false)
	_cast(holder, ab, [holder], m)

# A clean NORMAL hit for `amount` from `attacker` onto `victim`.
func _hit(attacker, victim, amount: int, m) -> void:
	var ab := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": amount, "to": "target"}]}, attacker)
	_cast(attacker, ab, [victim], m)

func _ab_spec(blocks: Array) -> Dictionary:
	return {"name": "Probe", "target": "ally", "cooldown": 0, "cost": {},
		"classes": ["Helpful"], "blocks": blocks, "requires": []}

func _has_err(errs: Array, needle: String) -> bool:
	for e in errs:
		if needle in str(e):
			return true
	return false

func _ready():
	seed(4242)   # global RNG floor for the live-match assertions (hard rule)
	print("=== CREATOR RULING 3 — redirect via selector ===")

	# self_check() stays green: EFFECT_KINDS grew by one NAMED kind that declares reserves.
	_check(BlockSchema.self_check().is_empty(), "self_check() is green after adding the redirect kind")
	_check(BlockSchema.EFFECT_KINDS.has("redirect"), "redirect is a member of EFFECT_KINDS")
	_check(BlockSchema.reserved_fields("redirect").get("mag", "") == "amount",
		"redirect reserves mag (written from the authored percentage), so a universal mag cannot clobber the fraction")

	# ==================================================================================
	# 1. RUNTIME — redirect 50% of a hit to a RANDOM LIVING ALLY. The holder takes the
	#    rest; exactly one other ally absorbs the slice.
	# ==================================================================================
	var s = _fresh(); var m = s["m"]
	var def = s["allies"][0]; var a1 = s["allies"][1]; var a2 = s["allies"][2]; var atk = s["foes"][0]
	for c in [def, a1, a2, atk]:
		c.health.max_hp = 200; c.health.hp = 200
	_plant_redirect(def, {"pool": "other_allies", "pick": "random", "count": 1}, 50, m)
	_hit(atk, def, 40, m)
	var def_loss: int = 200 - int(def.health.hp)
	var a1_loss: int = 200 - int(a1.health.hp)
	var a2_loss: int = 200 - int(a2.health.hp)
	_check(def_loss == 20, "holder takes the un-redirected half of a 40 hit (took %d)" % def_loss)
	_check(a1_loss + a2_loss == 20, "the redirected half (20) lands on the allies (a1=%d a2=%d)" % [a1_loss, a2_loss])
	_check((a1_loss == 20) != (a2_loss == 20), "exactly ONE random living ally absorbed it, not both")

	# ==================================================================================
	# 2. RUNTIME — a deterministic destination (lowest-HP other ally) + the % is honoured.
	#    Redirect 25% of an 80 hit -> holder takes 60, the lowest-HP ally takes 20.
	# ==================================================================================
	s = _fresh(); m = s["m"]
	def = s["allies"][0]; a1 = s["allies"][1]; a2 = s["allies"][2]; atk = s["foes"][0]
	for c in [def, a2, atk]:
		c.health.max_hp = 200; c.health.hp = 200
	a1.health.max_hp = 200; a1.health.hp = 30   # a1 is the clear lowest -> the absorber
	_plant_redirect(def, {"pool": "other_allies", "pick": "lowest", "measure": "hp"}, 25, m)
	_hit(atk, def, 80, m)
	_check(200 - int(def.health.hp) == 60, "25%% redirect: holder takes 60 of an 80 hit (took %d)" % (200 - int(def.health.hp)))
	_check(30 - int(a1.health.hp) == 20, "the lowest-HP ally absorbed the 20 slice (took %d)" % (30 - int(a1.health.hp)))
	_check(int(a2.health.hp) == 200, "the OTHER ally, not lowest, absorbed nothing")

	# --- 2b. NEGATIVE CONTROL: no redirect at all -> the holder eats the whole hit. ---
	s = _fresh(); m = s["m"]
	def = s["allies"][0]; a1 = s["allies"][1]; atk = s["foes"][0]
	for c in [def, a1, atk]:
		c.health.max_hp = 200; c.health.hp = 200
	_hit(atk, def, 40, m)
	_check(200 - int(def.health.hp) == 40 and int(a1.health.hp) == 200,
		"control: without a redirect the holder takes the full 40 and no ally is touched")

	# ==================================================================================
	# 3. RUNTIME — DEAD ABSORBER. A destination that resolves to a dead character must
	#    NO-OP the redirect: the hit lands FULLY on the holder, never black-holed.
	#    THE dead-absorber-guard revert-fails case (see header).
	# ==================================================================================
	s = _fresh(); m = s["m"]
	def = s["allies"][0]; a1 = s["allies"][1]; a2 = s["allies"][2]; atk = s["foes"][0]
	for c in [def, a2, atk]:
		c.health.max_hp = 200; c.health.hp = 200
	# Put a1 in the dead state directly: a genuine (revivable) corpse in the dead_allies pool. Done by
	# hand rather than by a lethal hit because some allies carry an on-death revive passive (gon's
	# Post-Mortem Nen) that would spare them — the test needs a reliably-dead absorber, not a fight.
	a1.health.max_hp = 200; a1.health.set_health(0); a1.dead = true
	_check(a1.dead and not a1.banished, "pre-req: a1 is a dead, non-banished corpse in the dead_allies pool")
	# Redirect onto the dead pool: the selector resolves to the corpse, and check_damage_redirect
	# rejects it (a dead absorber cannot swallow the hit).
	_plant_redirect(def, {"pool": "dead_allies", "pick": "random", "count": 1}, 50, m)
	_hit(atk, def, 40, m)
	_check(200 - int(def.health.hp) == 40,
		"dead absorber: the holder takes the FULL 40 (the redirect no-ops, not a black-hole) — took %d" % (200 - int(def.health.hp)))

	# --- 3b. EMPTY selector (nobody matches) also no-ops rather than black-holing. ---
	s = _fresh(); m = s["m"]
	def = s["allies"][0]; atk = s["foes"][0]
	def.health.max_hp = 200; def.health.hp = 200; atk.health.max_hp = 200; atk.health.hp = 200
	# where: HP above 9999 matches nobody -> the selector yields [] -> resolver returns null -> no-op.
	_plant_redirect(def, {"pool": "other_allies", "where": [{"cond": "compare", "value": {"read": "hp"}, "op": "gt", "than": 9999}]}, 50, m)
	_hit(atk, def, 40, m)
	_check(200 - int(def.health.hp) == 40, "empty selector: the holder takes the full 40 (no-op, no black-hole)")

	# ==================================================================================
	# 4. VALIDATOR — destination is a REQUIRED selector object; amount is a 0-100 percent;
	#    the reserved mag is refused. Every negative paired with a positive control.
	# ==================================================================================
	var ok := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "redirect", "amount": 50, "turns": 2,
			"destination": {"pool": "other_allies", "pick": "random", "count": 1}}}])
	_check(BlockValidator.validate_ability(ok).is_empty(), "POSITIVE: a well-formed redirect validates clean — %s" % str(BlockValidator.validate_ability(ok)))

	# NEGATIVE: no destination.
	var no_dest := _ab_spec([{"op": "apply", "to": "user", "effect": {"kind": "redirect", "amount": 50, "turns": 2}}])
	_check(_has_err(BlockValidator.validate_ability(no_dest), "destination"), "NEGATIVE: a redirect with no destination is rejected")

	# NEGATIVE: destination is a bare string, not a selector object.
	var str_dest := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "redirect", "amount": 50, "turns": 2, "destination": "random_ally"}}])
	_check(_has_err(BlockValidator.validate_ability(str_dest), "selector object"), "NEGATIVE: a string destination is rejected (must be a selector object)")

	# NEGATIVE: amount above 100% (would invert the maths).
	var over := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "redirect", "amount": 150, "turns": 2,
			"destination": {"pool": "other_allies", "pick": "random", "count": 1}}}])
	_check(_has_err(BlockValidator.validate_ability(over), "0-100"), "NEGATIVE: a redirect above 100%% is rejected as a maths-inversion")

	# NEGATIVE: a universal mag on a redirect (reserved from amount) is refused.
	var mag_set := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "redirect", "amount": 50, "mag": 3, "turns": 2,
			"destination": {"pool": "other_allies", "pick": "random", "count": 1}}}])
	_check(_has_err(BlockValidator.validate_ability(mag_set), "mag"), "NEGATIVE: a universal mag is refused (it is reserved, written from amount)")

	# NEGATIVE: the destination selector's OWN rules still apply (an unknown pool is rejected).
	var bad_pool := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "redirect", "amount": 50, "turns": 2, "destination": {"pool": "nonsense"}}}])
	_check(_has_err(BlockValidator.validate_ability(bad_pool), "pool"), "NEGATIVE: the destination reuses the selector-object validator (bad pool rejected)")

	# ==================================================================================
	# 5. Generated prose names the redirect (the card is the contract, not describe()).
	# ==================================================================================
	var prose_ab := _mk(ok, s["allies"][1])
	var joined := " ".join(prose_ab.split_desc())
	_check("redirected to" in joined and "50%" in joined, "generated prose names the fraction and the destination: '%s'" % joined)

	print("=== DONE: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
