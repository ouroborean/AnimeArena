extends Node

# ============================================================================
# Creator hardening, Phase A items A2 + A4.
#
# A2 — POOL RE-VALIDATION. A block that says `to: "target"` acts on characters the
# TARGETING system already vetted. Every other selector builds its pool inside
# BlockRunner, and the primitives under `damage` / `break` / `cleanse` / `remove` ask
# nothing: resolve_damage never consults is_invuln, shatter_shields / shatter_barrier
# check nothing, cleanse_all_enemy_effects is gated only on IGNORE_CLEANSE. So an
# authored `to: "all_enemies"` used to reach straight through an invulnerable defender,
# which no hand-written kit can do. This probe asserts the four ops now stop, that
# `target` and the two safe ops (`apply`, `heal`) do NOT, and that `bypassing: true` is the
# one opt-out.
#
# BYPASSING - THE WORD AND THE MECHANIC. The opt-out was briefly called `pierce`; that name
# collided with DamageType.Type.PIERCING (a damage type that ignores damage REDUCTION and has
# nothing to do with invulnerability - scripts/character_component.gd:699, :834), so it now
# carries the engine's own word, the one `apply` and Character.add_*_effect have always used.
# And the ability-level "Bypassing" CLASS is now WIRED: ScriptedAbility.target passes it to the
# targeting helpers (so a Bypassing authored skill can SELECT an invulnerable enemy the way a
# shipped one does), and it is the DEFAULT for every block's pool check, which the per-block
# field overrides in both directions. Before this, ticking the class printed a chip on the card
# and did nothing at all.
#
# A4 — HOSTILITY AS DATA. The literal seven-name list in BlockRunner._is_hostile_effect
# is now a per-kind `hostile` column in BlockSchema.EFFECT_KINDS. Asserted
# behaviour-preserving for EVERY kind on the palette, not a sample.
#
# Run: godot --headless --path <repo> res://training/tests/creator_hardening_a2a4_probe.tscn
# ============================================================================

# The pre-A4 literal, kept here as the ORACLE. This is the list that used to live in
# BlockRunner; the data-driven answer has to match it for every kind on the palette.
const OLD_HOSTILE_NAMES := [
	"damage_over_time", "stun", "silence", "vulnerability", "destructible_break",
	"paralyze", "taunt"]

# PHASE C — the Simple Effect Table's hostile rows, hand-listed HERE independently of the `hostile`
# column in BlockSchema so this stays a real cross-check (two sources that must agree), exactly the
# way OLD_HOSTILE_NAMES cross-checks the named kinds. The answer per kind was read off its READER:
# a debuff you drop on an enemy is hostile, a guard you give yourself/an ally is not. The allied
# Simple rows are the complement and need no entry (membership defaults to false).
const PHASE_C_HOSTILE_NAMES := [
	"heal_cut", "health_cap", "damage_cap", "isolate", "blind",
	"ignore_healing", "no_boost", "false_stun", "chain_nullify", "delay", "barrier",
	# ignore_cleanse was ORIGINALLY OMITTED here and mis-tagged allied in the schema — a shared
	# blind spot that this hand-list could not catch because it repeated the same wrong judgment.
	# The real guard is now the CORPUS-DERIVED cross-check in creator_effect_table_probe (section
	# "hostility ground truth"), which reads how the shipped kits actually route each effect.
	"ignore_cleanse"]

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

# One battle per assertion group: cleanse and break tear down effects, so sharing a
# board between cases would let one case decide another's answer.
func _fresh() -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 2024, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

# Deliberately NOT Helpful: an authored ability that is not flagged Helpful is the case
# where can_apply_allied_effect skips its helpable check, which is what makes the
# "apply is unchanged" assertion below able to fail.
func _mk(spec: Dictionary, owner, bypassing := false) -> ScriptedAbility:
	var a := ScriptedAbility.new()
	a.configure(spec)
	a.ability_name = str(spec.get("name", "Authored"))
	a.classes = {"Physical": false, "Energy": false, "Mental": false, "Affliction": false,
		"Strategic": false, "Harmful": true, "Helpful": false, "Instant": true, "Action": false,
		"Control": false, "Channeled": false, "Uncounterable": false, "Bypassing": bypassing,
		"Stealthed": false, "Passive": false, "Preserves Channel": false, "Damaging": true}
	a.user = owner
	owner.moveset.add_ability(a)
	return a

func _cast(caster, ab, targets: Array, m):
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)

# Place an effect a character owns on ITSELF, bypassing application gating — this is
# board setup, not a thing under test.
func _self_effect(c, m, eff) -> void:
	eff.set_source(c.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(c, m), c, c, eff, true)

func _invuln(c, m) -> void:
	_self_effect(c, m, Effect.invuln_effect(20))

func _isolate(c, m) -> void:
	_self_effect(c, m, Effect.isolate(20))

# A named mark planted by MY side on a character, so cleanse/remove have something of
# ours to find. Applied BEFORE any invulnerability, or the application itself is refused.
func _plant(caster, victim, m, nm: String) -> void:
	var e = Effect.mark(20)
	e.name_override = nm
	e.set_source(caster.moveset.base_abilities[0])
	Character.add_hostile_effect(QueryContext.from_game_state(caster, m), caster, victim, e)

func _shield(c, m) -> void:
	_self_effect(c, m, Effect.shield_effect(20, 20))

# Iron Maiden is a TARGETING restriction the game already has (Condition.extra_targetable):
# a character carrying it may only be targeted by itself. It is the sharpest available
# probe of "was this pool re-validated?", because — unlike invulnerability and isolation —
# NOTHING in the application or healing path consults it. Whatever stops on it stopped
# because A2's check ran.
func _iron_maiden(c, m) -> void:
	var e = Effect.mark(20)
	e.name_override = "Iron Maiden"
	_self_effect(c, m, e)

# Re-run the ability's OWN target() and report who it legally marked. Snapshotting and
# restoring the `targeted` flags is the whole side effect, exactly as
# Ability._skill_pierces_invuln does it (abilities/scripts/ability_component.gd:446-457).
func _targets_of(ab, caster, m) -> Array:
	var chars = m.all_characters()
	var saved := []
	for c in chars:
		saved.append(c.targeted)
		c.targeted = false
	ab.target(caster, m)
	var hit := []
	for c in chars:
		if c.targeted:
			hit.append(c)
	for i in range(chars.size()):
		chars[i].targeted = saved[i]
	return hit

func _ready():
	print("=== Creator hardening A2 + A4 ===")

	# ================= A2: the four ops stop at an illegal target ==============

	# ---- damage ------------------------------------------------------------
	var s = _fresh(); var m = s["m"]; var caster = s["allies"][0]; var foes = s["foes"]
	_invuln(foes[1], m)
	_check(foes[1].is_invuln(null), "setup: foes[1] is invulnerable")
	var hp := [foes[0].health.hp, foes[1].health.hp, foes[2].health.hp]
	_cast(caster, _mk({"name": "Sweep", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies"}]}, caster), [foes[0]], m)
	_check(foes[0].health.hp == hp[0] - 10, "A2 damage/all_enemies: legal enemy took 10")
	_check(foes[1].health.hp == hp[1], "A2 damage/all_enemies: INVULNERABLE enemy took nothing (%d)" % foes[1].health.hp)
	_check(foes[2].health.hp == hp[2] - 10, "A2 damage/all_enemies: the other legal enemy took 10")

	# ---- break -------------------------------------------------------------
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_shield(foes[0], m); _shield(foes[1], m)
	_invuln(foes[1], m)
	_cast(caster, _mk({"name": "Shatter", "target": "all_enemies", "blocks": [
		{"op": "break", "what": "shield", "to": "all_enemies"}]}, caster), [foes[0]], m)
	_check(foes[0].get_shield_effects().is_empty(), "A2 break/all_enemies: legal enemy's shield broke")
	_check(foes[1].get_shield_effects().size() == 1, "A2 break/all_enemies: INVULNERABLE enemy kept its shield")

	# ---- remove ------------------------------------------------------------
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_plant(caster, foes[0], m, "Probe Mark"); _plant(caster, foes[1], m, "Probe Mark")
	_invuln(foes[1], m)
	_check(foes[1].has_any_effect("Probe Mark"), "setup: the mark is on the invulnerable enemy")
	_cast(caster, _mk({"name": "Strip", "target": "all_enemies", "blocks": [
		{"op": "remove", "name": "Probe Mark", "to": "all_enemies"}]}, caster), [foes[0]], m)
	_check(not foes[0].has_any_effect("Probe Mark"), "A2 remove/all_enemies: legal enemy's mark removed")
	_check(foes[1].has_any_effect("Probe Mark"), "A2 remove/all_enemies: INVULNERABLE enemy's mark survived")

	# ---- cleanse -----------------------------------------------------------
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_plant(caster, foes[0], m, "Probe Mark"); _plant(caster, foes[1], m, "Probe Mark")
	_invuln(foes[1], m)
	_cast(caster, _mk({"name": "Wash", "target": "all_enemies", "blocks": [
		{"op": "cleanse", "to": "all_enemies"}]}, caster), [foes[0]], m)
	_check(not foes[0].has_any_effect("Probe Mark"), "A2 cleanse/all_enemies: legal enemy was cleansed")
	_check(foes[1].has_any_effect("Probe Mark"), "A2 cleanse/all_enemies: INVULNERABLE enemy was not cleansed")

	# ---- the opt-out -------------------------------------------------------
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_invuln(foes[1], m)
	var bp_hp: int = foes[1].health.hp
	_cast(caster, _mk({"name": "Reach", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies", "bypassing": true}]}, caster), [foes[0]], m)
	_check(foes[1].health.hp == bp_hp - 10, "A2 bypassing:true: the author's opt-out reaches the invulnerable enemy")
	# A hand-edited file never met the validator, and bool("no") is TRUE in GDScript — so a
	# non-bool must not be readable as an opt-out.
	bp_hp = foes[1].health.hp
	_cast(caster, _mk({"name": "Junk Reach", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies", "bypassing": "no"}]}, caster), [foes[0]], m)
	_check(foes[1].health.hp == bp_hp, "A2 a non-bool `bypassing` is not an opt-out (invuln still held)")

	# ---- `target` is NOT re-filtered ---------------------------------------
	# Its characters came out of user.targeter.targets, which the targeting system (and
	# battle_manager's invuln-target drop filter) already vetted. Re-checking here would
	# double-filter and quietly change what a `to`-less block has always done.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_invuln(foes[1], m)
	var tgt_hp: int = foes[1].health.hp
	_cast(caster, _mk({"name": "Direct", "target": "enemy", "blocks": [
		{"op": "damage", "amount": 10}]}, caster), [foes[1]], m)
	_check(foes[1].health.hp == tgt_hp - 10, "A2 to:'target' pool is untouched (still resolves as before)")

	# ---- random_enemy filters BEFORE the roll ------------------------------
	# Rolling first and discarding an illegal pick would silently produce no-op casts;
	# six casts against a one-legal-enemy board must therefore land six hits.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_invuln(foes[1], m); _invuln(foes[2], m)
	var rnd_hp := [foes[0].health.hp, foes[1].health.hp, foes[2].health.hp]
	var rnd := _mk({"name": "Scatter", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "random_enemy"}]}, caster)
	for i in range(6):
		_cast(caster, rnd, [foes[0]], m)
	_check(foes[0].health.hp == rnd_hp[0] - 60,
		"A2 random_enemy rolls among LEGAL targets only: 6 casts = 6 hits (%d -> %d)" % [rnd_hp[0], foes[0].health.hp])
	_check(foes[1].health.hp == rnd_hp[1] and foes[2].health.hp == rnd_hp[2],
		"A2 random_enemy: neither invulnerable enemy was ever picked")

	# ---- the condition-filtered selectors ----------------------------------
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_invuln(foes[1], m)
	var f_hp := [foes[0].health.hp, foes[1].health.hp]
	_cast(caster, _mk({"name": "Seek", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "any_enemy",
		 "when": {"cond": "hp_above", "value": 1}}]}, caster), [foes[0]], m)
	_check(foes[0].health.hp == f_hp[0] - 10, "A2 any_enemy: legal enemy matching the filter was hit")
	_check(foes[1].health.hp == f_hp[1], "A2 any_enemy: INVULNERABLE enemy dropped before the filter")

	# ================= A2: the ALLIED half =====================================
	# can_allied_target's non-bypass clause is is_helpable == "not isolated", so isolation
	# is the allied analogue of invulnerability and needs no separate check.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; var allies = s["allies"]
	_shield(allies[1], m); _shield(allies[2], m)
	_isolate(allies[1], m)
	_check(allies[1].is_isolated(), "setup: allies[1] is isolated")
	_cast(caster, _mk({"name": "Team Shatter", "target": "all_allies", "blocks": [
		{"op": "break", "what": "shield", "to": "all_allies"}]}, caster), [caster], m)
	_check(allies[2].get_shield_effects().is_empty(), "A2 break/all_allies: reachable ally's shield broke")
	_check(allies[1].get_shield_effects().size() == 1, "A2 break/all_allies: ISOLATED ally's shield survived")

	# ---- apply and heal are UNCHANGED --------------------------------------
	# Iron Maiden is the discriminator: it makes an ally an illegal TARGET while leaving
	# both the healing path and the effect-application path completely indifferent. So
	# `break` must skip this ally while `heal` and `apply` must not — which is exactly
	# what "the fix does not double-filter the two safe ops" means.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; allies = s["allies"]
	_iron_maiden(allies[1], m)
	_shield(allies[1], m)
	allies[1].health.hp = 50
	_cast(caster, _mk({"name": "Mixed", "target": "all_allies", "blocks": [
		{"op": "break", "what": "shield", "to": "all_allies"},
		{"op": "heal", "amount": 10, "to": "all_allies"},
		{"op": "apply", "to": "all_allies", "effect": {"kind": "mark", "turns": 3, "name_override": "Rally"}}]},
		caster), [caster], m)
	_check(allies[1].get_shield_effects().size() == 1,
		"A2 break/all_allies: an Iron-Maiden'd ally is not a legal target, so its shield survived")
	_check(allies[1].health.hp > 50,
		"A2 heal is UNCHANGED: the same ally was still healed (%d)" % allies[1].health.hp)
	_check(allies[1].has_any_effect("Rally"),
		"A2 apply is UNCHANGED: the same ally still received the effect")

	# ================= A2: schema + validator ==================================
	for op in BlockSchema.REVALIDATED_OPS:
		_check(BlockSchema.OPS.has(op) and "bypassing" in (BlockSchema.OPS[op]["fields"] as Array),
			"A2 schema: '%s' re-validates and therefore offers `bypassing`" % op)
	# APPLY-STYLE ops carry their own `bypassing` legitimately — it is the add_*_effect PARAMETER
	# (ignore the target's invulnerability when applying), not the REVALIDATED_OPS pool re-check.
	# `apply` and `seal` both hand `bypassing` straight to add_hostile_effect/add_allied_effect
	# (block_runner _op_apply / _op_seal:1172-1174). A future apply-style op belongs in this set.
	var APPLY_STYLE_BYPASS := ["apply", "seal"]
	for op in BlockSchema.OPS.keys():
		if str(op) in BlockSchema.REVALIDATED_OPS or str(op) in APPLY_STYLE_BYPASS:
			continue
		_check(not "bypassing" in (BlockSchema.OPS[op]["fields"] as Array),
			"A2 schema: '%s' does not re-validate, so it must not offer `bypassing`" % str(op))
	# THE RENAME: `pierce` is gone everywhere, with no compatibility alias. It shipped hours ago
	# and no authored content used it, so a leftover would only ever be a typo that validates.
	for op in BlockSchema.OPS.keys():
		_check(not "pierce" in (BlockSchema.OPS[op]["fields"] as Array),
			"rename: '%s' no longer offers the misnomer `pierce`" % str(op))
	_check(not BlockValidator.validate_ability({"name": "P", "blocks": [
		{"op": "damage", "amount": 5, "to": "all_enemies", "pierce": true}]}).is_empty(),
		"rename: `pierce` is REJECTED as an unknown field on damage")
	_check(BlockValidator.validate_ability({"name": "P", "blocks": [
		{"op": "damage", "amount": 5, "to": "all_enemies", "bypassing": true}]}).is_empty(),
		"A2 validator: `bypassing` accepted on damage")
	for op4 in BlockSchema.REVALIDATED_OPS:
		var blk := {"op": str(op4), "to": "all_enemies", "bypassing": false}
		match str(op4):
			"damage":  blk["amount"] = 5
			"remove":  blk["name"] = "Probe Mark"
			"break":   blk["what"] = "shield"
			"adjust":
				# Phase B added `adjust` to REVALIDATED_OPS (nothing under a duration/stack/mag
				# write consults a targeting predicate, so a pool-built `to` would otherwise reach
				# an invulnerable defender). This loop is table-driven off REVALIDATED_OPS on
				# purpose — a new op only has to declare its own REQUIRED fields here.
				blk["name"] = "Probe Mark"
				blk["turns"] = 1
		_check(BlockValidator.validate_ability({"name": "P", "blocks": [blk]}).is_empty(),
			"A2 validator: `bypassing` accepted on '%s'" % str(op4))
	_check(not BlockValidator.validate_ability({"name": "P", "blocks": [
		{"op": "heal", "amount": 5, "to": "all_allies", "bypassing": true}]}).is_empty(),
		"A2 validator: `bypassing` REJECTED on heal (inert there)")

	# ================= THE `Bypassing` CLASS IS WIRED ==========================
	# Owner's requirement: "skills can be correctly marked as Bypassing and have them correctly
	# target invulnerable targets." Every negative below sits beside a legal-target control, so
	# a pass can never come from the skill simply doing nothing.

	# ---- layer 1: TARGETING ------------------------------------------------
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_invuln(foes[1], m)
	var plain := _mk({"name": "Plain Swing", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies"}]}, caster)
	var byp := _mk({"name": "Bypassing Swing", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies"}]}, caster, true)
	var plain_t := _targets_of(plain, caster, m)
	var byp_t := _targets_of(byp, caster, m)
	_check(foes[0] in plain_t, "targeting control: a NON-Bypassing skill still selects the legal enemy")
	_check(not foes[1] in plain_t, "targeting: a NON-Bypassing skill cannot select the INVULNERABLE enemy")
	_check(foes[0] in byp_t, "targeting control: a Bypassing skill still selects the legal enemy")
	_check(foes[1] in byp_t, "targeting: a Bypassing skill SELECTS the invulnerable enemy (the class now does something)")

	# ---- layer 2: the block POOL -------------------------------------------
	# Both layers have to agree, or a Bypassing AoE selects an invulnerable enemy at targeting
	# and then silently drops it when the block resolves.
	var cls_hp := [foes[0].health.hp, foes[1].health.hp]
	_cast(caster, byp, [foes[0]], m)
	_check(foes[0].health.hp == cls_hp[0] - 10, "pool control: the Bypassing skill still hit the legal enemy")
	_check(foes[1].health.hp == cls_hp[1] - 10, "pool: the class is the block DEFAULT - the invulnerable enemy took 10 too")

	# ---- the per-block override, BOTH directions ---------------------------
	# Direction A: skill marked Bypassing, one block told to respect invulnerability anyway.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_invuln(foes[1], m)
	var ov_hp := [foes[0].health.hp, foes[1].health.hp]
	_cast(caster, _mk({"name": "Restrained", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies", "bypassing": false}]}, caster, true), [foes[0]], m)
	_check(foes[0].health.hp == ov_hp[0] - 10, "override control: `bypassing: false` still hit the legal enemy")
	_check(foes[1].health.hp == ov_hp[1],
		"override A: `bypassing: false` overrides the Bypassing CLASS (invulnerable enemy spared)")
	# Direction B: a skill WITHOUT the class, one block told to reach through anyway.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_invuln(foes[1], m)
	ov_hp = [foes[0].health.hp, foes[1].health.hp]
	_cast(caster, _mk({"name": "One Reach", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies", "bypassing": true}]}, caster), [foes[0]], m)
	_check(foes[0].health.hp == ov_hp[0] - 10, "override control: `bypassing: true` still hit the legal enemy")
	_check(foes[1].health.hp == ov_hp[1] - 10,
		"override B: `bypassing: true` on a skill WITHOUT the class reaches the invulnerable enemy")

	# ---- `apply` is a DIFFERENT LAYER and keeps its old behaviour ----------
	# apply's `bypassing` is the add_*_effect PARAMETER (land the effect through invuln), not a
	# targeting-pool gate - and shipped kits pass it per call, never off the class (byakuya7 and
	# misaka2 both carry the class and pass nothing). So it does NOT inherit; wiring it to the
	# class would invent a rule the game does not have.
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	_invuln(foes[0], m); _invuln(foes[1], m)
	_cast(caster, _mk({"name": "Weaken Plain", "target": "enemy", "blocks": [
		{"op": "apply", "effect": {"kind": "vulnerability", "amount": 10, "turns": 2}}]}, caster), [foes[0]], m)
	_check(foes[0].effects.get_effects_by_type(EffectType.Type.VULNERABILITY).is_empty(),
		"apply control: without `bypassing`, invulnerability still refuses the effect")
	_cast(caster, _mk({"name": "Weaken Through", "target": "enemy", "blocks": [
		{"op": "apply", "bypassing": true, "effect": {"kind": "vulnerability", "amount": 10, "turns": 2}}]}, caster), [foes[0]], m)
	_check(not foes[0].effects.get_effects_by_type(EffectType.Type.VULNERABILITY).is_empty(),
		"apply: its pre-existing `bypassing` field still lands the effect through invulnerability")
	_cast(caster, _mk({"name": "Weaken Classy", "target": "enemy", "blocks": [
		{"op": "apply", "effect": {"kind": "vulnerability", "amount": 10, "turns": 2}}]}, caster, true), [foes[1]], m)
	_check(foes[1].effects.get_effects_by_type(EffectType.Type.VULNERABILITY).is_empty(),
		"apply: the CLASS does not silently become apply's parameter (application layer unchanged)")

	# ---- generated prose ---------------------------------------------------
	# The class already prints as a chip on the skill card, so an INHERITED default adds no
	# clause; only a block that says something the card does not gets a sentence.
	var prose_on := _mk({"name": "Prose On", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies", "bypassing": true}]}, caster)
	var prose_off := _mk({"name": "Prose Off", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies", "bypassing": false}]}, caster, true)
	var prose_none := _mk({"name": "Prose None", "target": "all_enemies", "blocks": [
		{"op": "damage", "amount": 10, "to": "all_enemies"}]}, caster, true)
	_check("even through invulnerability" in str(prose_on.split_desc()[0]),
		"prose: an explicit `bypassing: true` says so - '%s'" % str(prose_on.split_desc()[0]))
	_check("but not through invulnerability" in str(prose_off.split_desc()[0]),
		"prose: an explicit `bypassing: false` says so - '%s'" % str(prose_off.split_desc()[0]))
	_check(not "invulnerability" in str(prose_none.split_desc()[0]),
		"prose: an inherited default adds no clause - '%s'" % str(prose_none.split_desc()[0]))

	# ================= A4: hostility is data ===================================
	s = _fresh(); m = s["m"]; caster = s["allies"][0]; foes = s["foes"]
	var probe_ability := _mk({"name": "A4", "target": "enemy", "blocks": [
		{"op": "damage", "amount": 1}]}, caster)
	var runner := BlockRunner.new(probe_ability, m, caster)

	var missing := 0
	var mismatched := 0
	for k in BlockSchema.EFFECT_KINDS.keys():
		var kind := str(k)
		if not (BlockSchema.EFFECT_KINDS[kind] as Dictionary).has("hostile"):
			missing += 1
			print("        -> '%s' declares no `hostile` column" % kind)
			continue
		# Both signs, so the two HOSTILE_BY_SIGN kinds are exercised in both directions
		# and every other kind is proven to IGNORE the sign the way the old list did.
		for amt in [1, -1]:
			var new_answer: bool = runner._is_hostile_effect({"kind": kind, "amount": amt})
			var old_answer: bool = _old_is_hostile(kind, amt)
			if new_answer != old_answer:
				mismatched += 1
				print("        -> '%s' (amount %d): was %s, now %s" % [kind, amt, old_answer, new_answer])
	_check(missing == 0, "A4: every one of the %d palette kinds declares `hostile`" % BlockSchema.EFFECT_KINDS.size())
	_check(mismatched == 0, "A4: data-driven hostility equals the old seven-name answer for EVERY kind, both signs")
	# The alias has to survive: a character saved before the rename still says "reactive".
	_check(runner._is_hostile_effect({"kind": "reactive"}) == false,
		"A4: the pre-rename alias still resolves (reactive -> trigger, allied)")

	# ...and the column actually DRIVES the routing, not merely a pure function: a hostile
	# kind must go through add_hostile_effect, which invulnerability refuses. Declared
	# allied, it would slip in through add_allied_effect — the exact hazard the column exists
	# to prevent.
	_invuln(foes[0], m)
	_cast(caster, _mk({"name": "Weaken", "target": "enemy", "blocks": [
		{"op": "apply", "effect": {"kind": "vulnerability", "amount": 10, "turns": 2}}]}, caster), [foes[0]], m)
	_check(foes[0].effects.get_effects_by_type(EffectType.Type.VULNERABILITY).is_empty(),
		"A4 routing: a `hostile: true` kind went through add_hostile_effect and invuln refused it")
	_cast(caster, _mk({"name": "Guard", "target": "self", "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "shield", "amount": 20, "turns": 2}}]}, caster), [caster], m)
	_check(caster.get_shield_effects().size() == 1,
		"A4 routing: a `hostile: false` kind went through add_allied_effect and landed")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)

# The pre-A4 implementation, verbatim in shape: the signed pair by sign, everything else
# by membership of the literal list.
func _old_is_hostile(kind: String, amount: int) -> bool:
	# damage_boost is signed too, but its attack is a WEAKEN — a NEGATIVE amount is the hostile side
	# (the inverse of a cost/cooldown tax). Matches SIGN_HOSTILE_WHEN_NEGATIVE in the schema.
	if kind == "damage_boost":
		return amount < 0
	if kind in BlockValidator.SIGNED_AMOUNT_KINDS:
		return amount > 0
	return kind in OLD_HOSTILE_NAMES or kind in PHASE_C_HOSTILE_NAMES
