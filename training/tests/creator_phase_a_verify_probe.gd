extends Node

# ============================================================================
# INDEPENDENT verification of Creator Phase A, run after all three build groups
# landed. It does NOT re-test what each group's own probe already covers; it
# tests the two things no single group could:
#
#   1. CROSS-GROUP A2 x A4. A2 filters the pools BlockRunner builds through
#      Condition.can_hostile_target / can_allied_target, chosen PER CANDIDATE by
#      user.is_hostile(c). A4 decides, PER KIND, whether an `apply` routes through
#      Character.add_hostile_effect (which refuses an invulnerable target) or
#      add_allied_effect (which does not). Those are two different axes, and the
#      question is whether they AGREE about the same character on the same board.
#      They agree for every kind the column calls hostile. They do NOT agree for
#      the kinds it calls allied, because `apply` is deliberately outside
#      BlockSchema.REVALIDATED_OPS — so the composite claim "after A2, no authored
#      op reaches an invulnerable enemy" is false, and this probe pins exactly
#      which kinds are the exception so a future palette row cannot widen the set
#      unnoticed.
#
#   2. TWO NAMES A1's blocklist does not cover, both reachable today with the
#      shipped `mark` kind and both with a real payout. Asserted as the ENGINE
#      behaviour (what the collision buys), plus the fact that the validator
#      currently accepts them.
#
# Run: godot --headless --path <repo> res://training/tests/creator_phase_a_verify_probe.tscn
# ============================================================================

# The pre-A4 hostility answer, taken from the DESIGN DOCS rather than from the shipped
# column ("Creator Gap Analysis.md":154, "Block Palette Reference.md":114): the literal
# seven names, plus the two signed kinds answering by sign. Held independently so this
# probe can catch a column that drifts in either direction.
const ORACLE_HOSTILE_NAMES := ["damage_over_time", "stun", "silence", "vulnerability",
	"destructible_break", "paralyze", "taunt",
	# PHASE C — the Simple Effect Table's hostile rows, listed independently of BlockSchema's
	# `hostile` column (this probe's whole point is to be a SECOND source that must agree). The side
	# of each was read off its reader: heal_cut/health_cap/damage_cap/ignore_healing/no_boost debuff
	# an enemy; isolate/blind/false_stun deny their actions; chain_nullify zeroes their output; delay
	# slows their tempo; barrier (Nullify) is offensive suppression of the enemy's damage.
	"heal_cut", "health_cap", "damage_cap", "isolate", "blind",
	"ignore_healing", "no_boost", "false_stun", "chain_nullify", "delay", "barrier",
	# ignore_cleanse: originally mis-tagged allied in the schema AND omitted from all three hand
	# oracles (this one, a2a4's, and the schema column) — a shared blind spot. It is HOSTILE: the
	# shipped Deadly Gas drops it on an enemy (kurotsuchi6.gd:30). The genuinely independent guard is
	# the CORPUS-DERIVED check in creator_effect_table_probe, which reads the routing off the kits.
	"ignore_cleanse"]
const ORACLE_SIGNED_KINDS := ["cost_change", "cooldown_change"]

func _oracle_hostile(kind: String, amount: int) -> bool:
	if kind in ORACLE_SIGNED_KINDS:
		return amount > 0
	# damage_boost is signed too, but its attack is a WEAKEN — a negative amount is the hostile side
	# (the inverse of a cost/cooldown tax). Hand-derived here, independent of the schema it checks.
	if kind == "damage_boost":
		return amount < 0
	return kind in ORACLE_HOSTILE_NAMES

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

func _mk(spec: Dictionary, owner) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Authored"))
	a.classes = {"Physical": false, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": false, "Harmful": true, "Helpful": false, "Instant": true, "Action": false,
		"Control": false, "Channeled": false, "Uncounterable": false, "Bypassing": false,
		"Stealthed": false, "Passive": false, "Preserves Channel": false, "Damaging": true}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)

func _self_effect(c, m, eff) -> void:
	eff.set_source(c.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(c, m), c, c, eff, true)

func _invuln(c, m) -> void:
	_self_effect(c, m, Effect.invuln_effect(20))

# A minimally-valid `apply` spec for one kind, so every kind can be driven through
# the same code path. The factory-specific fields come from BlockSchema itself, not
# from a hand-kept list here, so a kind added later is exercised automatically.
func _spec_for(kind: String) -> Dictionary:
	var spec := {"kind": kind, "turns": 2}
	var fields: Array = BlockSchema.EFFECT_KINDS[kind]["fields"] as Array
	if "amount" in fields: spec["amount"] = 10
	if "trigger" in fields: spec["trigger"] = "on_damaged"
	if "then" in fields: spec["then"] = [{"op": "damage", "amount": 1, "to": "user"}]
	if "scope" in fields: spec["scope"] = "all"
	if "slot" in fields: spec["slot"] = 0
	if "into" in fields: spec["into"] = 1
	if "colour" in fields: spec["colour"] = "random"
	if "effect" in fields: spec["effect"] = "stun"
	return spec

# One fresh board, one `apply` of this kind at the enemy front-liner, answering only
# "did an Effect end up stored on them". `invuln` picks which of the two boards this is.
func _apply_and_see(kind: String, spec: Dictionary, invuln: bool) -> bool:
	var s = _fresh(); var m = s["m"]; var c = s["allies"][0]; var f = s["foes"]
	if invuln:
		_invuln(f[0], m)
	var before: int = f[0].effects._effects.size()
	_cast(c, _mk({"name": "Probe " + kind, "target": "all_enemies", "blocks": [
		{"op": "apply", "to": "all_enemies", "effect": spec}]}, c), [f[0]], m)
	return f[0].effects._effects.size() > before

func _ready():
	print("=== Creator Phase A — independent verification ===")

	# ============================================================================
	# 1. CROSS-GROUP: A2's pool predicate vs A4's routing column
	# ============================================================================
	var s = _fresh(); var m = s["m"]; var caster = s["allies"][0]; var foes = s["foes"]
	_invuln(foes[0], m)
	_check(foes[0].is_invuln(null), "setup: foes[0] is invulnerable")

	# A2's own answer about this exact character, taken from the shipped helper rather
	# than re-derived, so the two sides of the comparison cannot drift apart.
	var carrier := _mk({"name": "Carrier", "target": "enemy", "blocks": [
		{"op": "damage", "amount": 1}]}, caster)
	var runner := BlockRunner.new(carrier, m, caster)
	var a2_legal: Array = runner._legal_pool([foes[0]], false)
	_check(a2_legal.is_empty(),
		"A2's pool predicate calls an invulnerable enemy ILLEGAL (this is the hostile predicate, chosen by user.is_hostile)")

	# The expectation comes from THIS probe's own oracle — the pre-A4 seven-name list as
	# recorded in "Creator Gap Analysis.md":154 and "Block Palette Reference.md":114, read
	# out of the design docs rather than out of the shipped column — so a column edited in
	# either direction fails here instead of quietly redefining what "correct" means.
	var agree: Array = []
	var disagree: Array = []
	var column_wrong: Array = []
	var routing_wrong: Array = []
	var unbuildable: Array = []
	for k in BlockSchema.EFFECT_KINDS.keys():
		var kind := str(k)
		var spec := _spec_for(kind)
		var expected_hostile: bool = _oracle_hostile(kind, int(spec.get("amount", 1)))
		var a4_hostile: bool = runner._is_hostile_effect(spec)
		if a4_hostile != expected_hostile:
			column_wrong.append("%s (column says %s, the pre-A4 answer was %s)" % [kind, a4_hostile, expected_hostile])
		# TWO boards per kind. Without the control, a kind whose spec the factory declines to
		# build would look "refused by invulnerability" and the assertion would pass for the
		# wrong reason — the difference between the two boards is the only thing invulnerability
		# can explain.
		var landed_control: bool = _apply_and_see(kind, spec, false)
		var landed_invuln: bool = _apply_and_see(kind, spec, true)
		if not landed_control:
			unbuildable.append(kind)
			continue
		# AGREEMENT means: what A4's column decided produced the same verdict about this
		# character that A2's pool predicate gave. A2 said "illegal", so agreement is
		# "the effect did not land".
		if landed_invuln == expected_hostile:
			routing_wrong.append("%s (landed on the invulnerable enemy=%s, expected refused=%s)" % [kind, landed_invuln, expected_hostile])
		if expected_hostile:
			agree.append(kind)
		elif landed_invuln:
			disagree.append(kind)
	for w in column_wrong:
		print("        -> COLUMN DRIFT: " + w)
	for w in routing_wrong:
		print("        -> ROUTING DRIFT: " + w)
	# Not a failure by itself — these kinds' minimal specs do not produce a stored Effect on a
	# plain enemy, so this probe has nothing to say about their routing. It IS a failure if a
	# kind the oracle calls hostile is among them, because then "invulnerability refused it"
	# would be unfalsifiable.
	print("        -> kinds this probe could not exercise (no effect stored even on a legal enemy): %s" % str(unbuildable))
	for u in unbuildable:
		_check(not _oracle_hostile(str(u), 1),
			"A4: hostile kind '%s' is exercisable, so its refusal is a real observation" % str(u))
	_check(column_wrong.is_empty(),
		"A4's `hostile` column still equals the pre-A4 seven-name answer for all %d kinds" % BlockSchema.EFFECT_KINDS.size())
	_check(routing_wrong.is_empty(),
		"…and every hostile kind is REFUSED by invulnerability while every allied kind lands — routing follows the column, and agrees with A2 for the hostile half (%d kinds)" % agree.size())

	# The disagreement is real and structural, not a bug in one group's work: `apply` is
	# deliberately outside REVALIDATED_OPS, so nothing re-checks the pool, and a kind the
	# column calls allied is applied with add_allied_effect, whose only extra clause
	# (is_helpable) is skipped entirely unless the ability is classed Helpful
	# (Condition.can_apply_allied_effect, scripts/condition.gd:109-117).
	print("        -> kinds where A4's routing DISAGREES with A2's pool verdict (they land on an invulnerable enemy through `apply`): %s" % str(disagree))
	_check(disagree.size() > 0,
		"the A2/A4 disagreement set is non-empty — `apply` is the op A2 does not cover, and this probe names the kinds")
	# Pinned so a NEW palette row cannot widen it unnoticed. `mark` being in this set is
	# what makes A1's blocklist load-bearing: a name-collision mark can be planted on a
	# defender that no hand-written kit could touch.
	_check("mark" in disagree,
		"…and `mark` is one of them, which is why A1's reserved-name list is the only guard on that path")

	# The ALLIED mirror of the same disagreement, so it is recorded as symmetric rather
	# than as an enemy-side quirk: an ISOLATED ally is illegal for A2 (can_allied_target's
	# is_helpable clause), and `break` therefore stops on them — but `apply` still lands,
	# because can_apply_allied_effect only consults is_helpable when the source ability is
	# classed Helpful, and an authored ability need not be.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; var allies = s["allies"]
	_self_effect(allies[1], m, Effect.isolate(20))
	_self_effect(allies[1], m, Effect.shield_effect(20, 20))
	var r2 := BlockRunner.new(_mk({"name": "Carrier2", "target": "ally", "blocks": [
		{"op": "damage", "amount": 1}]}, caster), m, caster)
	_check(r2._legal_pool([allies[1]], false).is_empty(),
		"A2's ALLIED pool predicate calls an isolated ally ILLEGAL")
	_cast(caster, _mk({"name": "Team Mixed", "target": "all_allies", "blocks": [
		{"op": "break", "what": "shield", "to": "all_allies"},
		{"op": "apply", "to": "all_allies", "effect":
			{"kind": "mark", "turns": 2, "name_override": "Rally"}}]}, caster), [caster], m)
	_check(allies[1].get_shield_effects().size() == 1,
		"…so `break` (a REVALIDATED_OP) stopped on the isolated ally")
	_check(allies[1].has_any_effect("Rally"),
		"…while `apply` on the same ally still landed — the allied mirror of the A2/A4 disagreement")

	print("")
	# ============================================================================
	# 2. A1 — two reachable hardcoded names the shipped blocklist does not carry
	# ============================================================================

	# (a) "Warp Digivolve - Beelzemon": receive_healing multiplies ALL healing by the
	# mark's `mag` as a percent (scripts/character_component.gd:1093-1097). Effect.mark
	# leaves mag at 0 (effect_component.gd:14, :1175-1185), so a plain authored mark of
	# this name planted on an ENEMY means that enemy can never be healed again.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	var healer = s["foes"][1]                      # an enemy healing their own teammate
	foes[0].health.hp = 50
	var control_heal := _mk({"name": "Mend", "target": "ally", "blocks": [
		{"op": "heal", "amount": 20, "to": "target"}]}, healer)
	_cast(healer, control_heal, [foes[0]], m)
	_check(foes[0].health.hp == 70, "CONTROL: an unmarked character heals normally (%d)" % foes[0].health.hp)

	foes[0].health.hp = 50
	_cast(caster, _mk({"name": "Impmon Curse", "target": "all_enemies", "blocks": [
		{"op": "apply", "to": "all_enemies", "effect":
			{"kind": "mark", "turns": -1, "name_override": "Warp Digivolve - Beelzemon"}}]}, caster), [foes[0]], m)
	_check(foes[0].has_any_effect("Warp Digivolve - Beelzemon"),
		"A1 GAP (a): an authored mark named 'Warp Digivolve - Beelzemon' lands on an enemy")
	_cast(healer, control_heal, [foes[0]], m)
	_check(foes[0].health.hp == 50,
		"A1 GAP (a): …and that enemy can no longer be healed AT ALL (mag 0 multiplier), hp still %d" % foes[0].health.hp)
	_check(Character.RESERVED_EFFECT_NAMES.has("Warp Digivolve - Beelzemon"),
		"A1 GAP (a) CLOSED: the name is now on the reserved list")
	_check(not AuthoredRegistry.validate_character(_char_with_name_override("Warp Digivolve - Beelzemon", true)).is_empty(),
		"A1 GAP (a) CLOSED: …and the validator now REJECTS a character that uses it")

	# (b) "Crush Card Virus": the blocklist's exclusion note keys this name to the
	# DAMAGE_CAP branch, but Character.apply_effect:179 reads it as a MARK from any user —
	# every invisible effect the marked character applies is forced visible. That is the
	# same payout as "Data Collection", which IS on the list, and it needs no particular
	# teammate.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	var hidden = Effect.mark(10)
	hidden.name_override = "Sneaky"
	hidden.invisible = true
	hidden.set_source(foes[0].moveset.base_abilities[0])
	foes[0].apply_effect(hidden, foes[1])
	_check(hidden.invisible, "CONTROL: an unmarked enemy's invisible effect stays invisible")

	_cast(caster, _mk({"name": "Kaiba Tell", "target": "all_enemies", "blocks": [
		{"op": "apply", "to": "all_enemies", "effect":
			{"kind": "mark", "turns": -1, "name_override": "Crush Card Virus"}}]}, caster), [foes[0]], m)
	_check(foes[0].has_any_effect("Crush Card Virus"),
		"A1 GAP (b): an authored mark named 'Crush Card Virus' lands on an enemy")
	var hidden2 = Effect.mark(10)
	hidden2.name_override = "Sneaky2"
	hidden2.invisible = true
	hidden2.set_source(foes[0].moveset.base_abilities[0])
	foes[0].apply_effect(hidden2, foes[1])
	_check(not hidden2.invisible,
		"A1 GAP (b): …and every invisible effect that enemy applies is forced VISIBLE")
	_check(Character.RESERVED_EFFECT_NAMES.has("Crush Card Virus"),
		"A1 GAP (b) CLOSED: the name is now on the reserved list (the MARK branch at :179, not just DAMAGE_CAP)")

	# The names that ARE on the list still reject, so this probe is not measuring an
	# absent check.
	_check(not AuthoredRegistry.validate_character(_char_with_name_override("Plasmantle", true)).is_empty(),
		"A1 CONTROL: a reserved name ('Plasmantle') is still rejected")

	print("")
	# ============================================================================
	# 3. A PRE-EXISTING VALIDATOR ABORT that silently disarms every check above it
	# ============================================================================
	# AuthoredRegistry.validate_character:269 reads `a["classes"]` after guarding only
	# with `a.get("classes", []) is Array` — an empty default IS an Array, so an ability
	# dict with no `classes` key satisfies the guard and then subscripts a missing key.
	# The runtime error unwinds validate_character, which returns the default empty Array
	# for its declared return type: every error accumulated so far (id safety, name
	# length, per-ability block errors, the A1 reserved-name rejection, the four-slot
	# count) is discarded and the spec validates CLEAN.
	var abortable := _char_with_name_override("Plasmantle", false)   # no `classes` key
	var abort_errs: Array = AuthoredRegistry.validate_character(abortable)
	_check(not abort_errs.is_empty(),
		"ABORT FIXED: an ability dict with NO `classes` key still VALIDATES — %d error(s), not a swallowed 0" % abort_errs.size())
	# The same spec with an explicit empty `classes` — the only difference — is rejected,
	# which is what proves the emptiness above is the abort and not a legitimate pass.
	_check(not AuthoredRegistry.validate_character(_char_with_name_override("Plasmantle", true)).is_empty(),
		"…while the SAME spec with \"classes\": [] is rejected — so the empty result is the abort, not a pass")
	# And the abort swallows a security check, not only a design one: a traversal-shaped id
	# is refused with `classes` present and accepted without it.
	var bad_id := _char_with_name_override("Skill X", false)
	bad_id["id"] = "../../etc/passwd"
	_check(not AuthoredRegistry.validate_character(bad_id).is_empty(),
		"…and the id path-safety check survives it: a '../' id is REJECTED even with `classes` absent")
	# …and the BLOCK checks, which is what makes the bypass a content problem and not just a
	# metadata one: an over-limit damage amount is rejected with `classes` present and
	# accepted without it, so unvalidated block content can be stored AND re-loaded (load_all
	# re-validates through the same aborting function).
	var over := _char_with_name_override("Skill X", false)
	over["abilities"][1]["blocks"] = [{"op": "damage", "amount": BlockSchema.LIMITS["max_amount"] * 100}]
	var over_ok := _char_with_name_override("Skill X", true)
	over_ok["abilities"][1]["blocks"] = [{"op": "damage", "amount": BlockSchema.LIMITS["max_amount"] * 100}]
	_check(not AuthoredRegistry.validate_character(over_ok).is_empty(),
		"CONTROL: an over-limit `damage` amount is rejected when `classes` is present")
	_check(not AuthoredRegistry.validate_character(over).is_empty(),
		"…and STILL rejected when it is absent — unvalidated block content can no longer be saved")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)

# The smallest character spec that validates, with one effect name_override swapped in.
# `with_classes` controls the single key that decides whether validate_character finishes
# or aborts at :269 — see section 3.
func _char_with_name_override(nm: String, with_classes: bool) -> Dictionary:
	var abils: Array = []
	for i in range(4):
		var one := {"name": "Skill %d" % i, "target": "enemy",
			"blocks": [{"op": "damage", "amount": 10}]}
		if with_classes:
			one["classes"] = []
		abils.append(one)
	abils[0]["blocks"] = [{"op": "apply", "effect":
		{"kind": "mark", "turns": 2, "name_override": nm}}]
	return {"id": "auth_zzprobe", "name": "ZZ Probe", "author": "ZZ_verify",
		"status": "draft", "colors": [0], "abilities": abils}
