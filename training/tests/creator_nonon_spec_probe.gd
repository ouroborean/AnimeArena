extends Node

# ============================================================================
# CREATOR ROULETTE 11 — NONON JAKUZURE, the create-ability PROOF.
#
# Proves — through the REAL AuthoredRegistry (validate on save AND on load), a
# REAL AuthoredCharacter build, and a REAL headless battle — that Nonon's entire
# shipped kit (character/nonon.gd + abilities/nonon{1..5}.gd) can be authored as
# block-tree JSON with FULL fidelity: GAP 1 (typed vulnerability) and GAP 2 (nonon3's
# conditional invuln TARGETING reach) are both closed — the latter by `bypass_when`.
#
#   godot --headless --path <repo> res://training/tests/creator_nonon_spec_probe.tscn
#
# Per-skill, asserted below:
#   nonon1 "Flute Missile"          — 10 PIERCING + the NEW damage-type-FILTERED
#                                     vulnerability (+5 to every NON-Affliction hit).
#   nonon2 "Overture Barrage"       — AoE 5 PIERCING now + AoE 5-PIERCING DoT +
#                                     AoE "Overture Barrage" MARK + self-swap.
#   nonon3 "Concentrated Climax"    — channel:"control"; 10 NORMAL + DoT +
#                                     "Concentrated Climax" MARK, all applied
#                                     BYPASSING iff the target carries Overture
#                                     Barrage (group-branch on has_effect); swap.
#   nonon4 "Sound Negation"         — self-invulnerable 1 turn.
#   nonon5 "Unstoppable Performance"— 10 to main + 10 to each Overture-marked +
#                                     10 to each Climax-marked (double-marked main -> 30).
#
# THE SWAP CHAIN — followed from the CODE, not the brief. The shipped scripts are
# unambiguous: nonon2 = ability_swap_effect(4, 1, ...) and nonon3 =
# ability_swap_effect(4, 2, ...). base_abilities is [nonon1,nonon2,nonon3,nonon4,
# nonon5] (Movesets.from_skill_count), so index 4 is Unstoppable Performance in
# BOTH. i.e. Overture Barrage and Concentrated Climax EACH replace THEIR OWN board
# slot with Unstoppable Performance — they do NOT chain 2->3->5. The roulette brief
# says "nonon2 swaps to nonon3", but the HONESTY rule is "cite the actual entry,
# never assume": the code wins, and the discrepancy is reported in `reversals`.
#
# GAP 1 (the palette gap this run closed) — nonon1's damage-type-filtered
# vulnerability {amount:5, exclude_types:["AFFLICTION"]}. Built in the prior stage;
# re-proven here inside the full character (sections 3).
#
# GAP 2 (CLOSED by bypass_when) — nonon3's shipped target() bypasses invulnerability
# PER CANDIDATE (bypass = marked_by "Overture Barrage"). Creator Layer-1 used to compute
# bypass ONCE for the whole ability, so it could only be all-or-nothing. The `bypass_when`
# CONDITION on the target object now computes the bypass per candidate through the same
# check_condition_public the `only` predicates use, so nonon3's target carries
# bypass_when {has_effect "Overture Barrage", MARK, mine} and is byte-faithful: section 6c
# proves it reaches the marked-invuln combo target and REFUSES an unmarked-invuln one. The
# EXECUTE half was already faithful (section 6a/6b: the group bypasses a marked-invuln
# target and NOT an unmarked one). Both halves now match the shipped kit.
# ============================================================================

const CHAR_ID := "auth_zz_nonon_roulette"
const AUTHOR := "ZZ_NONON_ROULETTE_11"

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

# ---------------------------------------------------------------------------
# THE SPEC — the whole authored Nonon, as one validated JSON object.
# Costs / cooldowns / classes / targets copied from abilities_data.json's nonon1..5
# (Blue == energy index 3, Random == index 4).
# ---------------------------------------------------------------------------
func _spec() -> Dictionary:
	return {
		"id": CHAR_ID,
		"name": "Nonon Jakuzure",
		"author": AUTHOR,
		"status": "testing",
		"colors": [3],  # BLUE — character_colors=[3] in character/nonon.gd (draft hint only)
		"description": "Nonon Jakuzure, Elite Four of Honnoji Academy. Her uniform is a gigantic LRAD that launches musical barrages.",
		"abilities": [
			# --- nonon1 "Flute Missile" — 10 PIERCING + typed vulnerability -----------------------
			# vulnerability_effect(5, 4, [], [], [AFFLICTION]) == amount:5, exclude_types:[AFFLICTION],
			# turns:2 (2N -> raw 4). The mark/DoT-free rider lands on whoever the damage block hit.
			{"name": "Flute Missile", "target": "enemy", "cooldown": 1, "cost": {"4": 1},
			 "classes": ["Harmful", "Instant", "Physical", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "damage", "to": "target", "amount": 10, "damage_type": "PIERCING"},
				{"op": "apply", "to": "target", "effect": {
					"kind": "vulnerability", "amount": 5, "exclude_types": ["AFFLICTION"], "turns": 2}}]},
			# --- nonon2 "Overture Barrage" — AoE hit + AoE DoT + AoE MARK + self-swap --------------
			# Immediate 5 (the manual first instance) + damage_over_time ticks:5 (raw 5 == the shipped
			# damage_effect(5,PIERCING,5)) + mark ticks:5 (raw 5) — the mark INHERITS the ability name
			# "Overture Barrage" (effect_name fallback), which is the exact string nonon3/nonon5 read.
			# swap slot:1 (this skill's board slot) into:4 (Unstoppable Performance, hidden idx 4).
			{"name": "Overture Barrage", "target": "all_enemies", "cooldown": 2, "cost": {"3": 1},
			 "classes": ["Harmful", "Instant", "Physical", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "damage", "to": "all_enemies", "amount": 5, "damage_type": "PIERCING"},
				{"op": "apply", "to": "all_enemies", "effect": {
					"kind": "damage_over_time", "amount": 5, "damage_type": "PIERCING", "ticks": 5}},
				{"op": "apply", "to": "all_enemies", "effect": {
					"kind": "mark", "ticks": 5,
					"text": "Auto-targeted by Unstoppable Performance; Concentrated Climax Bypasses against this target."}},
				{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 1, "into": 4, "ticks": 5}}]},
			# --- nonon3 "Concentrated Climax" — channelled; conditional-bypass; self-swap ----------
			# channel:"control" plants a control_cancel over EVERYTHING applied (DoT + mark + swap),
			# matching the shipped cancels list; the "Control" class is DERIVED from it, not typed.
			# The immediate 10 NORMAL is NOT bypassing (resolve_damage has no bypass param — invuln
			# still blocks it, exactly as shipped). The DoT + mark branch on has_effect("Overture
			# Barrage", MARK, mine) on the target: bypassing:true when marked, plain when not.
			# The mark INHERITS the ability name "Concentrated Climax" (nonon5's second selector).
			# target object with bypass_when {has_effect "Overture Barrage", MARK, mine} — the GAP-2
			# per-candidate bypass, now BYTE-FAITHFUL to the shipped target() (section 6c): it reaches a
			# marked-invuln enemy and refuses an unmarked one, exactly as `bypass = marked_by(...)` does.
			{"name": "Concentrated Climax", "cooldown": 1, "cost": {"3": 1},
			 "classes": ["Harmful", "Physical", "Damaging"], "channel": "control",
			 "target": {"mode": "enemy", "bypass_when":
				{"cond": "has_effect", "name": "Overture Barrage", "effect": "MARK", "by": "mine"}}, "requires": [],
			 "blocks": [
				{"op": "damage", "to": "target", "amount": 10, "damage_type": "NORMAL"},
				{"op": "group",
				 "when": {"cond": "has_effect", "name": "Overture Barrage", "effect": "MARK", "by": "mine", "on": "target"},
				 "blocks": [
					{"op": "apply", "to": "target", "bypassing": true, "effect": {
						"kind": "damage_over_time", "amount": 10, "damage_type": "NORMAL", "ticks": 5}},
					{"op": "apply", "to": "target", "bypassing": true, "effect": {
						"kind": "mark", "ticks": 5, "text": "Auto-targeted by Unstoppable Performance."}}],
				 "else": [
					{"op": "apply", "to": "target", "effect": {
						"kind": "damage_over_time", "amount": 10, "damage_type": "NORMAL", "ticks": 5}},
					{"op": "apply", "to": "target", "effect": {
						"kind": "mark", "ticks": 5, "text": "Auto-targeted by Unstoppable Performance."}}]},
				{"op": "apply", "to": "user", "effect": {"kind": "swap", "slot": 2, "into": 4, "ticks": 5}}]},
			# --- nonon4 "Sound Negation" — self-invulnerable 1 turn -------------------------------
			# default_defend == invuln_effect(2) == turns:1.
			{"name": "Sound Negation", "target": "self", "cooldown": 4, "cost": {"4": 1},
			 "classes": ["Instant", "Strategic", "Energy"], "requires": [],
			 "blocks": [{"op": "apply", "to": "user", "effect": {"kind": "invulnerable", "turns": 1}}]},
			# --- nonon5 "Unstoppable Performance" — HIDDEN swap-in finisher ------------------------
			# to:"target" is the single clicked enemy (this is a single-target skill, so targeter.targets
			# == [main]); 10 to EACH enemy marked "Overture Barrage"; 10 to EACH enemy
			# marked "Concentrated Climax". any_enemy == "every living enemy the condition holds for"
			# (its own pool re-runs the invuln gate with the ability's non-Bypassing default, so an
			# invuln enemy is dropped — identical net to shipped resolve_damage's invuln no-op). A
			# double-marked main takes 10+10+10 = 30.
			{"name": "Unstoppable Performance", "hidden": true, "target": "enemy", "cooldown": 0, "cost": {"3": 1},
			 "classes": ["Harmful", "Instant", "Physical", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "damage", "to": "target", "amount": 10, "damage_type": "PIERCING"},
				{"op": "damage", "to": "any_enemy", "amount": 10, "damage_type": "PIERCING",
				 "when": {"cond": "has_effect", "name": "Overture Barrage", "effect": "MARK", "by": "mine"}},
				{"op": "damage", "to": "any_enemy", "amount": 10, "damage_type": "PIERCING",
				 "when": {"cond": "has_effect", "name": "Concentrated Climax", "effect": "MARK", "by": "mine"}}]},
		],
	}

# --- battle scaffolding (mirrors creator_saitama_spec_probe) ----------------
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
	m.start_battle(p1, p2, true, 1111, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _cast(caster, ab, targets: Array, m) -> void:
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

func _make_invuln(m, ch) -> void:
	var ctx = QueryContext.from_game_state(ch, m)
	var iv = Effect.invuln_effect(2)
	iv.set_source(ch.moveset.base_abilities[0])
	Character.add_allied_effect(ctx, ch, ch, iv, true)

# Plant a MARK on `victim` whose name INHERITS `source_ability`'s name (effect_name fallback),
# by `hero` — so has_effect(name, MARK, mine) reads it exactly as a real Nonon cast would.
func _plant_mark(m, hero, victim, source_ability) -> void:
	var ctx = QueryContext.from_game_state(hero, m)
	var mk = Effect.mark(10, "probe-planted mark")
	mk.set_source(source_ability)
	Character.add_hostile_effect(ctx, hero, victim, mk)

func _dealt(damager, target, ab, base, dtype) -> int:
	damager.used_ability = ab
	var r: int = ab.get_true_damage(damager, target, base, null, dtype)
	damager.used_ability = null
	return r

func _has_mark(ch, name, by) -> bool:
	return ch.has_effect(name, EffectType.Type.MARK, by) != null

func _write_fixture(spec: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://authored"))
	var f := FileAccess.open("res://authored/%s.json" % CHAR_ID, FileAccess.WRITE)
	if f == null:
		printerr("  could not write the probe fixture"); return
	f.store_string(JSON.stringify(spec, "\t"))
	f.close()

func _ready():
	print("=== CREATOR ROULETTE 11 — Nonon Jakuzure authored spec ===")
	var spec := _spec()

	# ------------------------------------------------------------------
	# 1. VALIDATE through the REAL AuthoredRegistry (save AND load re-validate).
	# ------------------------------------------------------------------
	var direct_errs := AuthoredRegistry.validate_character(spec)
	_check(direct_errs.is_empty(), "validate_character() returns 0 errors: %s" % str(direct_errs))

	_write_fixture(spec)
	AuthoredRegistry.load_all(true)
	var loaded = AuthoredRegistry.get_spec(CHAR_ID)
	_check(loaded != null, "spec loaded from disk (passed validate-on-load)")
	if loaded == null:
		print("=== DONE: %d failure(s) ===" % fails); get_tree().quit(1); return
	_check(AuthoredRegistry.validate_character(loaded).is_empty(), "re-validates cleanly after round-trip")

	# ------------------------------------------------------------------
	# 2. BUILD a real Character (no .gd/.tscn) and confirm the moveset shape.
	# ------------------------------------------------------------------
	var s := _fresh_battle(); var m = s["m"]
	var hero = s["allies"][0]
	_check(hero is AuthoredCharacter, "Character.from_character_name built an AuthoredCharacter")
	_check(hero.character_name == "Nonon Jakuzure", "name applied: %s" % hero.character_name)
	var kit = hero.moveset.base_abilities
	_check(kit.size() == 5, "5 abilities built (%d)" % kit.size())
	_check(kit[0].ability_name == "Flute Missile" and kit[1].ability_name == "Overture Barrage"
		and kit[2].ability_name == "Concentrated Climax" and kit[3].ability_name == "Sound Negation"
		and kit[4].ability_name == "Unstoppable Performance",
		"moveset order [n1,n2,n3,n4,n5] — swap into:4 == Unstoppable Performance")
	_check(hero.moveset.display_abilities().size() == 4, "exactly 4 visible board slots (nonon5 hidden, off-board)")
	var n1 = kit[0]; var n2 = kit[1]; var n3 = kit[2]; var n4 = kit[3]; var n5 = kit[4]

	# ------------------------------------------------------------------
	# 3. nonon1 — 10 PIERCING + the typed vulnerability (+5 non-Affliction).
	# ------------------------------------------------------------------
	print("-- nonon1: Flute Missile --")
	var foe = s["foes"][0]
	var hp0: int = int(foe.health.hp)
	_cast(hero, n1, [foe], m)
	_check(int(foe.health.hp) == hp0 - 10, "Flute Missile dealt 10 PIERCING (%d -> %d)" % [hp0, foe.health.hp])
	var v = foe.has_effect("Flute Missile", EffectType.Type.VULNERABILITY, hero)
	_check(v != null, "a VULNERABILITY (named 'Flute Missile') landed on the target")
	_check(v != null and v.mag == 5, "vulnerability magnitude is +5 (unsigned)")
	_check(v != null and v.exclusion_targets == [DamageType.Type.AFFLICTION],
		"exclude_types ['AFFLICTION'] -> exclusion_targets [AFFLICTION] (got %s)" % (str(v.exclusion_targets) if v else "null"))
	var normal_hit := _dealt(hero, foe, n1, 20, DamageType.Type.NORMAL)
	var affl_hit := _dealt(hero, foe, n1, 20, DamageType.Type.AFFLICTION)
	_check(normal_hit == 25, "a follow-up 20 NORMAL hit is raised to 25 (vulnerable)")
	_check(affl_hit == 20, "a follow-up 20 AFFLICTION hit is UNCHANGED (the excluded type is spared)")

	# ------------------------------------------------------------------
	# 4. nonon2 — AoE 5 now + AoE 5-PIERCING DoT + AoE "Overture Barrage" MARK + self-swap.
	# ------------------------------------------------------------------
	print("-- nonon2: Overture Barrage --")
	var foes = s["foes"]
	var pre := {}
	for f2 in foes: pre[f2] = int(f2.health.hp)
	_cast(hero, n2, foes.duplicate(), m)
	var all_marked := true; var all_dot := true
	for f2 in foes:
		if not _has_mark(f2, "Overture Barrage", hero): all_marked = false
		if f2.has_effect("Overture Barrage", EffectType.Type.DAMAGE, hero) == null: all_dot = false
	# foes[0] still carries nonon1's vulnerability (+5 to non-Affliction), so its 5 PIERCING becomes
	# 10 — a real cross-skill interaction, not an error. The two clean enemies take exactly 5.
	_check(int(foes[0].health.hp) == int(pre[foes[0]]) - 10,
		"Overture Barrage's 5 PIERCING became 10 on the still-vulnerable nonon1 target (cross-skill)")
	var clean_hit := int(foes[1].health.hp) == int(pre[foes[1]]) - 5 and int(foes[2].health.hp) == int(pre[foes[2]]) - 5
	_check(clean_hit, "Overture Barrage dealt 5 immediately to the two clean enemies (the manual first instance)")
	_check(all_marked, "EVERY enemy carries the 'Overture Barrage' MARK (name inherited from the ability)")
	_check(all_dot, "EVERY enemy carries a 5-PIERCING DoT (DAMAGE effect, name 'Overture Barrage')")
	_check(hero.get_ability_swap_effects().size() == 1, "self ability_swap applied")
	var board = hero.moveset.get_active_abilities(hero)
	_check(board.size() >= 2 and board[1].ability_name == "Unstoppable Performance",
		"board slot 1 (Overture Barrage) is now Unstoppable Performance (swap 1->4)")

	# ------------------------------------------------------------------
	# 5. nonon4 — self-invulnerable 1 turn (done before the invuln-bypass tests).
	# ------------------------------------------------------------------
	print("-- nonon4: Sound Negation --")
	_check(not hero.is_ignoring_damage(true), "(setup) hero is not invulnerable yet")
	_cast(hero, n4, [hero], m)
	_check(hero.effects.get_effects_by_type(EffectType.Type.INVULN).size() == 1, "Sound Negation made Nonon INVULNERABLE")

	# ------------------------------------------------------------------
	# 6. nonon3 — the conditional-bypass EXECUTE half + the channel + GAP 2 (targeting).
	# ------------------------------------------------------------------
	print("-- nonon3: Concentrated Climax (EXECUTE-half conditional bypass) --")
	# Fresh battle so the two invuln enemies' marks are controlled EXACTLY: one Overture-marked, one
	# genuinely unmarked. (In the main battle nonon2 marked all three.)
	var s3 := _fresh_battle(); var m3 = s3["m"]
	var hero3 = s3["allies"][0]; var foes3 = s3["foes"]
	var n2c = hero3.moveset.base_abilities[1]   # Overture Barrage — the mark source
	var n3c = hero3.moveset.base_abilities[2]   # Concentrated Climax — the ability under test
	var marked_foe = foes3[0]
	var clean_foe = foes3[1]
	_plant_mark(m3, hero3, marked_foe, n2c)     # Overture Barrage MARK on the combo target only
	_make_invuln(m3, marked_foe)
	_make_invuln(m3, clean_foe)

	# 6a. MARKED + INVULN: the group's `when` is true -> DoT+mark applied BYPASSING invulnerability.
	_check(marked_foe.is_invuln() and _has_mark(marked_foe, "Overture Barrage", hero3),
		"(setup) marked_foe is Overture-marked AND invulnerable")
	_cast(hero3, n3c, [marked_foe], m3)
	# The DoT is the TRUE discriminator: add_hostile_effect gates a DAMAGE effect on invulnerability
	# (can_apply_hostile_effect appends the invuln check unless bypassing), so its landing on an invuln
	# target PROVES the bypass fired. (The MARK is a neutral tag the engine never invuln-gates — it
	# lands either way, in the authored kit AND the shipped one — so it is not itself proof of bypass.)
	_check(marked_foe.has_effect("Concentrated Climax", EffectType.Type.DAMAGE, hero3) != null,
		"BYPASS: the 10-NORMAL DoT landed on the marked-invuln enemy (through invuln — the group's true arm)")
	_check(_has_mark(marked_foe, "Concentrated Climax", hero3),
		"...and the 'Concentrated Climax' MARK is present (marks are not invuln-gated, as in the shipped kit)")
	_check(hero3.effects.get_effects_by_type(EffectType.Type.CONTROL_CANCEL).size() >= 1,
		"channel:'control' planted a CONTROL_CANCEL over the cast")

	# 6b. UNMARKED + INVULN: the group's `when` is false -> the else arm is non-bypassing, so the
	# DoT is BLOCKED by invulnerability (the mark, being un-gated, still lands — same as shipped).
	print("-- nonon3: else arm does NOT bypass an unmarked target --")
	_check(clean_foe.is_invuln() and not _has_mark(clean_foe, "Overture Barrage", hero3),
		"(setup) clean_foe is invulnerable and NOT Overture-marked")
	_cast(hero3, n3c, [clean_foe], m3)
	_check(clean_foe.has_effect("Concentrated Climax", EffectType.Type.DAMAGE, hero3) == null,
		"NO-BYPASS: the 10-NORMAL DoT was BLOCKED by invulnerability (unmarked -> non-bypassing else arm)")

	# 6c. GAP 2 CLOSED — the TARGETING reach is now BYTE-FAITHFUL to the shipped target(). nonon3's
	# target carries bypass_when {has_effect "Overture Barrage", MARK, mine}, so the bypass is computed
	# PER CANDIDATE exactly as `bypass = character.marked_by("Overture Barrage", user)` does: it reaches
	# the marked-invuln combo target and REFUSES an unmarked-invuln one. This assertion recorded the
	# GAP-2 loss (the over-reach wrongly flagged the unmarked enemy); it now flips to the faithful refusal.
	print("-- nonon3: GAP 2 CLOSED (per-candidate bypass_when == the shipped target) --")
	for c in m3.all_characters(): c.targeted = false
	n3c.target(hero3, m3)
	_check(marked_foe.targeted, "REACH: nonon3 targets the marked-invuln combo enemy (bypass_when fired)")
	_check(not clean_foe.targeted,
		"BYTE-FAITHFUL: nonon3 REFUSES an unmarked invuln enemy — the shipped per-candidate mark-gated "
		+ "bypass is now expressible, so the old GAP-2 over-reach is gone")
	_check(foes3[2].targeted, "CONTROL: nonon3 still targets a non-invuln enemy (the bypass is additive)")

	# ------------------------------------------------------------------
	# 7. nonon5 — 10 to main + 10 per Overture-marked + 10 per Climax-marked (double-marked main -> 30).
	#    Fresh battle so the mark setup is exact and hp is uncapped.
	# ------------------------------------------------------------------
	print("-- nonon5: Unstoppable Performance --")
	var s2 := _fresh_battle(); var m2 = s2["m"]
	var hero2 = s2["allies"][0]; var foes2 = s2["foes"]
	var n2b = hero2.moveset.base_abilities[1]   # Overture Barrage (mark source)
	var n3b = hero2.moveset.base_abilities[2]   # Concentrated Climax (mark source)
	var n5b = hero2.moveset.base_abilities[4]   # Unstoppable Performance
	for f2 in foes2:
		f2.health.max_hp = 9999; f2.health.hp = 9999
	var main = foes2[0]      # main + double-marked -> 30
	var side = foes2[1]      # Overture-marked only -> 10
	var bystander = foes2[2] # unmarked, not main -> 0
	_plant_mark(m2, hero2, main, n2b)   # Overture Barrage
	_plant_mark(m2, hero2, main, n3b)   # Concentrated Climax
	_plant_mark(m2, hero2, side, n2b)   # Overture Barrage
	var mh := int(main.health.hp); var sh := int(side.health.hp); var bh := int(bystander.health.hp)
	_cast(hero2, n5b, [main], m2)
	_check(mh - int(main.health.hp) == 30, "double-marked MAIN took 30 (10 main + 10 Overture + 10 Climax), got %d" % (mh - int(main.health.hp)))
	_check(sh - int(side.health.hp) == 10, "Overture-marked non-main took 10, got %d" % (sh - int(side.health.hp)))
	_check(bh - int(bystander.health.hp) == 0, "unmarked non-main took 0, got %d" % (bh - int(bystander.health.hp)))

	# ------------------------------------------------------------------
	# 8. Generated presentation — the authored kit describes itself.
	# ------------------------------------------------------------------
	print("-- generated prose --")
	print("        n1 -> " + str(n1.split_desc()))
	print("        n5 -> " + str(n5.split_desc()))
	var n1line := ""
	for seg in n1.split_desc():
		n1line += (str(seg[0]) if seg is Array else str(seg)) + " | "
	_check("non-Affliction" in n1line, "nonon1 prose reads the typed vulnerability as 'non-Affliction'")

	print("=== DONE: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
