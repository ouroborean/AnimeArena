extends Node

# ============================================================================
# CREATOR — PORTRAIT_CHANGE (authored transformation into an uploaded alt portrait).
#
# A NAMED effect kind (not a Simple Effect row: it needs system=true + cleansable=false,
# which only Effect.portrait_change_effect sets). This probe proves, end to end:
#   * a portrait_change block VALIDATES, and its `index` bound refuses an out-of-range slot;
#   * it BUILDS a PORTRAIT_CHANGE effect whose mag is the chosen index, carrying system=true
#     and cleansable=false;
#   * `reserves` works — a universal `mag` cannot clobber the index (validator rejects it, and the
#     runtime backstop skips it so the built mag still equals the index);
#   * the schema self_check stays green with the new reserved row;
#   * the character_component bounds guard returns the DEFAULT portrait for an out-of-range index on
#     an EMPTY alt_portraits[] (an authored character) instead of crashing.
#
#   godot --headless --path <repo> res://training/tests/creator_portrait_change_probe.tscn
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

# Apply ONE effect spec at `targets` through the REAL runner path (execute -> BlockRunner),
# NOT the validator — this is how a hand-edited file that never met the validator reaches the
# _apply_universal_fields reserved-register backstop.
func _apply(caster, spec: Dictionary, to: String, targets: Array, m, harmful := false) -> void:
	var ab := _mk({"name": "Apply " + str(spec.get("kind", "")), "target": "enemy",
		"blocks": [{"op": "apply", "to": to, "effect": spec}]}, caster, harmful)
	_cast(caster, ab, targets, m)

func _spec(blocks: Array) -> Dictionary:
	return {"name": "Probe", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Harmful"], "blocks": blocks, "requires": []}

func _ready():
	print("=== CREATOR — PORTRAIT_CHANGE ===")
	var alt_count: int = AuthoredAssets.alt_portrait_slots().size()
	print("-- alt-portrait slot count: %d --" % alt_count)

	# ==================================================================================
	# 1. SCHEMA — the kind is present, named, and its self_check is green.
	# ==================================================================================
	_check(BlockSchema.EFFECT_KINDS.has("portrait_change"), "portrait_change is an authorable effect kind")
	_check(str(BlockSchema.EFFECT_KINDS["portrait_change"].get("factory", "")) == "portrait_change_effect",
		"it wires the portrait_change_effect factory (NAMED kind, not the generic __simple__ arm)")
	_check(BlockSchema.reserved_fields("portrait_change").get("mag", "") == "index",
		"it reserves the `mag` register from its `index` field (like reflect reserves mag from destination)")
	var sc := BlockSchema.self_check()
	_check(sc.is_empty(), "schema self_check stays green with the new reserved row (errs=%s)" % str(sc))

	# ==================================================================================
	# 2. VALIDATION — a clean block validates; `index` is structurally bounded to the alt-slot count.
	# ==================================================================================
	var ok := _spec([{"op": "apply", "to": "user", "effect": {"kind": "portrait_change", "index": 0, "turns": -1}}])
	_check(BlockValidator.validate_ability(ok).is_empty(), "a portrait_change(index 0, permanent) validates clean")
	# CONTROL at the TOP index — the last valid slot passes (the bound is inclusive of count-1).
	var top := _spec([{"op": "apply", "to": "user", "effect": {"kind": "portrait_change", "index": alt_count - 1, "turns": 2}}])
	_check(BlockValidator.validate_ability(top).is_empty(),
		"CONTROL: the top alt-slot index (%d) validates — the bound is not off-by-one" % (alt_count - 1))
	# An index PAST the alt slots is rejected (a 404 client-side would silently render the default portrait —
	# a card promising a transform that never shows).
	var over := _spec([{"op": "apply", "to": "user", "effect": {"kind": "portrait_change", "index": alt_count, "turns": 2}}])
	var e_over := BlockValidator.validate_ability(over)
	_check(not e_over.is_empty(), "index == count (%d) is REJECTED (errs=%s)" % [alt_count, str(e_over)])
	var e_99 := BlockValidator.validate_ability(_spec([{"op": "apply", "to": "user", "effect": {"kind": "portrait_change", "index": 99, "turns": 2}}]))
	_check(not e_99.is_empty(), "index 99 is REJECTED")
	_check(str(e_99).find("index") != -1, "the rejection names `index`, the field at fault")

	# ==================================================================================
	# 3. RESERVES — a universal `mag` cannot clobber the index.
	# ==================================================================================
	# 3a. The validator refuses a portrait_change carrying a universal `mag` (both write the same register).
	var mag_spec := _spec([{"op": "apply", "to": "user", "effect": {"kind": "portrait_change", "index": 2, "turns": -1, "mag": 0}}])
	var e_mag := BlockValidator.validate_ability(mag_spec)
	_check(not e_mag.is_empty(), "a portrait_change carrying a universal `mag` is REJECTED (errs=%s)" % str(e_mag))
	_check(str(e_mag).find("index") != -1, "the rejection points at `index`, the field that owns the register")
	# NEGATIVE CONTROL: the same block WITHOUT the universal mag validates — the rejection is the mag, not the kind.
	_check(BlockValidator.validate_ability(_spec([{"op": "apply", "to": "user", "effect": {"kind": "portrait_change", "index": 2, "turns": -1}}])).is_empty(),
		"NEGATIVE CONTROL: the same portrait_change without `mag` validates clean")

	# ==================================================================================
	# 4. BUILD — the effect lands with mag == index, system=true, cleansable=false; and the runtime
	#    backstop skips a hand-edited universal mag so the built mag STILL equals the index.
	# ==================================================================================
	var s := _fresh(); var m = s["m"]; var caster = s["allies"][0]
	_apply(caster, {"kind": "portrait_change", "index": 2, "turns": -1}, "user", [caster], m, false)
	var pc = caster.get_effects_by_type(EffectType.Type.PORTRAIT_CHANGE)
	_check(pc.size() == 1, "a PORTRAIT_CHANGE effect lands on the caster (count=%d)" % pc.size())
	if pc.size() == 1:
		_check(int(pc[0].mag) == 2, "the built mag equals the chosen index (mag=%d)" % int(pc[0].mag))
		_check(pc[0].system == true, "system=true (so the snapshot keeps it off the visible wire)")
		_check(pc[0].cleansable == false, "cleansable=false (a transform must survive a cleanse)")

	# 4b. RESERVES on the RUNTIME path: a hand-edited file with BOTH index and a universal mag builds
	#     through the runner (no validator), and _apply_universal_fields must SKIP the reserved mag so the
	#     built mag is the INDEX (3), never the universal 0.
	var s2 := _fresh(); var m2 = s2["m"]; var caster2 = s2["allies"][0]
	_apply(caster2, {"kind": "portrait_change", "index": 3, "turns": -1, "mag": 0}, "user", [caster2], m2, false)
	var pc2 = caster2.get_effects_by_type(EffectType.Type.PORTRAIT_CHANGE)
	_check(pc2.size() == 1 and int(pc2[0].mag) == 3,
		"reserves backstop: a universal mag:0 does NOT clobber the index — built mag=%s" % (str(pc2[0].mag) if pc2.size() == 1 else "<none>"))

	# ==================================================================================
	# 5. CHARACTER_COMPONENT BOUNDS GUARD — an EMPTY alt_portraits[] with a live server index must
	#    resolve to the DEFAULT portrait, not crash (an authored character never fills alt_portraits).
	# ==================================================================================
	var ch = Character.from_character_name("naruto")
	var empty_alts: Array[Texture2D] = []       # typed to match @export Array[Texture2D]
	ch.alt_portraits = empty_alts               # authored-character shape: no alt textures server-side
	ch.mastery_portrait_on = false
	ch.mastery_skin_on = false
	ch.server_portrait_set = true               # live-match path: the index is server-resolved
	ch.server_portrait_alt = 0                  # in-bounds for the wire, OUT of bounds for the empty array
	ch.server_portrait_disguise = ""
	var tex = ch.active_portrait()
	_check(tex == ch.portrait_texture,
		"bounds guard: index 0 on an EMPTY alt_portraits[] returns the DEFAULT portrait (no out-of-bounds crash)")
	# CONTROL: with no server override and no PORTRAIT_CHANGE effect, final_path stays -1 -> default too,
	# proving the guard did not simply swallow a real alt.
	ch.server_portrait_set = false
	_check(ch.active_portrait() == ch.portrait_texture, "CONTROL: an untransformed character resolves to the default portrait")
	ch.queue_free()

	print("=== portrait-change probe: %d failure(s) ===" % fails)
	get_tree().quit(fails)
