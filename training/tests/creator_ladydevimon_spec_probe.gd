extends Node

# ============================================================================
# CREATOR ROULETTE 10 — LADYDEVIMON, the create-ability PROOF.
#
# The payoff of the Roulette-10 audit + the signed/filterable `damage_boost`
# build. It proves — through the REAL AuthoredRegistry, the REAL validator and a
# REAL headless battle — that LadyDevimon's shipped kit (abilities/ladydevimon{1..5}.gd)
# can be authored ENTIRELY as block-tree JSON: no character/ladydevimon.gd, no
# ability scripts, no .tscn. The ONE gap the draw exposed (a HOSTILE, damage-type-
# EXCLUDING damage-dealt weaken — ladydevimon3's "decreases non-Affliction damage
# by 10") is now a first-class authored field, and this probe fields the whole
# character on top of it.
#
#   godot --headless --path <repo> res://training/tests/creator_ladydevimon_spec_probe.tscn
#
# What is asserted, per skill (contract = split_desc + execute of the shipped .gd):
#   ladydevimon1 "Black Wing"     — 20 AFFLICTION to target enemy
#   ladydevimon2 "Devil Slap"     — 20 NORMAL + Taunt 1 turn
#   ladydevimon3 "Darkness Spear" — 10 Nullify + hostile non-Affliction weaken (-10, the NEW
#                                   field) + conditional first 5 Affliction + 1 stack Lady's Poison
#   ladydevimon4 "Darkness Wave"  — self Invulnerable 1 turn
#   ladydevimon5 "Lady's Poison"  — PASSIVE on_harmful_received: an enemy that hits her gains a
#                                   permanent STACKING Lady's Poison (5 Affliction/turn PER stack)
#
# THE POISON-NAME COUPLING (the one fidelity knot): both ladydevimon3's manual stack and the
# passive's stacks must land under the SAME effect name so they MERGE. The passive ABILITY is named
# "Lady's Poison" (abilities_data.json), so its DoT inherits that name for free; skill 3's DoT is
# sourced from "Darkness Spear", so it carries name_override:"Lady's Poison" to match. The
# not_has_effect guard in skill 3 keys on that same name. Section 3 proves the merge (a second cast
# does NOT re-deal the first-instance 5, and the stack count climbs) and section 5 proves the passive
# stacks the SAME effect.
#
# RESIDUAL FIDELITY (proven / stated honestly in `losses`, not hand-waved):
#   * The passive's poison rides the authored-passive PERMANENCE machinery
#     (AuthoredCharacter._make_permanent_effects_survive: system/display_system + remove_on_death:false
#     + cleansable:false), so it survives a buff-strip and the death cleanse. The hand-written
#     ladydevimon5 poison is a plain cleansable DoT. This is a documented property of authoring a
#     PERMANENT passive effect (it would otherwise silently die), not a defect of this spec — but it
#     means a passive-applied stack is stickier than skill 3's, and a merge kept whichever landed first.
# ============================================================================

const CHAR_ID := "auth_zz_ladydevimon_roulette"
const AUTHOR := "ZZ_LADYDEVIMON_ROULETTE_10"
const POISON := "Lady's Poison"

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

# ---------------------------------------------------------------------------
# THE SPEC — the whole authored LadyDevimon, as one validated JSON object.
# Costs / cooldowns / classes copied verbatim from abilities_data.json; damage
# amounts from the shipped .gd split_desc/execute (20, 20, 5, 5).
# Energy indices: 1 = Red, 3 = Blue, 4 = Random (Energy.Type).
# ---------------------------------------------------------------------------
func _spec() -> Dictionary:
	return {
		"id": CHAR_ID,
		"name": "LadyDevimon",
		"author": AUTHOR,
		"status": "testing",
		"colors": [1, 3, 4],  # Red + Blue + Random — the colours her costs actually spend (draft hint)
		"description": "Fallen-angel Digimon. Poisons anyone foolish enough to strike her.",
		"abilities": [
			# --- ladydevimon1: "Black Wing" — 20 AFFLICTION -------------------------------------
			{"name": "Black Wing", "target": "enemy", "cooldown": 1, "cost": {"4": 1},
			 "classes": ["Affliction", "Harmful", "Instant", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "damage", "amount": 20, "damage_type": "AFFLICTION", "to": "target"}]},
			# --- ladydevimon2: "Devil Slap" — 20 NORMAL + Taunt 1 turn --------------------------
			{"name": "Devil Slap", "target": "enemy", "cooldown": 1, "cost": {"3": 1},
			 "classes": ["Physical", "Instant", "Harmful", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "damage", "amount": 20, "damage_type": "NORMAL", "to": "target"},
				{"op": "apply", "to": "target", "effect": {"kind": "taunt", "turns": 1}}]},
			# --- ladydevimon3: "Darkness Spear" — Nullify + non-Affliction weaken + poison ------
			# (a) 10 Nullify (barrier, permanent, hostile). (b) THE NEW FIELD: a hostile, damage-type-
			# EXCLUDING damage-dealt weaken — amount -10 (HOSTILE_BY_SIGN) with exclude_types AFFLICTION,
			# so every NON-Affliction hit the target deals is cut by 10 for 1 turn. (c) the manual first
			# instance: 5 Affliction ONLY if the target isn't already carrying Lady's Poison (keyed on
			# the shared name+DAMAGE type, the target's copy). (d) 1 stack of the per-stack permanent
			# poison, name_override'd to the passive's "Lady's Poison" so the stacks MERGE. Order matters:
			# the conditional (c) must precede the stack (d), or the first cast never deals its 5.
			{"name": "Darkness Spear", "target": "enemy", "cooldown": 1, "cost": {"1": 1},
			 "classes": ["Physical", "Harmful", "Instant", "Affliction", "Damaging"], "requires": [],
			 "blocks": [
				{"op": "apply", "to": "target", "effect": {"kind": "barrier", "amount": 10, "turns": -1}},
				{"op": "apply", "to": "target", "effect": {"kind": "damage_boost", "amount": -10, "turns": 1, "exclude_types": ["AFFLICTION"]}},
				{"op": "group", "when": {"cond": "not_has_effect", "name": POISON, "on": "target", "effect": "DAMAGE", "by": "mine"},
				 "blocks": [{"op": "damage", "amount": 5, "damage_type": "AFFLICTION", "to": "target"}]},
				{"op": "apply", "to": "target", "effect": {
					"kind": "damage_over_time", "amount": 5, "damage_type": "AFFLICTION", "turns": -1,
					"stackable": true, "per_stack": true, "display_stacks": true, "name_override": POISON}}]},
			# --- ladydevimon4: "Darkness Wave" — self Invulnerable 1 turn ----------------------
			{"name": "Darkness Wave", "target": "self", "cooldown": 4, "cost": {"4": 1},
			 "classes": ["Mental", "Strategic", "Instant"], "requires": [],
			 "blocks": [
				{"op": "apply", "to": "user", "effect": {"kind": "invulnerable", "turns": 1}}]},
			# --- ladydevimon5: "Lady's Poison" — PASSIVE on_harmful_received --------------------
			# The trigger sits permanent on self; when an enemy uses a Harmful skill on her, the payload
			# runs with LadyDevimon as the applier and to:"target" rebound to the ATTACKER (context.owner),
			# stacking a Lady's Poison on them. The ability is NAMED "Lady's Poison", so the DoT inherits
			# that name with no override — the same name skill 3 forces via name_override, hence they merge.
			{"name": POISON, "target": "self", "cooldown": 0, "cost": {},
			 "classes": ["Passive"], "requires": [],
			 "blocks": [
				{"op": "apply", "to": "user", "effect": {
					"kind": "trigger", "trigger": "on_harmful_received", "turns": -1,
					"then": [
						{"op": "apply", "to": "target", "effect": {
							"kind": "damage_over_time", "amount": 5, "damage_type": "AFFLICTION", "turns": -1,
							"stackable": true, "per_stack": true, "display_stacks": true}}]}}]},
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
	m.start_battle(p1, p2, true, 1010, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

func _cast(caster, ab, targets: Array, m) -> void:
	caster.used_ability = ab
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	ab.execute(caster, m)
	caster.used_ability = null

# A plain Harmful single-target attack owned by `owner` — used both as the DAMAGER whose outgoing
# damage the weaken measures, and as the incoming Harmful skill that trips the passive.
func _attack(name, owner):
	var a := ScriptedAbility.new()
	a.configure({"name": name, "target": "enemy", "blocks": [{"op": "damage", "amount": 5, "to": "target"}]})
	a.ability_name = name
	a.classes = Ability.default_classes()
	a.classes["Harmful"] = true
	a.classes["Instant"] = true
	a.user = owner
	owner.moveset.add_ability(a)
	return a

# The damage `damager` would actually deal for a hit of `dtype`, through the SAME get_true_damage
# resolve_damage calls (the weaken lives on the damager and is summed here). `base` is pre-modifier.
func _dealt(damager, target, attack, base, dtype) -> int:
	damager.used_ability = attack
	var r: int = attack.get_true_damage(damager, target, base, null, dtype)
	damager.used_ability = null
	return r

func _write_fixture(spec: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://authored"))
	var f := FileAccess.open("res://authored/%s.json" % CHAR_ID, FileAccess.WRITE)
	if f == null:
		printerr("  could not write the probe fixture"); return
	f.store_string(JSON.stringify(spec, "\t"))
	f.close()

func _ready():
	print("=== CREATOR ROULETTE 10 — LadyDevimon authored spec ===")
	var spec := _spec()

	# ---------------------------------------------------------------------------
	# 1. VALIDATE through the REAL AuthoredRegistry (on save AND on load).
	# ---------------------------------------------------------------------------
	var direct_errs := AuthoredRegistry.validate_character(spec)
	_check(direct_errs.is_empty(), "validate_character() returns 0 errors: %s" % str(direct_errs))

	_write_fixture(spec)
	AuthoredRegistry.load_all(true)                       # re-validates on load
	var loaded = AuthoredRegistry.get_spec(CHAR_ID)
	_check(loaded != null, "spec loaded from disk (passed validate-on-load)")
	if loaded == null:
		print("=== DONE: %d failure(s) ===" % fails); get_tree().quit(1); return
	_check(AuthoredRegistry.validate_character(loaded).is_empty(), "re-validates cleanly after round-trip")

	# save_spec is the OTHER real write path (client -> server). Exercise it too.
	var save_errs := AuthoredRegistry.save_spec(spec)
	_check(save_errs.is_empty(), "save_spec() writes with 0 errors: %s" % str(save_errs))

	# ---------------------------------------------------------------------------
	# 2. BUILD a real Character (no .gd/.tscn) and confirm the moveset shape.
	# ---------------------------------------------------------------------------
	var s := _fresh_battle(); var m = s["m"]
	var hero = s["allies"][0]
	_check(hero is AuthoredCharacter, "Character.from_character_name built an AuthoredCharacter")
	_check(hero.character_name == "LadyDevimon", "name applied: %s" % hero.character_name)
	var kit = hero.moveset.base_abilities
	# 4 visible actives + 1 Passive = 5 abilities, order [s1,s2,s3,s4,passive].
	_check(kit.size() == 5, "5 abilities built (%d)" % kit.size())
	_check(kit[0].ability_name == "Black Wing" and kit[1].ability_name == "Devil Slap"
		and kit[2].ability_name == "Darkness Spear" and kit[3].ability_name == "Darkness Wave"
		and kit[4].ability_name == POISON,
		"moveset order is [Black Wing, Devil Slap, Darkness Spear, Darkness Wave, Lady's Poison]")
	_check(hero.moveset.display_abilities().size() == 4, "exactly 4 visible board slots (the Passive is off-board)")
	_check(kit[4].classes["Passive"], "Lady's Poison carries the Passive class")

	var s1 = kit[0]; var s2 = kit[1]; var s3 = kit[2]; var s4 = kit[3]
	# Real cost/cooldown copied from abilities_data.json survived the build.
	_check(s1.cooldown == 1 and s2.cooldown == 1 and s3.cooldown == 1 and s4.cooldown == 4,
		"cooldowns match abilities_data.json (1/1/1/4)")
	_check(int(s1.cost()[4]) == 1 and int(s2.cost()[3]) == 1 and int(s3.cost()[1]) == 1 and int(s4.cost()[4]) == 1,
		"costs match abilities_data.json (Random/Blue/Red/Random)")

	# ---------------------------------------------------------------------------
	# 3. THE PASSIVE ACTUALLY STARTED — the on_harmful_received trigger is on her.
	# ---------------------------------------------------------------------------
	_check(hero.has_effect(POISON, EffectType.Type.HARMFUL_RECEIVE_TRIGGER, hero) != null,
		"startup_passives ran: the on_harmful_received trigger sits permanent on LadyDevimon")

	# ---------------------------------------------------------------------------
	# 4. ladydevimon1 — 20 AFFLICTION.
	# ---------------------------------------------------------------------------
	print("-- ladydevimon1: Black Wing --")
	var foe0 = s["foes"][0]
	var h0: int = int(foe0.health.hp)
	_cast(hero, s1, [foe0], m)
	_check(h0 - int(foe0.health.hp) == 20, "Black Wing dealt 20 Affliction (%d -> %d)" % [h0, foe0.health.hp])

	# ---------------------------------------------------------------------------
	# 5. ladydevimon2 — 20 NORMAL + Taunt.
	# ---------------------------------------------------------------------------
	print("-- ladydevimon2: Devil Slap --")
	var foe1 = s["foes"][1]
	var h1: int = int(foe1.health.hp)
	_cast(hero, s2, [foe1], m)
	_check(h1 - int(foe1.health.hp) == 20, "Devil Slap dealt 20 Normal (%d -> %d)" % [h1, foe1.health.hp])
	_check(foe1.get_effects_by_type(EffectType.Type.TAUNT).size() == 1, "Devil Slap Taunted the target")

	# ---------------------------------------------------------------------------
	# 6. ladydevimon3 — Nullify + non-Affliction weaken + conditional first 5 + poison stack.
	# ---------------------------------------------------------------------------
	print("-- ladydevimon3: Darkness Spear --")
	var foe2 = s["foes"][2]
	var foe2_atk = _attack("Sakura Strike", foe2)   # the DAMAGER whose outgoing damage the weaken cuts
	var h2: int = int(foe2.health.hp)
	_cast(hero, s3, [foe2], m)
	# (a) Nullify
	_check(foe2.get_effects_by_type(EffectType.Type.BARRIER).size() == 1, "(a) 10 Nullify applied (BARRIER)")
	# (c) conditional first instance — 5 Affliction on a not-yet-poisoned target, and NOTHING else in
	# skill 3 deals damage, so the whole hp delta is exactly that 5.
	_check(h2 - int(foe2.health.hp) == 5, "(c) first instance dealt 5 Affliction (target wasn't poisoned) (%d -> %d)" % [h2, foe2.health.hp])
	# (d) a Lady's Poison stack merged under the shared name
	var poison2 = foe2.has_effect(POISON, EffectType.Type.DAMAGE, hero)
	_check(poison2 != null, "(d) a Lady's Poison DoT is on the target under the SHARED name")
	_check(poison2 != null and poison2.stack_count() == 1, "(d) 1 stack after one cast (%d)" % (poison2.stack_count() if poison2 else -1))
	# (b) THE NEW FIELD — the hostile, non-Affliction weaken, measured through get_true_damage: a 20
	# NORMAL/PHYSICAL hit the TARGET deals is cut to 10; a 20 AFFLICTION hit is UNCHANGED.
	var wep = foe2.has_effect("Darkness Spear", EffectType.Type.DAMAGE_MOD, hero)
	_check(wep != null and wep.mag == -10, "(b) the weaken applied to the target as a -10 DAMAGE_MOD")
	_check(wep != null and wep.exclusion_targets == [DamageType.Type.AFFLICTION],
		"(b) exclude_types [AFFLICTION] -> exclusion_targets [AFFLICTION]")
	var norm := _dealt(foe2, hero, foe2_atk, 20, DamageType.Type.NORMAL)
	var phys := _dealt(foe2, hero, foe2_atk, 20, DamageType.Type.PHYSICAL)
	var affl := _dealt(foe2, hero, foe2_atk, 20, DamageType.Type.AFFLICTION)
	_check(norm == 10, "(b) the target's 20 NORMAL hit is weakened to 10 (got %d)" % norm)
	_check(phys == 10, "(b) the target's 20 PHYSICAL hit is weakened to 10 (got %d)" % phys)
	_check(affl == 20, "(b) the target's 20 AFFLICTION hit is UNCHANGED — the excluded type is spared (got %d)" % affl)

	# THE MERGE / NAME COUPLING — a SECOND cast must NOT re-deal the 5 (target now poisoned), and the
	# stack must climb to 2. This is the direct proof that name_override + the not_has_effect guard key
	# on the SAME name: get it wrong and either the 5 fires again or a second same-named DoT appears.
	print("-- ladydevimon3: recast (poison already present) --")
	var h2b: int = int(foe2.health.hp)
	_cast(hero, s3, [foe2], m)
	_check(int(foe2.health.hp) == h2b, "recast deals 0 immediate damage — the conditional 5 is gated OFF by the existing poison")
	var poison2b = foe2.has_effect(POISON, EffectType.Type.DAMAGE, hero)
	_check(poison2b != null and poison2b.stack_count() == 2, "recast stacked the SAME Lady's Poison to 2 (%d)" % (poison2b.stack_count() if poison2b else -1))
	# The DoT really ticks 5 per stack through the real tick path.
	var pv0: int = int(foe2.health.hp)
	m.execute_ticking_effect(poison2b)
	_check(pv0 - int(foe2.health.hp) == 10, "2 stacks tick 5 each = 10 Affliction (got %d)" % (pv0 - int(foe2.health.hp)))

	# ---------------------------------------------------------------------------
	# 7. ladydevimon4 — self Invulnerable.
	# ---------------------------------------------------------------------------
	print("-- ladydevimon4: Darkness Wave --")
	_check(hero.get_effects_by_type(EffectType.Type.INVULN).is_empty(), "(setup) LadyDevimon isn't invuln yet")
	_cast(hero, s4, [hero], m)
	_check(hero.get_effects_by_type(EffectType.Type.INVULN).size() == 1, "Darkness Wave made LadyDevimon Invulnerable")

	# ---------------------------------------------------------------------------
	# 8. ladydevimon5 (PASSIVE) — an enemy that hits her gains a STACKING poison. Fresh battle so the
	#    passive poison lands clean (no skill-3 stack in play), proving stacks-per-hit and 5/stack.
	# ---------------------------------------------------------------------------
	print("-- ladydevimon5: Lady's Poison (passive) --")
	var s2b := _fresh_battle(); var m2 = s2b["m"]
	var hero2 = s2b["allies"][0]; var attacker = s2b["foes"][0]
	var atk = _attack("Foe Strike", attacker)
	# The attacker uses a Harmful skill ON LadyDevimon. Drive the receive-trigger dispatch the engine
	# runs after every ability resolves against a target.
	_check(attacker.has_effect(POISON, EffectType.Type.DAMAGE, hero2) == null, "(setup) the attacker has no poison yet")
	attacker.used_ability = atk; attacker.targeter.targets = [hero2]; attacker.targeter.main_target = hero2
	hero2.check_ability_receive_triggers(m2, atk)
	attacker.used_ability = null; attacker.targeter.targets = []
	var ap1 = attacker.has_effect(POISON, EffectType.Type.DAMAGE, hero2)
	_check(ap1 != null, "the ATTACKER gained a Lady's Poison stack from hitting LadyDevimon")
	_check(ap1 != null and ap1.stack_count() == 1, "one hit -> 1 stack (%d)" % (ap1.stack_count() if ap1 else -1))
	# Tick it: 5 per stack.
	var av0: int = int(attacker.health.hp)
	m2.execute_ticking_effect(ap1)
	_check(av0 - int(attacker.health.hp) == 5, "1 stack ticks 5 Affliction (got %d)" % (av0 - int(attacker.health.hp)))
	# A SECOND hit stacks (the trigger re-arms, it is not one-shot).
	attacker.used_ability = atk; attacker.targeter.targets = [hero2]; attacker.targeter.main_target = hero2
	hero2.check_ability_receive_triggers(m2, atk)
	attacker.used_ability = null; attacker.targeter.targets = []
	var ap2 = attacker.has_effect(POISON, EffectType.Type.DAMAGE, hero2)
	_check(ap2 != null and ap2.stack_count() == 2, "a SECOND hit stacks Lady's Poison to 2 (%d)" % (ap2.stack_count() if ap2 else -1))
	var av1: int = int(attacker.health.hp)
	m2.execute_ticking_effect(ap2)
	_check(av1 - int(attacker.health.hp) == 10, "2 stacks tick 5 each = 10 Affliction (got %d)" % (av1 - int(attacker.health.hp)))
	# An ALLY of LadyDevimon that "hits" her must NOT be poisoned (the dispatcher skips ally attackers).
	var ally = s2b["allies"][1]
	var ally_atk = _attack("Ally Bonk", ally)
	ally.used_ability = ally_atk; ally.targeter.targets = [hero2]; ally.targeter.main_target = hero2
	hero2.check_ability_receive_triggers(m2, ally_atk)
	ally.used_ability = null; ally.targeter.targets = []
	_check(ally.has_effect(POISON, EffectType.Type.DAMAGE, hero2) == null,
		"an ALLY attacker is NOT poisoned (the passive skips same-team attackers)")

	# ---------------------------------------------------------------------------
	# 9. Generated presentation — the authored kit produces its own descriptions.
	# ---------------------------------------------------------------------------
	print("-- generated prose --")
	_check(s3.split_desc().size() >= 1, "Darkness Spear auto-describes")
	print("        s1 -> " + str(s1.split_desc()))
	print("        s3 -> " + str(s3.split_desc()))
	print("        s5 -> " + str(kit[4].split_desc()))

	# Tidy the fixture so it can't leak into another suite's load_all.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://authored/%s.json" % CHAR_ID))

	print("=== DONE: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
