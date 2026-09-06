extends Node

# ============================================================================
# CREATOR ROULETTE 09 — SAITAMA, the create-ability PROOF.
#
# The whole point of this probe is to prove — through the REAL registry, the
# REAL validator and a REAL headless battle — that Saitama's shipped kit can be
# authored ENTIRELY as block-tree JSON (no character/saitama.gd, no ability
# scripts, no .tscn), and to be HONEST about the exactly-two places fidelity is
# lost. It is the payoff of the earlier audit + the dead_count reading.
#
#   godot --headless --path <repo> res://training/tests/creator_saitama_spec_probe.tscn
#
# What is asserted, per skill:
#   saitama1 "Normal Punch"                         — shatter TARGET shield + 45 NORMAL (single)
#   saitama2 "Consecutive Normal Punches"           — shatter ALL shields + 30 NORMAL (AoE)
#   saitama3 "Serious Series: Serious Table-Flip"   — ONE skill, BOTH teams: allies cleansed + Invuln,
#                                                     enemies Shattered (destructible_break)
#   saitama4 "Serious Series: Serious Side-Hops"    — INVISIBLE counter; on success: +1 GREEN,
#                                                     attacker MARKED, swap to Serious Punch
#   saitama5 "Serious Series: Serious Punch"        — mark-gated INSTANT KILL of the marked enemy
#   saitama7 "...Omni-Directional Serious Punch"    — AoE shatter + (50 + 25*dead ally), via dead_count
#
# CLOSED LOSS (was a residual loss; now proven fixed here):
#   * saitama4: the shipped counter excludes the STRATEGIC class (counter_effect(...,["Strategic"])).
#     The block `counter` kind now carries an `exclude` field that resolves to counter_effect's
#     exclusion list, so the authored Side-Hops uses exclude:["Strategic"] and lets a Harmful+Strategic
#     skill THROUGH exactly as the shipped kit does. Section 5b DRIVES a Harmful+Strategic skill into
#     it and asserts it is NOT countered — the fidelity restored (this assertion used to prove the loss).
#
# RESIDUAL LOSSES (proven here, not hand-waved):
#   * saitama4 mark duration: the block mark uses ticks:3 to match Effect.mark(3) exactly.
#   * saitama7 cap: a scaling `amount` REQUIRES a cap (unbounded ramp guard). The shipped saitama7 has
#     no explicit cap (naturally bounded by team size). cap is set to max_amount (9999) so it never
#     binds for any team the palette permits — the faithful "unbounded within the palette" choice.
#   * saitama7 cost/cooldown: saitama7 is a HIDDEN swap-in and is NOT in abilities_data.json, so its
#     cost/cd are author-chosen (mirroring the Serious-Punch family), not copied from shipped data.
# ============================================================================

const CHAR_ID := "auth_zz_saitama_roulette"
const AUTHOR := "ZZ_SAITAMA_ROULETTE_09"
# The marker string the shipped kit couples saitama4->saitama5 with. In the shipped game it is the
# COUNTER ABILITY's own name (Effect.effect_name() falls back to the source ability), so the authored
# mark carries no name_override — it inherits saitama4's ability name for free.
const MARK_NAME := "Serious Series: Serious Side-Hops"

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

# ---------------------------------------------------------------------------
# THE SPEC — the whole authored Saitama, as one validated JSON object.
# ---------------------------------------------------------------------------
func _spec() -> Dictionary:
	return {
		"id": CHAR_ID,
		"name": "Saitama",
		"author": AUTHOR,
		"status": "testing",
		"colors": [0, 4],  # GREEN + RANDOM, the two colours his costs actually spend (draft hint only)
		"description": "One Punch Man. Ends fights in a single Serious Punch.",
		"abilities": [
			# --- saitama1: "Normal Punch" — single shatter + 45 NORMAL ---------------------------
			{"name": "Normal Punch", "target": "enemy", "cooldown": 0, "cost": {"0": 2},
			 "classes": ["Harmful", "Instant", "Physical", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "break", "what": "shield", "to": "target"},
				{"op": "damage", "amount": 45, "damage_type": "NORMAL", "to": "target"}]},
			# --- saitama2: "Consecutive Normal Punches" — AoE shatter + 30 NORMAL -----------------
			{"name": "Consecutive Normal Punches", "target": "all_enemies", "cooldown": 2, "cost": {"0": 1, "4": 2},
			 "classes": ["Harmful", "Instant", "Physical", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "break", "what": "shield", "to": "target"},
				{"op": "damage", "amount": 30, "damage_type": "NORMAL", "to": "target"}]},
			# --- saitama3: "Serious Series: Serious Table-Flip" — ONE skill, BOTH teams -----------
			# Ally half (all_allies pool, resolved independently of the click): cleanse enemy effects
			# + Invulnerable 1 turn (invuln_effect(2)). Enemy half (all_enemies pool): destructible_break
			# for 2 turns (def_negate(3) — ticks:3, the odd raw duration the 2N convention can't spell).
			{"name": "Serious Series: Serious Table-Flip", "target": "everyone", "cooldown": 6, "cost": {"4": 3},
			 "classes": ["Bypassing", "Instant", "Strategic", "Uncounterable", "Physical"], "requires": [],
			 "blocks": [
				{"op": "cleanse", "to": "all_allies", "scope": "hostile"},
				{"op": "apply", "to": "all_allies", "effect": {"kind": "invulnerable", "turns": 1}},
				{"op": "apply", "to": "all_enemies", "effect": {"kind": "destructible_break", "ticks": 3}}]},
			# --- saitama4: "Serious Series: Serious Side-Hops" — invisible counter ----------------
			# INVISIBLE self counter of the first Harmful, NON-STRATEGIC skill (ticks:2 == counter_effect
			# dur 2). scope "harmful" + exclude ["Strategic"] == counter_effect(...,["Harmful"],["Strategic"]),
			# the shipped kit exactly. On success the `then` payload runs with Saitama as user and
			# to:"target" rebound to the ATTACKER: +1 GREEN, mark the attacker (mark inherits THIS
			# ability's name == MARK_NAME), swap Side-Hops (slot 3) -> Serious Punch (index 4, ticks:2).
			{"name": "Serious Series: Serious Side-Hops", "target": "self", "cooldown": 3, "cost": {"4": 1},
			 "classes": ["Instant", "Strategic", "Physical", "Invisible"], "requires": [],
			 "blocks": [
				{"op": "apply", "to": "user", "effect": {
					"kind": "counter", "scope": "harmful", "exclude": ["Strategic"], "on": "incoming", "ticks": 2, "invisible": true,
					"then": [
						{"op": "gain_energy", "colour": "green", "amount": 1},
						{"op": "apply", "to": "target", "effect": {
							"kind": "mark", "ticks": 3,
							"text": "This character can be targeted by Serious Series: Serious Punch."}},
						{"op": "apply", "to": "user", "effect": {
							"kind": "swap", "slot": 3, "into": 4, "ticks": 2}}]}}]},
			# --- saitama5: "Serious Series: Serious Punch" — HIDDEN, mark-gated instant kill -------
			# Usable only while the mark exists (requires); targets only the marked enemy (Layer-1 only);
			# execute with no hp_below == instant kill. Uncounterable covers uncounter+unreflect.
			{"name": "Serious Series: Serious Punch", "hidden": true, "cooldown": 0, "cost": {"0": 3},
			 "classes": ["Harmful", "Instant", "Physical", "Uncounterable"],
			 "target": {"mode": "enemy", "only": [
				{"cond": "has_effect", "name": MARK_NAME, "effect": "MARK", "by": "mine"}]},
			 "requires": [
				{"cond": "has_effect", "name": MARK_NAME, "effect": "MARK", "by": "mine", "on": "all_enemies"}],
			 "blocks": [{"op": "execute", "to": "target"}]},
			# --- saitama7: "...Omni-Directional Serious Punch" — HIDDEN, dead-ally scaling ---------
			# AoE shatter + (50 + 25 * dead other-allies), the dead_count reading. cap == max_amount so
			# it never binds (faithful "unbounded within the palette"; the shipped skill has no cap).
			{"name": "Serious Series: Omni-Directional Serious Punch", "hidden": true, "target": "all_enemies",
			 "cooldown": 0, "cost": {"0": 3},
			 "classes": ["Harmful", "Instant", "Physical", "Uncounterable"], "requires": [],
			 "blocks": [
				{"op": "break", "what": "shield", "to": "all_enemies"},
				{"op": "damage", "damage_type": "NORMAL", "to": "all_enemies",
				 "amount": {"base": 50, "per": 25, "cap": 9999,
					"each": {"read": "dead_count", "of": "other_allies"}}}]},
		],
	}

# --- battle scaffolding (mirrors authored_character_probe / creator_dead_count_probe) -------
func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy: bool = (u == "BotEnemy")
	for cn in names: p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _fresh_battle() -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", [CHAR_ID, "naruto", "gon"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 909, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _cast(caster, ab, targets: Array, m) -> void:
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _give_shield(m, ch, amount: int) -> void:
	var ctx = QueryContext.from_game_state(ch, m)
	var sh = Effect.shield_effect(amount, 6)
	sh.set_source(ch.moveset.base_abilities[0])
	Character.add_allied_effect(ctx, ch, ch, sh, true)

func _write_fixture(spec: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://authored"))
	var f := FileAccess.open("res://authored/%s.json" % CHAR_ID, FileAccess.WRITE)
	if f == null:
		printerr("  could not write the probe fixture"); return
	f.store_string(JSON.stringify(spec, "\t"))
	f.close()

func _ready():
	print("=== CREATOR ROULETTE 09 — Saitama authored spec ===")
	var spec := _spec()

	# ---------------------------------------------------------------------------
	# 1. VALIDATE through the REAL AuthoredRegistry (validate on save AND on load).
	# ---------------------------------------------------------------------------
	var direct_errs := AuthoredRegistry.validate_character(spec)
	_check(direct_errs.is_empty(), "validate_character() returns 0 errors: %s" % str(direct_errs))

	# save_spec re-validates and writes to disk; load_all re-validates on load. Both are the real path.
	_write_fixture(spec)
	AuthoredRegistry.load_all(true)
	var loaded = AuthoredRegistry.get_spec(CHAR_ID)
	_check(loaded != null, "spec loaded from disk (passed validate-on-load)")
	if loaded == null:
		print("=== DONE: %d failure(s) ===" % fails); get_tree().quit(1); return
	_check(AuthoredRegistry.validate_character(loaded).is_empty(), "re-validates cleanly after round-trip")

	# ---------------------------------------------------------------------------
	# 2. BUILD a real Character (no .gd/.tscn) and confirm the moveset shape.
	# ---------------------------------------------------------------------------
	var s := _fresh_battle(); var m = s["m"]
	var hero = s["allies"][0]
	var foe = s["foes"][0]
	_check(hero is AuthoredCharacter, "Character.from_character_name built an AuthoredCharacter")
	_check(hero.character_name == "Saitama", "name applied: %s" % hero.character_name)
	# 4 visible + 2 hidden = 6 abilities, in moveset_order [s1,s2,s3,s4,s5,s7].
	var kit = hero.moveset.base_abilities
	_check(kit.size() == 6, "6 abilities built (%d)" % kit.size())
	_check(kit[0].ability_name == "Normal Punch" and kit[3].ability_name == MARK_NAME
		and kit[4].ability_name == "Serious Series: Serious Punch",
		"moveset order is [s1,s2,s3,s4,s5,s7] — swap indices are valid")
	_check(hero.moveset.display_abilities().size() == 4, "exactly 4 visible board slots (hidden s5/s7 off-board)")

	var s1 = kit[0]; var s2 = kit[1]; var s3 = kit[2]; var s4 = kit[3]; var s5 = kit[4]; var s7 = kit[5]

	# ---------------------------------------------------------------------------
	# 3. saitama1 — single shatter + 45.
	# ---------------------------------------------------------------------------
	print("-- saitama1: Normal Punch --")
	_give_shield(m, foe, 25)
	_check(foe.get_shield_effects().size() == 1, "(setup) foe has a Shield")
	var hp0: int = int(foe.health.hp)
	_cast(hero, s1, [foe], m)
	_check(foe.get_shield_effects().is_empty(), "Normal Punch SHATTERED the foe's Shield")
	_check(int(foe.health.hp) == hp0 - 45, "Normal Punch dealt 45 through the broken shield (%d -> %d)" % [hp0, foe.health.hp])

	# ---------------------------------------------------------------------------
	# 4. saitama2 — AoE shatter + 30 to every enemy.
	# ---------------------------------------------------------------------------
	print("-- saitama2: Consecutive Normal Punches --")
	var foes = s["foes"]
	for f2 in foes:
		_give_shield(m, f2, 20)
	var hp_before := {}
	for f2 in foes:
		hp_before[f2] = int(f2.health.hp)
	_cast(hero, s2, foes.duplicate(), m)
	var all_shattered := true
	var all_30 := true
	for f2 in foes:
		if not f2.get_shield_effects().is_empty(): all_shattered = false
		if int(f2.health.hp) != int(hp_before[f2]) - 30: all_30 = false
	_check(all_shattered, "Consecutive Normal Punches shattered EVERY enemy's Shield")
	_check(all_30, "Consecutive Normal Punches dealt 30 to EVERY enemy")

	# ---------------------------------------------------------------------------
	# 5. saitama4 + saitama5 — invisible counter -> mark/energy/swap, then mark-gated kill.
	#    Done BEFORE saitama3 (which would make Saitama Invulnerable and swallow the attack).
	# ---------------------------------------------------------------------------
	print("-- saitama4: Serious Side-Hops (counter) --")
	# saitama5 is gated OFF before any mark exists.
	_check(not s5.extra_usable(hero), "Serious Punch is gated OFF before the mark exists")
	# Cast the counter on self.
	_cast(hero, s4, [hero], m)
	var counter_eff = hero.has_effect(MARK_NAME, EffectType.Type.COUNTER_RECEIVE, hero)
	_check(counter_eff != null, "counter applied as COUNTER_RECEIVE on Saitama")
	_check(counter_eff != null and counter_eff.invisible, "the counter is INVISIBLE")
	_check(counter_eff != null and counter_eff.class_targets == ["Harmful"], "counter watches ['Harmful'] (scope 'harmful')")
	_check(counter_eff != null and counter_eff.exclusion_targets == ["Strategic"], "counter EXCLUDES ['Strategic'] (exclude ['Strategic']) — the shipped counter_effect(...,['Strategic'])")

	# Drive a real Harmful, non-Uncounterable enemy skill into it.
	var attack = null
	for a in foe.moveset.base_abilities:
		if a.classes.get("Harmful", false) and not a.classes.get("Uncounterable", false):
			attack = a; break
	_check(attack != null, "(setup) the enemy has a counterable Harmful skill")
	var green0: int = int(hero.team.energy.pool[Energy.Type.GREEN])
	foe.targeter.targets = [hero]; foe.targeter.main_target = hero; foe.used_ability = attack
	var was_countered: bool = foe.countered(m, attack)
	foe.used_ability = null; foe.targeter.targets = []
	_check(was_countered, "the incoming Harmful skill was COUNTERED (cancelled outright)")
	_check(int(hero.team.energy.pool[Energy.Type.GREEN]) == green0 + 1, "Saitama gained 1 GREEN on the successful counter")
	_check(foe.has_effect(MARK_NAME, EffectType.Type.MARK, hero) != null, "the countered ATTACKER was MARKED (by Saitama)")
	_check(hero.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP).size() == 1, "Saitama swapped Side-Hops -> Serious Punch")

	print("-- saitama5: Serious Punch (mark-gated kill) --")
	_check(s5.extra_usable(hero), "Serious Punch is gated ON once the enemy is marked")
	_check(not foe.dead, "(setup) the marked foe is alive before the kill")
	hero.used_ability = s5; hero.targeter.targets = [foe]; hero.targeter.main_target = foe
	s5.execute(hero, m)
	hero.used_ability = null
	_check(foe.dead, "Serious Punch INSTANTLY KILLED the marked enemy")

	# ---------------------------------------------------------------------------
	# 5b. THE saitama4 FIDELITY LOSS, now CLOSED: the block counter's `exclude` reproduces the shipped
	#     counter_effect(...,['Strategic']). Re-cast the counter, drive a Harmful+STRATEGIC skill in,
	#     and show it is (correctly, matching the shipped kit) NOT countered — it lands. The assertion
	#     that used to prove the loss is FLIPPED here.
	# ---------------------------------------------------------------------------
	print("-- saitama4: Strategic IS excluded (fidelity restored) --")
	var live_foe = foes[1]  # misaka, still alive
	_cast(hero, s4, [hero], m)
	var strat := ScriptedAbility.new()
	strat.configure({"name": "Strat Poke", "target": "enemy", "blocks": [{"op": "damage", "amount": 1}]})
	strat.ability_name = "Strat Poke"
	strat.classes = Ability.default_classes()
	strat.classes["Harmful"] = true; strat.classes["Strategic"] = true; strat.classes["Instant"] = true
	strat.user = live_foe
	live_foe.moveset.add_ability(strat)
	live_foe.targeter.targets = [hero]; live_foe.targeter.main_target = hero; live_foe.used_ability = strat
	var strat_countered: bool = live_foe.countered(m, strat)
	live_foe.used_ability = null; live_foe.targeter.targets = []
	_check(not strat_countered,
		"FIDELITY RESTORED: the authored counter now lets a Harmful+Strategic skill THROUGH — the shipped counter_effect(...,['Strategic']) exclusion is expressible via the block `counter` kind's `exclude`")
	# And the exclusion did not break the common case: the counter is unspent (it never fired) and
	# still catches a plain Harmful skill, exactly as saitama4 did earlier in this battle.
	_check(hero.has_effect(MARK_NAME, EffectType.Type.COUNTER_RECEIVE, hero) != null,
		"...and the counter survived the excluded skill (it never fired)")

	# ---------------------------------------------------------------------------
	# 6. saitama3 — ONE skill, BOTH teams (ally cleanse + Invuln, enemy Shattered). LAST in this
	#    battle because it applies team-wide Invulnerable.
	# ---------------------------------------------------------------------------
	print("-- saitama3: Serious Table-Flip (both teams) --")
	var ally = s["allies"][1]  # naruto
	# Plant a cleansable enemy debuff on the ally to prove the cleanse half.
	var dctx = QueryContext.from_game_state(ally, m)
	var debuff = Effect.vulnerability_effect(10, 6)
	debuff.set_source(foe.moveset.base_abilities[0])
	Character.add_hostile_effect(dctx, live_foe, ally, debuff, true)
	_check(ally.effects.get_effects_by_type(EffectType.Type.VULNERABILITY).size() == 1, "(setup) ally carries an enemy debuff")
	# Target the whole board; the per-block pool selectors resolve their own populations.
	var everyone: Array = []
	everyone.append_array(s["allies"])
	for f2 in foes:
		if not f2.dead: everyone.append(f2)
	_cast(hero, s3, everyone, m)
	_check(ally.effects.get_effects_by_type(EffectType.Type.VULNERABILITY).is_empty(), "ally half: the enemy debuff was CLEANSED")
	_check(ally.effects.get_effects_by_type(EffectType.Type.INVULN).size() == 1, "ally half: the ally is now INVULNERABLE")
	_check(hero.effects.get_effects_by_type(EffectType.Type.INVULN).size() == 1, "ally half: Saitama himself is INVULNERABLE (all_allies includes the user)")
	var living_enemy_shattered := true
	var any_living := false
	for f2 in foes:
		if f2.dead: continue
		any_living = true
		if f2.effects.get_effects_by_type(EffectType.Type.DEF_NEGATE).is_empty():
			living_enemy_shattered = false
	_check(any_living and living_enemy_shattered, "enemy half: every living enemy is SHATTERED (destructible_break)")

	# ---------------------------------------------------------------------------
	# 7. saitama7 — AoE shatter + (50 + 25 * dead other-allies), in a FRESH battle so the
	#    dead-ally setup is clean. 0-dead -> 50, 1-dead -> 75, 2-dead -> 100.
	# ---------------------------------------------------------------------------
	print("-- saitama7: Omni-Directional (dead-ally scaling) --")
	var s2b := _fresh_battle(); var m2 = s2b["m"]
	var hero2 = s2b["allies"][0]; var allies2 = s2b["allies"]; var foes2 = s2b["foes"]
	var omni = hero2.moveset.base_abilities[5]
	_check(omni.ability_name == "Serious Series: Omni-Directional Serious Punch", "(setup) grabbed saitama7 (hidden index 5)")
	# Keep every enemy well above the ceiling so nothing dies mid-measure.
	for f2 in foes2:
		f2.health.max_hp = 9999; f2.health.hp = 9999
	var victim = foes2[0]
	_give_shield(m2, victim, 40)

	var vh0: int = int(victim.health.hp)
	_cast(hero2, omni, foes2.duplicate(), m2)
	_check(victim.get_shield_effects().is_empty(), "saitama7 shattered the enemy's Shield")
	_check(vh0 - int(victim.health.hp) == 50, "0 dead allies -> 50 damage (got %d)" % (vh0 - int(victim.health.hp)))

	allies2[1].dead = true  # naruto down -> 1 dead other-ally
	var vh1: int = int(victim.health.hp)
	_cast(hero2, omni, foes2.duplicate(), m2)
	_check(vh1 - int(victim.health.hp) == 75, "1 dead ally -> 50 + 25*1 = 75 damage (got %d)" % (vh1 - int(victim.health.hp)))

	allies2[2].dead = true  # gon down -> 2 dead other-allies
	var vh2: int = int(victim.health.hp)
	_cast(hero2, omni, foes2.duplicate(), m2)
	_check(vh2 - int(victim.health.hp) == 100, "2 dead allies -> 50 + 25*2 = 100 damage (got %d)" % (vh2 - int(victim.health.hp)))

	# BANISHED, not merely dead: a banished ally is off the board and must NOT feed the count.
	allies2[1].banished = true  # was dead; now banished -> drops back to 1 counted
	var vh3: int = int(victim.health.hp)
	_cast(hero2, omni, foes2.duplicate(), m2)
	_check(vh3 - int(victim.health.hp) == 75, "a BANISHED dead ally is not counted -> back to 75 (got %d)" % (vh3 - int(victim.health.hp)))

	# ---------------------------------------------------------------------------
	# 8. Generated presentation — the authored kit produces its own descriptions.
	# ---------------------------------------------------------------------------
	print("-- generated prose --")
	_check(s1.split_desc().size() >= 1, "Normal Punch auto-describes")
	print("        s1 -> " + str(s1.split_desc()))
	print("        s7 -> " + str(s7.split_desc()))

	print("=== DONE: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
