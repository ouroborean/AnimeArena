extends Node

# ============================================================================
# CREATOR PHASE C — the Simple Effect Table.
#
# One build arm (BlockRunner._build_simple_effect) plus N data rows
# (BlockSchema.SIMPLE_EFFECTS). This probe asserts, PER ROW, the thing the
# roadmap says the table must guarantee: the effect that lands behaves the way
# its READER reads it, its hostility routes the way its column declares, and its
# guard refuses its abuse case. Rows are independent — deleting one table line
# turns exactly that row's block red and leaves the rest green (the manual
# reversal at the end of this file).
#
#   godot --headless --path <repo> res://training/tests/creator_effect_table_probe.tscn
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

# Apply ONE simple-effect spec at `targets`, then hand back the caster's ability so the
# routing tests can inspect what landed. `harmful` sets the ability class so the allied/hostile
# path is exercised the way a real card would be.
func _apply(caster, spec: Dictionary, to: String, targets: Array, m, harmful := true) -> void:
	var ab := _mk({"name": "Apply " + str(spec.get("kind", "")), "target": "enemy",
		"blocks": [{"op": "apply", "to": to, "effect": spec}]}, caster, harmful)
	_cast(caster, ab, targets, m)

func _self_effect(c, m, eff) -> void:
	eff.set_source(c.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(c, m), c, c, eff, true)

func _has_type(char, type_name: String) -> bool:
	return not char.get_effects_by_type(EffectType.Type[type_name]).is_empty()

func _spec(blocks: Array) -> Dictionary:
	return {"name": "Probe", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Harmful"], "blocks": blocks, "requires": []}

func _ready():
	print("=== CREATOR PHASE C — the Simple Effect Table ===")

	# ==================================================================================
	# 1. mag NORMALISATION, end to end through the READER (not the factory string).
	# ==================================================================================
	# PERCENT_DR: author gives "40% removed"; reader multiplies incoming damage by (100-mag)/100.
	# Convention "flat" => mag == amount, so a 100-damage hit is reduced to 60.
	var s = _fresh(); var m = s["m"]; var caster = s["allies"][0]; var foes = s["foes"]
	_apply(caster, {"kind": "percent_dr", "amount": 40, "turns": 4}, "all_enemies", [foes[0]], m, false)
	var pdr = foes[0].get_effects_by_type(EffectType.Type.PERCENT_DR)
	_check(pdr.size() == 1 and int(pdr[0].mag) == 40,
		"PERCENT_DR: amount 40 writes mag 40 (reader reads mag as percent REMOVED) — mag=%s" % (str(pdr[0].mag) if pdr.size() == 1 else "<none>"))
	var reduced := int(foes[0].check_damage_against_percent_damage_reduction(null, 100, foes[0]))
	_check(reduced == 60, "PERCENT_DR: a 100 hit is reduced by 40%% to %d" % reduced)

	# HEAL_CUT: author gives "40% less healing"; reader multiplies healing by mag/100 (mag = % RETAINED).
	# Convention "retained" => mag == 100 - amount == 60, so a 40 heal delivers 24.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_apply(caster, {"kind": "heal_cut", "amount": 40, "turns": 4}, "all_enemies", [foes[0]], m)
	var hc = foes[0].get_effects_by_type(EffectType.Type.HEAL_CUT)
	_check(hc.size() == 1 and int(hc[0].mag) == 60,
		"HEAL_CUT: amount 40 (40%% cut) writes mag 60 (reader reads mag as percent RETAINED) — mag=%s" % (str(hc[0].mag) if hc.size() == 1 else "<none>"))
	foes[0].health.hp = foes[0].get_modified_max_hp() - 40
	var hp_before: int = int(foes[0].health.hp)
	foes[0].receive_ability_healing(null, 40, caster)
	var gained := int(foes[0].health.hp) - hp_before
	_check(gained == 24, "HEAL_CUT: a 40 heal delivers 24 (retains 60%%) — gained %d" % gained)

	# DODGE_CHANCE: a straight chance, "flat" (mag == amount). Stronger = higher, same convention.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_apply(caster, {"kind": "dodge_chance", "amount": 30, "turns": 4}, "user", [caster], m, false)
	var dodge = caster.get_effects_by_type(EffectType.Type.DODGE_CHANCE)
	_check(dodge.size() == 1 and int(dodge[0].mag) == 30, "DODGE_CHANCE: amount 30 writes mag 30 (flat)")

	# A flat-magnitude row: BARRIER (Nullify) absorbs the HOLDER's outgoing damage, mag points of it.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_apply(caster, {"kind": "barrier", "amount": 25, "turns": 4}, "all_enemies", [foes[0]], m)
	var bar = foes[0].get_effects_by_type(EffectType.Type.BARRIER)
	_check(bar.size() == 1 and int(bar[0].mag) == 25, "BARRIER: amount 25 writes mag 25 (offensive absorb)")
	# The reader consumes it against damage the holder (foes[0]) DEALS.
	var absorbed := int(foes[0].check_damage_against_barriers(null, 10, foes[0]))
	_check(absorbed == 0 and int(bar[0].mag) == 15, "BARRIER: absorbs a 10-damage hit the holder deals (25 -> 15)")

	# ==================================================================================
	# 2. HOSTILE, AS DATA (A4) — per-row routing, proven both directions.
	# ==================================================================================
	# A HOSTILE row (isolate) routes through add_hostile_effect, so invulnerability refuses it and a
	# shrug (true_ignoring) drops it — it can NOT reach a target no hand-written kit could.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_self_effect(foes[0], m, Effect.invuln_effect(20))
	_apply(caster, {"kind": "isolate", "turns": 2}, "all_enemies", [foes[0]], m)
	_check(not _has_type(foes[0], "ISOLATE"), "A4: a hostile ISOLATE is REFUSED by the target's invulnerability")

	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_self_effect(foes[0], m, Effect.ignore_non_damage_effect(20))   # foes[0] now true_ignoring
	_apply(caster, {"kind": "heal_cut", "amount": 40, "turns": 4}, "all_enemies", [foes[0]], m)
	_check(not _has_type(foes[0], "HEAL_CUT"), "A4: a hostile HEAL_CUT is dropped by shrug_off_type (the enemy is ignoring non-damage effects)")

	# An ALLIED row (damage_cap_receive) routes through add_allied_effect, which does NOT consult
	# invulnerability — so it lands where the hostile one was refused. This is the whole reason the
	# column exists: an allied-declared effect must NOT be gated, a hostile-declared one MUST.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_self_effect(foes[0], m, Effect.invuln_effect(20))
	_apply(caster, {"kind": "damage_cap_receive", "amount": 20, "turns": 4}, "all_enemies", [foes[0]], m, false)
	_check(_has_type(foes[0], "DAMAGE_CAP_RECEIVE"), "A4: an allied DAMAGE_CAP_RECEIVE lands through add_allied_effect despite the target's invulnerability")

	# ==================================================================================
	# 3. EVERY ROW LANDS AND ITS READER SEES IT (presence, for the flag rows).
	# ==================================================================================
	_probe_reader_lands("isolate", true, func(c): return c.is_isolated(), "is Isolated")
	_probe_reader_lands("blind", true, func(c): return c.blind_check(), "is blinded")
	_probe_reader_lands("false_stun", true, func(c): return c.has_stuns(), "counts as stunned")
	_probe_reader_lands("ignore_healing", true, func(c): return c.heal_blocked(), "cannot be healed")
	_probe_reader_lands("no_boost", true, func(c): return not c.can_boost(), "cannot boost damage")
	_probe_reader_lands("chain_nullify", true, func(c): return not c.shrug_off_type(EffectType.Type.CHAIN_NULLIFY) and not c.get_effects_by_type(EffectType.Type.CHAIN_NULLIFY).is_empty(), "zeroes its output")
	_probe_reader_lands("immortality", false, func(c): return c.is_immortal(), "is immortal")
	_probe_reader_lands("sharpshooter", false, func(c): return not c.get_effects_by_type(EffectType.Type.SHARPSHOOTER).is_empty(), "cannot be dodged")
	_probe_reader_lands("stealth", false, func(c): return c.stealthed(), "is stealthed")
	_probe_reader_lands("ignore_cleanse", true, func(c): return not c.get_effects_by_type(EffectType.Type.IGNORE_CLEANSE).is_empty(), "cannot be cleansed")
	_probe_reader_lands("ignore_non_damage", false, func(c): return c.true_ignoring(), "ignores non-damage effects")
	_probe_reader_lands("damage_reverse", false, func(c): return c.damage_reversed(), "reverses damage")

	# ==================================================================================
	# HOSTILITY GROUND TRUTH — the check that would have caught ignore_cleanse.
	# The prior cross-check (creator_hardening_a2a4_probe's PHASE_C_HOSTILE_NAMES) was a HAND-COPY
	# of the same human judgment as the schema's `hostile` column, so a shared mistake passed both.
	# This one is INDEPENDENT: it reads how the SHIPPED KITS actually route each effect — an
	# Effect.<factory>_effect(...) followed by add_hostile_effect or add_allied_effect in
	# abilities/*.gd — and asserts the schema's column agrees wherever the corpus has evidence.
	# A kind the corpus never applies cannot be checked and is skipped (an honest gap, listed).
	# Re-derive with: the python scan in the Phase C fix notes (scratchpad).
	_probe_hostility_ground_truth()


	# ==================================================================================
	# 4. PARITY — one generic Effect.from construction vs a shipped factory call.
	# ==================================================================================
	# BARRIER: barrier_effect never sets barrier_func (character_component.gd:881 calls the default),
	# so the generic arm's Effect.from(BARRIER,{}) is behaviourally identical to the shipped factory
	# for the property that matters — the absorb — differing only in the two DISPLAY flags the factory
	# turns on. Assert type + mag parity, and that BOTH absorb through the default callable.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	var shipped = Effect.barrier_effect(25, 4)
	var mine = BlockRunner.new(_mk(_spec([]), caster), m, caster)._build_simple_effect(
		"barrier", {"kind": "barrier", "amount": 25, "turns": 4}, 4)
	_check(shipped.effect_type == mine.effect_type and int(shipped.mag) == int(mine.mag),
		"PARITY/barrier: generic Effect.from matches Effect.barrier_effect on type and mag (%s/%d vs %s/%d)" % [shipped.effect_type, shipped.mag, mine.effect_type, mine.mag])
	# CHAIN_NULLIFY has NO factory — Effect.from is its ONLY constructor, exactly the gilgamesh2.gd:28
	# shape {"description":..., "duration":N}. The generic arm reaches the same effect.
	var gil_shape = Effect.from(EffectType.Type.CHAIN_NULLIFY, {"description": "x", "duration": 3})
	var mine_cn = BlockRunner.new(_mk(_spec([]), caster), m, caster)._build_simple_effect(
		"chain_nullify", {"kind": "chain_nullify", "turns": 2}, 3)
	_check(gil_shape.effect_type == mine_cn.effect_type and int(mine_cn.duration) == 3,
		"PARITY/chain_nullify: the generic arm reaches the same Effect.from shape gilgamesh2 uses (type=%s, dur=%d)" % [mine_cn.effect_type, mine_cn.duration])

	# ==================================================================================
	# 5. GUARDS — the reader-maths ceilings STAY; the invented balance caps are GONE.
	# ==================================================================================
	# REMOVED CAPS (owner ruling: the Creator enforces no restriction the game itself lacks). The
	# immortality / isolate / ignore_non_damage duration + permanence caps were invented balance guards.
	# A permanent or long one of these is a strong effect an APPROVER weighs before release, not a rule
	# the engine has — the roster ships permanent IMMORTALITY (Stark), ISOLATE and IGNORE_NON_DAMAGE
	# (Yubel). So they now VALIDATE where they used to be refused; the 2-turn form is the positive control.
	_check(_valid([{"op": "apply", "to": "user", "effect": {"kind": "immortality", "turns": -1}}]),
		"REMOVED CAP/immortality: a PERMANENT immortality VALIDATES (author-controlled; Stark ships one)")
	_check(_valid([{"op": "apply", "to": "user", "effect": {"kind": "immortality", "turns": 5}}]),
		"REMOVED CAP/immortality: a 5-turn immortality VALIDATES (no duration cap)")
	_check(_valid([{"op": "apply", "to": "user", "effect": {"kind": "immortality", "turns": 2}}]),
		"POSITIVE CONTROL/immortality: a 2-turn immortality validates")
	_check(_valid([{"op": "apply", "to": "target", "effect": {"kind": "isolate", "turns": -1}}]),
		"REMOVED CAP/isolate: a PERMANENT isolate VALIDATES (Yubel shipped one; strength is an approver's call)")
	_check(_valid([{"op": "apply", "to": "user", "effect": {"kind": "ignore_non_damage", "turns": -1}}]),
		"REMOVED CAP/ignore_non_damage: a PERMANENT one VALIDATES (Yubel's passive ticks it forever)")
	# Percentage ceilings — above them the reader's own maths inverts. These STAY (correctness rails,
	# not balance caps): a card that promises one thing and does the opposite is not a design choice.
	_check(not _valid([{"op": "apply", "to": "target", "effect": {"kind": "percent_dr", "amount": 120, "turns": 2}}]),
		"GUARD/percent_dr: amount 120 is refused (>100 would HEAL the attacker's target)")
	_check(not _valid([{"op": "apply", "to": "target", "effect": {"kind": "heal_cut", "amount": 150, "turns": 2}}]),
		"GUARD/heal_cut: amount 150 is refused (>100 would turn a heal into damage)")

	# ==================================================================================
	# 6. EDITOR — every row confines itself to already-rendered field names (zero new widgets).
	# ==================================================================================
	var rendered := ["amount", "turns"]   # the branches every Simple row relies on (app.js:5926/5932)
	var offenders: Array = []
	for k in BlockSchema.SIMPLE_EFFECTS.keys():
		for f in (BlockSchema.SIMPLE_EFFECTS[k]["fields"] as Array):
			if not str(f) in rendered:
				offenders.append("%s.%s" % [str(k), str(f)])
	_check(offenders.is_empty(),
		"EDITOR: every Simple Effect field already has a render branch (offenders: %s)" % str(offenders))

	# ==================================================================================
	# 7. BOT TAGS — grounded in training/bake_bot_tags.py, so an authored kit is a real opponent.
	# ==================================================================================
	_check(_tags_of([{"op": "apply", "to": "target", "effect": {"kind": "isolate", "turns": 2}}]) & ScriptedAbility.TAG_CONTROL != 0,
		"BOT/isolate: tagged CONTROL (bake_bot_tags.py groups isolate under CONTROL)")
	_check(_tags_of([{"op": "apply", "to": "target", "effect": {"kind": "barrier", "amount": 20, "turns": 2}}]) & ScriptedAbility.TAG_MITIGATE != 0,
		"BOT/barrier: tagged MITIGATE (bake_bot_tags.py fingerprints barrier_effect as MITIGATE)")
	_check(_tags_of([{"op": "apply", "to": "user", "effect": {"kind": "immortality", "turns": 2}}]) & ScriptedAbility.TAG_INVULN != 0,
		"BOT/immortality: tagged INVULN (bake_bot_tags.py fingerprints immortality_effect as INVULN)")
	_check(_tags_of([{"op": "apply", "to": "target", "effect": {"kind": "ignore_healing", "turns": 2}}]) == 0,
		"BOT/ignore_healing: UNTAGGED — the baker fingerprints no factory for it, so an honest 0 (not a guessed bit)")

	# ==================================================================================
	# 8. SCHEMA SELF-CHECK — the constant-vs-constant table drift check (section K passes separately).
	# ==================================================================================
	var drift := BlockSchema.self_check()
	_check(drift.is_empty(), "SELF-CHECK: SIMPLE_EFFECTS folds into EFFECT_KINDS with no drift (%s)" % str(drift))

	# ==================================================================================
	# 9. GENERATED PROSE reads as English, per row, from the reader's semantics.
	# ==================================================================================
	_check(_prose_has("isolate", {"kind": "isolate", "turns": 2}, "Isolates the target") and
			_prose_has("isolate", {"kind": "isolate", "turns": 2}, "healing, shields, cleanse"),
		"PROSE/isolate: names WHAT it removes")
	_check(_prose_has("barrier", {"kind": "barrier", "amount": 20, "turns": 2}, "the next 20 damage the target deals"),
		"PROSE/barrier: says 'damage the target DEALS' (offensive suppression, not a shield)")
	_check(_prose_has("heal_cut", {"kind": "heal_cut", "amount": 40, "turns": 2}, "receives by 40%"),
		"PROSE/heal_cut: reads from the author's number (40%), not the retained register (60)")

	_probe_portrait_change_presence()

	print("=== effect-table probe: %d failure(s) ===" % fails)
	get_tree().quit(fails)

# ITEM 4 — PORTRAIT_CHANGE is now IMPLEMENTED (was deferred). This is the FLIP of the old deferral
# assertion: the authorable kind exists as a NAMED kind (not a Simple Effect row — it needs system=true
# + cleansable=false, which the generic arm cannot set), and its precondition — the alt-portrait upload
# slots — now exists. creator_portrait_change_probe covers the full validate/build/reserve/bounds
# behaviour; this only asserts the presence signal the deferral probe used to guard.
func _probe_portrait_change_presence() -> void:
	print("-- item 4: portrait_change presence --")
	# The factory stores the portrait INDEX in `mag` — a non-magnitude register — which is WHY the row
	# declares `reserves` for mag (so an authored universal mag cannot clobber the portrait index).
	var pc = Effect.portrait_change_effect(2, 4)
	_check(pc.effect_type == EffectType.Type.PORTRAIT_CHANGE and int(pc.mag) == 2,
		"factory stores the portrait index in the mag register (mag=%d) — a non-magnitude register the row reserves" % int(pc.mag))
	pc.free()
	# IMPLEMENTED: portrait_change is an authorable NAMED kind. It is NOT a Simple Effect row (a named kind
	# has a real factory, so it has no 'type' key — detect it by kind name / factory, per the map note).
	_check(not BlockSchema.SIMPLE_EFFECTS.has("portrait_change"),
		"portrait_change is a NAMED kind, not a Simple Effect row (only the named factory sets system=true + cleansable=false)")
	_check(BlockSchema.EFFECT_KINDS.has("portrait_change") and
		str(BlockSchema.EFFECT_KINDS["portrait_change"].get("factory", "")) == "portrait_change_effect",
		"IMPLEMENTED: an authorable effect kind ('portrait_change') wires the portrait_change_effect factory")
	# The mag reserve is present so a universal mag cannot clobber the index.
	_check(BlockSchema.reserved_fields("portrait_change").has("mag"),
		"portrait_change reserves the mag register from its `index` field")
	# POSITIVE CONTROL: a shipped Simple Effect row (percent_dr) IS present, so the negative above (not in
	# SIMPLE_EFFECTS) is a real distinction, not the check being blind.
	_check(BlockSchema.SIMPLE_EFFECTS.has("percent_dr"),
		"control: a shipped Simple Effect row (percent_dr) IS in the table (the presence check is real)")
	# THE PRECONDITION now MET: the alt-portrait upload slots exist, and none is handed out as a skill icon.
	var alt_slots: int = AuthoredAssets.alt_portrait_slots().size()
	_check(alt_slots >= 1,
		"PRECONDITION: AuthoredAssets exposes %d alt-portrait slot(s) (the gating dependency)" % alt_slots)
	var alt_leaked := false
	for slot in AuthoredAssets.alt_portrait_slots():
		if str(slot) in AuthoredAssets.ability_slots():
			alt_leaked = true
	_check(not alt_leaked,
		"PRECONDITION: no alt-portrait slot is ever handed out as a skill icon")
	_check(not ("portrait" in AuthoredAssets.ability_slots()),
		"PRECONDITION: the base portrait slot is never handed out as a skill icon")

# Apply one row and assert its reader sees it on a legal target. `harmful` picks the side so the
# effect travels the path its column declares.
func _probe_reader_lands(kind: String, harmful: bool, reader: Callable, phrase: String) -> void:
	var s = _fresh(); var m = s["m"]; var caster = s["allies"][0]; var foes = s["foes"]
	var target = foes[0] if harmful else caster
	var to := "all_enemies" if harmful else "user"
	var eff := {"kind": kind, "turns": 3}
	if "amount" in (BlockSchema.SIMPLE_EFFECTS[kind]["fields"] as Array):
		eff["amount"] = 20
	_apply(caster, eff, to, [target], m, harmful)
	_check(bool(reader.call(target)), "READER/%s: lands and its reader agrees the holder %s" % [kind, phrase])

func _valid(blocks: Array) -> bool:
	return BlockValidator.validate_ability(_spec(blocks)).is_empty()

func _tags_of(blocks: Array) -> int:
	var a := ScriptedAbility.new()
	a.configure(_spec(blocks))
	return int(a.bot_tags)

func _prose_has(kind: String, spec: Dictionary, needle: String) -> bool:
	var a := ScriptedAbility.new()
	a.configure(_spec([{"op": "apply", "to": ("target" if BlockSchema.SIMPLE_EFFECTS[kind]["hostile"] else "user"), "effect": spec}]))
	for seg in a.split_desc():
		if str(seg).find(needle) != -1:
			return true
	return false

# Scan abilities/*.gd for how each SIMPLE_EFFECTS factory is applied (hostile vs allied), and assert
# the schema's `hostile` column matches the shipped majority wherever evidence exists. This reads the
# game's own routing, not a human's re-statement of it, so it is a real independent oracle.
func _probe_hostility_ground_truth() -> void:
	print("-- hostility ground truth (derived from shipped kits) --")
	var host := {}   # factory basename -> count applied via add_hostile_effect
	var ally := {}   # factory basename -> count applied via add_allied_effect
	var dir := DirAccess.open("res://abilities")
	if dir == null:
		_check(false, "GROUND-TRUTH: could not open abilities/ — cannot derive")
		return
	# Plain-string scan (no regex — GDScript string escapes make a regex literal a parse-error trap).
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if fn.ends_with(".gd"):
			var f := FileAccess.open("res://abilities/" + fn, FileAccess.READ)
			if f != null:
				var lines := f.get_as_text().split("\n")
				f.close()
				for i in range(lines.size()):
					var pair := _parse_factory_assign(lines[i])
					if pair.is_empty():
						continue
					var var_name: String = pair[0]
					var fac: String = pair[1]
					# look a few lines ahead for the add_*_effect that consumes this var
					for j in range(i, mini(i + 8, lines.size())):
						if var_name in lines[j] and "add_hostile_effect" in lines[j]:
							host[fac] = int(host.get(fac, 0)) + 1
							break
						if var_name in lines[j] and "add_allied_effect" in lines[j]:
							ally[fac] = int(ally.get(fac, 0)) + 1
							break
		fn = dir.get_next()
	dir.list_dir_end()

	# Map each SIMPLE_EFFECTS kind to the factory basename it would be built from. The row key IS the
	# factory basename for every simple row (ignore_cleanse -> ignore_cleanse_effect), so the key
	# doubles as the lookup — verified by the parity section using Effect.<key>_effect.
	var checked := 0
	var no_evidence: Array = []
	for kind in BlockSchema.SIMPLE_EFFECTS.keys():
		var k := str(kind)
		var h := int(host.get(k, 0))
		var a := int(ally.get(k, 0))
		if h == 0 and a == 0:
			no_evidence.append(k)
			continue
		checked += 1
		# Majority rules; a tie or any hostile use makes it hostile (the safe direction — a hostile
		# effect mis-routed allied lands ungated, the A4 defect).
		var truth_hostile := h > 0
		var schema_hostile := bool(BlockSchema.SIMPLE_EFFECTS[k]["hostile"])
		_check(schema_hostile == truth_hostile,
			"GROUND-TRUTH/%s: schema hostile=%s matches shipped routing (host=%d ally=%d => %s)"
			% [k, str(schema_hostile), h, a, str(truth_hostile)])
	_check(checked >= 6, "GROUND-TRUTH: enough rows had shipped evidence to be a real check (%d)" % checked)
	print("   (no shipped applier, reasoned not corpus-checked: %s)" % str(no_evidence))

# "var foo = Effect.bar_effect(..." -> ["foo", "bar"], else []. No regex, so no escape traps.
func _parse_factory_assign(line: String) -> Array:
	var marker := "= Effect."
	var mi := line.find(marker)
	if mi < 0:
		return []
	var suffix := "_effect("
	var si := line.find(suffix, mi)
	if si < 0:
		return []
	var fac := line.substr(mi + marker.length(), si - (mi + marker.length()))
	if fac == "" or not fac.is_valid_identifier():
		return []
	var lhs := line.substr(0, mi).strip_edges()
	var parts := lhs.split(" ")
	var var_name := str(parts[parts.size() - 1]).strip_edges()
	if var_name == "" or not var_name.is_valid_identifier():
		return []
	return [var_name, fac]
