extends Node

# ============================================================================
# Creator Phase B, stage 1 — PAYLOAD ADDRESSING, the three new hook rows, and the
# EVENT-CLASS FILTER (`trigger`.scope).
#
#   godot --headless --path <repo> res://training/tests/creator_addressing_probe.tscn
#
# WHAT IS UNDER TEST
#
# 1. ADDRESSING. A trigger payload runs with the effect's APPLIER as the acting user, so `user`
#    means the caster and `target` means whoever tripped the hook. Neither is the character
#    CARRYING the effect, so a trigger planted on an enemy could not aim at that enemy at all.
#    Two new selectors, legal only inside a `then` payload:
#      holder   := context.effect.target — the bearer, on all 15 hooks
#      affected := context.target        — the event's patient
#    They differ on exactly two hooks (on_damage_dealt, healing-given), which is why this is two
#    selectors and not one. Every case below pairs the new selector against the OLD one on the
#    same board, so a binding that quietly resolves to the caster fails an assertion rather than
#    passing for the wrong reason.
#
# 2. RE-ENTRANCY (hazard 2). on_hp_changed fires from receive_damage (character_component.gd:531)
#    AND receive_healing (:1112), and receive_healing calls it UNCONDITIONALLY — even for a heal
#    the max-HP clamp reduced to zero. The dispatchers' only brake is `if eff.triggered: continue`,
#    and NOTHING in the engine sets that flag (three hand-written kits set it themselves:
#    frieza2.gd:102, frieza3.gd:49, machinedramon3.gd:47).
#    MEASURED, with the latch edited out of BlockRunner._build_trigger by hand:
#      * DAMAGE form — run 07's two-block shape, a self-held on_hp_changed trigger whose payload
#        is `damage 10 to holder`. A single 5-damage poke took the holder 100 -> 0. 10 authored,
#        100 taken; it stopped only because the holder died. The same 10x over-run run 07
#        measured on on_damage_dealt.
#      * HEAL form — the same trigger with `heal 10 to holder` on a FULL-HP holder. No terminator
#        exists at all: "SCRIPT ERROR: Stack overflow. Check for infinite recursion in your
#        script." followed by a flood of engine-level "Stack underflow! (Engine Bug)". That is a
#        live match aborting, from two authored blocks.
#    BlockRunner now latches each trigger effect's payload against re-entering itself; the
#    assertions below pin the latched numbers (15 and full-HP respectively).
#
# 3. trigger.scope. Reuses COUNTER_SCOPES verbatim. It is rejected on the four hooks dispatched
#    through QueryContext.from_effect_end, whose `source` is the trigger effect itself rather than
#    a skill — a scope there would filter on nothing.
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

# One battle per assertion group. Effects persist and HP does not reset, so sharing a board
# between groups would let one case decide another's answer.
func _fresh() -> Dictionary:
	var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
	var p1 := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var p2 := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 7788, BattleManager.MatchType.BOT)
	return {"m": m, "allies": p1.team.characters, "foes": p2.team.characters}

# An authored skill, built the way AuthoredCharacter builds one. Harmful+Damaging by default so
# the application path is the hostile one when it aims at an enemy.
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

# Plant a trigger effect carrying `payload` on `bearer`, applied by `applier`.
func _plant(applier, bearer, m, hook: String, payload: Array, extra := {}) -> ScriptedAbility:
	var eff := {"kind": "trigger", "trigger": hook, "turns": 20, "then": payload}
	for k in extra:
		eff[k] = extra[k]
	var ab := _mk({"name": "Plant %s" % hook, "target": "enemy",
		"blocks": [{"op": "apply", "to": "target", "effect": eff}]}, applier)
	_cast(applier, ab, [bearer], m)
	return ab

# Trip ACTION_RECEIVE_TRIGGER on `who`, exactly as check_ability_use_triggers does for each of a
# caster's targets (scripts/character_component.gd:1494).
func _receive_skill(who, from_char, m, harmful := true) -> void:
	var incoming := _mk({"name": "Incoming %s" % ("Harmful" if harmful else "Helpful"),
		"target": "enemy", "blocks": [{"op": "damage", "amount": 0}]}, from_char, harmful)
	who.check_ability_receive_triggers(m, incoming)


func _ready():
	print("=== creator payload-addressing + hook-row probe ===")

	# =====================================================================================
	# GROUP 1 — `holder` is the BEARER, on a self-held, an ally-held and an ENEMY-held trigger.
	#
	# The enemy-held case is the one that was unreachable: `user` inside a payload is the
	# APPLIER, so "when this enemy is hit, hurt them" fired backwards onto the caster. Each
	# case is paired with the same spec written `to: "user"` on a twin character, so a `holder`
	# that silently resolved to the caster would make the two indistinguishable and the paired
	# assertion would fail.
	# =====================================================================================
	var g1 := _fresh()
	var m1 = g1["m"]
	var a1 = g1["allies"][0]      # applier / holder in the self-held case
	var b1 = g1["allies"][1]      # ally bearer
	var e1 = g1["foes"][0]        # enemy bearer
	var e1b = g1["foes"][1]       # enemy bearer for the `to: "user"` control

	var hit := [{"op": "damage", "amount": 12, "to": "holder"}]
	var hit_user := [{"op": "damage", "amount": 12, "to": "user"}]

	_plant(a1, a1, m1, "on_skill_received", hit)
	_plant(a1, b1, m1, "on_skill_received", hit)
	_plant(a1, e1, m1, "on_skill_received", hit)
	_plant(a1, e1b, m1, "on_skill_received", hit_user)

	# SELF-HELD.
	var a_hp: int = a1.health.hp
	_receive_skill(a1, e1, m1)
	_check(a1.health.hp == a_hp - 12,
		"self-held: `holder` is the bearer (%d -> %d, -12)" % [a_hp, a1.health.hp])

	# ALLY-HELD. The bearer is not the applier, so this separates "holder" from "user".
	a_hp = a1.health.hp
	var b_hp: int = b1.health.hp
	_receive_skill(b1, e1, m1)
	_check(b1.health.hp == b_hp - 12,
		"ally-held: the payload hits the ALLY carrying it (%d -> %d)" % [b_hp, b1.health.hp])
	_check(a1.health.hp == a_hp, "...and NOT the applier (%d unchanged)" % a1.health.hp)

	# ENEMY-HELD — red before addressing existed.
	a_hp = a1.health.hp
	var e_hp: int = e1.health.hp
	_receive_skill(e1, a1, m1)
	_check(e1.health.hp == e_hp - 12,
		"enemy-held: the payload hits the ENEMY carrying it (%d -> %d)" % [e_hp, e1.health.hp])
	_check(a1.health.hp == a_hp,
		"...and NOT the applier — this is the case that used to fire backwards (%d unchanged)" % a1.health.hp)

	# THE CONTROL that makes the three assertions above able to fail: the identical spec written
	# `to: "user"` still aims at the applier, on an enemy-held trigger.
	a_hp = a1.health.hp
	var e1b_hp: int = e1b.health.hp
	_receive_skill(e1b, a1, m1)
	_check(a1.health.hp == a_hp - 12,
		"control: the same payload written `to: \"user\"` hits the APPLIER (%d -> %d)" % [a_hp, a1.health.hp])
	_check(e1b.health.hp == e1b_hp, "...and leaves the bearer alone (%d unchanged)" % e1b.health.hp)

	# =====================================================================================
	# GROUP 2 — `affected` on on_damage_dealt is the VICTIM, `holder` is the dealer.
	#
	# This is the pair that forces two selectors rather than one: on this hook the bearer and
	# the patient are DIFFERENT characters, and a single binding is wrong whichever one it picks.
	# =====================================================================================
	var g2 := _fresh()
	var m2 = g2["m"]
	var dealer = g2["allies"][0]
	var dealer2 = g2["allies"][1]
	var victim = g2["foes"][0]
	var victim2 = g2["foes"][1]

	# name_override, deliberately: effect_name() falls back to the SOURCE ABILITY'S name, and the
	# trigger effect itself is named after that same ability — so without a distinct name the
	# "did the payload land here?" question is answered by the trigger's own presence.
	var vuln := {"kind": "vulnerability", "amount": 10, "turns": 3, "name_override": "Probe Vuln"}
	_plant(dealer, dealer, m2, "on_damage_dealt",
		[{"op": "apply", "to": "affected", "effect": vuln}])
	_plant(dealer2, dealer2, m2, "on_damage_dealt",
		[{"op": "apply", "to": "holder", "effect": vuln}])

	var punch := _mk({"name": "Probe Punch", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 5}]}, dealer)
	dealer.used_ability = punch
	dealer.deal_ability_damage(punch, 5, victim, DamageType.Type.NORMAL)
	dealer.used_ability = null

	_check(victim.has_any_effect("Probe Vuln"),
		"`affected` on on_damage_dealt lands on the VICTIM")
	_check(not dealer.has_any_effect("Probe Vuln"),
		"...and NOT on the dealer, which is what a single `holder` binding would have done")

	var punch2 := _mk({"name": "Probe Punch Two", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 5}]}, dealer2)
	dealer2.used_ability = punch2
	dealer2.deal_ability_damage(punch2, 5, victim2, DamageType.Type.NORMAL)
	dealer2.used_ability = null

	_check(dealer2.has_any_effect("Probe Vuln"),
		"control: `holder` on the same hook lands on the DEALER — the two selectors are not the same binding")
	_check(not victim2.has_any_effect("Probe Vuln"),
		"...and leaves the victim alone")

	# =====================================================================================
	# GROUP 3 — a DEAD holder mid-payload resolves to NOBODY, never to the caster.
	#
	# Two blocks: the first kills the bearer, the second must find no one. A "sensible default"
	# fallback to `user` would make the second block hit the applier — the run-07 defect in
	# reverse, and a self-kill the author never wrote.
	# =====================================================================================
	var g3 := _fresh()
	var m3 = g3["m"]
	var a3 = g3["allies"][0]
	var e3 = g3["foes"][0]
	e3.health.hp = 12
	_plant(a3, e3, m3, "on_skill_received", [
		{"op": "damage", "amount": 40, "to": "holder"},
		{"op": "damage", "amount": 30, "to": "holder"}])

	var a3_hp: int = a3.health.hp
	_receive_skill(e3, a3, m3)
	_check(e3.dead or e3.health.hp <= 0, "the first block killed the holder (hp %d, dead=%s)" % [e3.health.hp, str(e3.dead)])
	_check(a3.health.hp == a3_hp,
		"THE GUARD: the second block hit NOBODY — the applier took no damage (%d unchanged)" % a3.health.hp)

	# Positive control on the same board: a LIVING holder takes both blocks, so the assertion
	# above is about death and not about `holder` being inert.
	var e3b = g3["foes"][1]
	_plant(a3, e3b, m3, "on_skill_received", [
		{"op": "damage", "amount": 8, "to": "holder"},
		{"op": "damage", "amount": 9, "to": "holder"}])
	var e3b_hp: int = e3b.health.hp
	a3_hp = a3.health.hp
	_receive_skill(e3b, a3, m3)
	_check(e3b.health.hp == e3b_hp - 17,
		"control: a LIVING holder takes BOTH blocks (%d -> %d, -17)" % [e3b_hp, e3b.health.hp])
	_check(a3.health.hp == a3_hp, "...and the applier still takes nothing")

	# =====================================================================================
	# GROUP 4 — HAZARD 2: on_hp_changed re-entrancy.
	#
	# Run 07's two-block shape, self-held. UNLATCHED (measured by hand, with the latch edited
	# out of BlockRunner._build_trigger): a single 5-damage poke took the holder 100 -> 0 —
	# 10 damage authored, 100 taken, terminating only because the holder died. The heal form has
	# no terminator at all: receive_healing calls check_health_change_triggers even when the
	# max-HP clamp reduced the heal to zero, so a full-HP self-heal payload recurses until the
	# stack goes.
	# =====================================================================================
	var g4 := _fresh()
	var m4 = g4["m"]
	var a4 = g4["allies"][0]
	var e4 = g4["foes"][0]
	_plant(a4, a4, m4, "on_hp_changed", [{"op": "damage", "amount": 10, "to": "holder"}])

	var poke := _mk({"name": "Probe Poke", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 5}]}, e4)
	e4.used_ability = poke
	var a4_hp: int = a4.health.hp
	e4.deal_ability_damage(poke, 5, a4, DamageType.Type.NORMAL)
	e4.used_ability = null
	var lost: int = a4_hp - a4.health.hp
	_check(lost == 15,
		"on_hp_changed fires ONCE per event: 5 poke + 10 payload = %d lost (unlatched this was %d, i.e. dead)" % [lost, a4_hp])
	_check(not a4.dead, "the holder is alive — the payload did not run itself to death")

	# The unterminated form: a heal payload on a FULL-HP holder. receive_healing calls the hook
	# whatever the clamp did, so without the latch this never returns at all.
	var g4b := _fresh()
	var m4b = g4b["m"]
	var a4b = g4b["allies"][0]
	var e4b = g4b["foes"][0]
	_plant(a4b, a4b, m4b, "on_hp_changed", [{"op": "heal", "amount": 10, "to": "holder"}])
	var poke2 := _mk({"name": "Probe Poke Two", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 5}]}, e4b)
	e4b.used_ability = poke2
	e4b.deal_ability_damage(poke2, 5, a4b, DamageType.Type.NORMAL)
	e4b.used_ability = null
	_check(a4b.health.hp == a4b.get_modified_max_hp(),
		"the heal form terminates and heals back to full (%d) instead of recursing forever" % a4b.health.hp)

	# =====================================================================================
	# GROUP 5 — the three new hook rows actually fire, and `holder` is right on each.
	# =====================================================================================
	var g5 := _fresh()
	var m5 = g5["m"]
	var a5 = g5["allies"][0]
	var e5 = g5["foes"][0]
	var e5b = g5["foes"][1]

	# on_stunned — STUN_RECEIVED_TRIGGER, fired from apply_effect (:206) on the STUNNED
	# character, which is the bearer. 3 of the 4 shipped users are ally-held, so aim at `holder`.
	_plant(a5, e5, m5, "on_stunned", [{"op": "damage", "amount": 11, "to": "holder"}])
	var stun_src := _mk({"name": "Probe Stun", "target": "enemy",
		"blocks": [{"op": "apply", "to": "target", "effect": {"kind": "stun", "turns": 1}}]}, a5)
	var e5_hp: int = e5.health.hp
	_cast(a5, stun_src, [e5], m5)
	_check(e5.health.hp == e5_hp - 11,
		"on_stunned fires on the stunned bearer (%d -> %d)" % [e5_hp, e5.health.hp])

	# on_skill_received — ACTION_RECEIVE_TRIGGER. All 3 shipped users are enemy-held.
	_plant(a5, e5b, m5, "on_skill_received", [{"op": "damage", "amount": 9, "to": "holder"}])
	var e5b_hp: int = e5b.health.hp
	_receive_skill(e5b, a5, m5)
	_check(e5b.health.hp == e5b_hp - 9,
		"on_skill_received fires on the bearer (%d -> %d)" % [e5b_hp, e5b.health.hp])

	# =====================================================================================
	# GROUP 6 — `trigger`.scope, the event-class filter.
	#
	# A matching class fires; a non-matching one stays silent. Both halves on one board, so
	# "stays silent" cannot pass because the trigger was never planted.
	# =====================================================================================
	var g6 := _fresh()
	var m6 = g6["m"]
	var a6 = g6["allies"][0]
	var e6 = g6["foes"][0]
	_plant(a6, e6, m6, "on_skill_received", [{"op": "damage", "amount": 7, "to": "holder"}],
		{"scope": "harmful"})

	var e6_hp: int = e6.health.hp
	_receive_skill(e6, a6, m6, false)                  # a HELPFUL skill: outside the scope
	_check(e6.health.hp == e6_hp,
		"scope 'harmful': a Helpful skill does NOT fire the trigger (%d unchanged)" % e6.health.hp)
	_receive_skill(e6, a6, m6, true)                   # a HARMFUL skill: inside it
	_check(e6.health.hp == e6_hp - 7,
		"scope 'harmful': a Harmful skill DOES fire it (%d -> %d)" % [e6_hp, e6.health.hp])

	# A raw class list, the korra1-shaped form counter.scope already accepts.
	var e6b = g6["foes"][1]
	_plant(a6, e6b, m6, "on_skill_received", [{"op": "damage", "amount": 6, "to": "holder"}],
		{"scope": ["Mental"]})
	var e6b_hp: int = e6b.health.hp
	_receive_skill(e6b, a6, m6, true)                  # Harmful, but Physical — not Mental
	_check(e6b.health.hp == e6b_hp,
		"scope ['Mental']: a Physical skill does not match the raw class list (%d unchanged)" % e6b.health.hp)

	# =====================================================================================
	# GROUP 7 — the VALIDATOR rules. Every rejection is paired with the spec that must pass.
	# =====================================================================================
	var ok_scope := {"name": "Scoped", "target": "self", "classes": ["Strategic", "Instant"],
		"blocks": [{"op": "apply", "to": "user", "effect": {
			"kind": "trigger", "trigger": "on_skill_used", "scope": "harmful", "turns": 3,
			"then": [{"op": "damage", "amount": 5, "to": "holder"}]}}]}
	_check(BlockValidator.validate_ability(ok_scope).is_empty(),
		"scope on on_skill_used validates clean")

	var bad_scope := ok_scope.duplicate(true)
	bad_scope["blocks"][0]["effect"]["trigger"] = "on_turn_start"
	_check(_mentions(BlockValidator.validate_ability(bad_scope), "scope"),
		"scope on a turn hook is REJECTED (from_effect_end carries no skill to filter on)")

	var bad_scope2 := ok_scope.duplicate(true)
	bad_scope2["blocks"][0]["effect"]["trigger"] = "on_hp_changed"
	_check(_mentions(BlockValidator.validate_ability(bad_scope2), "scope"),
		"...and on on_hp_changed too")

	var bad_scope3 := ok_scope.duplicate(true)
	bad_scope3["blocks"][0]["effect"]["scope"] = "not_a_scope"
	_check(_mentions(BlockValidator.validate_ability(bad_scope3), "scope"),
		"an unknown scope name is rejected")

	# Placement: the payload selectors are legal ONLY inside a `then`.
	var top_holder := {"name": "Top Holder", "target": "enemy", "classes": ["Physical", "Harmful"],
		"blocks": [{"op": "damage", "amount": 5, "to": "holder"}]}
	_check(_mentions(BlockValidator.validate_ability(top_holder), "holder"),
		"`holder` as a TOP-LEVEL block's `to` is rejected, and the error names it")

	var grouped_holder := {"name": "Grouped Holder", "target": "enemy",
		"classes": ["Physical", "Harmful"],
		"blocks": [{"op": "group", "blocks": [{"op": "damage", "amount": 5, "to": "affected"}]}]}
	_check(_mentions(BlockValidator.validate_ability(grouped_holder), "affected"),
		"`affected` inside a top-level GROUP is rejected too — the flag rides down")

	var payload_group := {"name": "Payload Group", "target": "self",
		"classes": ["Strategic", "Instant"],
		"blocks": [{"op": "apply", "to": "user", "effect": {
			"kind": "trigger", "trigger": "on_turn_end", "turns": 3, "then": [
				{"op": "group", "blocks": [{"op": "damage", "amount": 5, "to": "holder"}]}]}}]}
	_check(BlockValidator.validate_ability(payload_group).is_empty(),
		"control: `holder` inside a group inside a payload VALIDATES — the flag rides down both ways")

	var counter_holder := {"name": "Counter Holder", "target": "self",
		"classes": ["Strategic", "Instant"],
		"blocks": [{"op": "apply", "to": "user", "effect": {
			"kind": "counter", "scope": "harmful", "turns": 3,
			"then": [{"op": "damage", "amount": 5, "to": "holder"}]}}]}
	_check(BlockValidator.validate_ability(counter_holder).is_empty(),
		"control: `holder` inside a COUNTER payload validates as well")

	# =====================================================================================
	# GROUP 8 — generated prose. `describe()` is never written by hand, so the generated
	# sentence IS the contract a player reads off the card.
	# =====================================================================================
	var prose_ab := ScriptedAbility.new()
	prose_ab.configure({"target": "self", "blocks": [{"op": "apply", "to": "user", "effect": {
		"kind": "trigger", "trigger": "on_skill_used", "scope": "harmful", "turns": 3,
		"then": [{"op": "damage", "amount": 10, "to": "holder"},
				 {"op": "heal", "amount": 5, "to": "affected"}]}}]})
	prose_ab.ability_name = "Prose Probe"
	prose_ab.classes = {"Passive": false}
	var prose: String = prose_ab.describe(null)
	print("    prose: " + prose)
	# The GUARD is unchanged — a scoped trigger must still name the class it waits for, or the card
	# reads "whenever they use a skill" off a trigger that only fires on Harmful ones. Only the
	# CASING moved, and it moved because there is now ONE scope renderer instead of two: this
	# assertion encoded _scope_phrase's wording (shortcut resolved to its CLASS NAME, "Harmful"),
	# while creator_interception_probe:690/710 encoded _scope_noun's ("harmful", the shortcut word
	# the author typed) for the same authored value on the same kind of card. They could not both
	# stay. The shortcut word won: it is what the author wrote, it is what two shipped assertions
	# already required, and a raw class LIST still prints its class names verbatim (asserted in
	# advreview_phaseb_probe section C, "Physical or Energy").
	_check(prose.find("harmful skill") != -1,
		"a scoped trigger NAMES the class in its prose")
	_check(prose.find("the holder") != -1 and prose.find("the character it happened to") != -1,
		"both payload selectors read as English nouns")

	var hooks_ab := ScriptedAbility.new()
	hooks_ab.configure({"target": "self", "blocks": [
		{"op": "apply", "to": "user", "effect": {"kind": "trigger", "trigger": "on_hp_changed",
			"turns": 3, "then": [{"op": "heal", "amount": 5, "to": "holder"}]}},
		{"op": "apply", "to": "user", "effect": {"kind": "trigger", "trigger": "on_stunned",
			"turns": 3, "then": [{"op": "heal", "amount": 5, "to": "holder"}]}},
		{"op": "apply", "to": "user", "effect": {"kind": "trigger", "trigger": "on_skill_received",
			"turns": 3, "then": [{"op": "heal", "amount": 5, "to": "holder"}]}}]})
	hooks_ab.ability_name = "Hook Prose"
	hooks_ab.classes = {"Passive": false}
	var hook_prose: String = hooks_ab.describe(null)
	print("    prose: " + hook_prose)
	for phrase in ["whenever their health changes", "when they are stunned", "whenever a skill is used on them"]:
		_check(hook_prose.find(phrase) != -1, "the new hook prints '%s'" % phrase)

	# The palette the editor builds its pickers from must carry the new lists, or stage 3 has
	# nothing to render and the fields become invisible-but-required.
	_check(BlockSchema.PAYLOAD_SELECTORS.size() == 2, "PAYLOAD_SELECTORS exports both names")
	for h in BlockSchema.SCOPED_TRIGGERS:
		_check(BlockSchema.TRIGGERS.has(h), "SCOPED_TRIGGERS entry '%s' is a real hook" % h)
	for h in ["on_hp_changed", "on_stunned", "on_skill_received"]:
		_check(BlockSchema.trigger_hook_id(h) >= 0, "'%s' resolves to an EffectType" % h)

	# =====================================================================================
	# GROUP 9 — LIVE MATCH. Everything above pokes the hooks by hand; this runs a full
	# bot-vs-bot match with a scoped trigger + an addressing payload planted on every
	# character of one team, so the payload fires inside the real turn machinery
	# (start_round_loop, the tick pass, the wire snapshot) rather than off a direct call.
	#
	# What it is watching for: the trigger firing at all in live play, the match reaching an
	# ordinary conclusion, and no [RECONCILE] drift warning in the process output (the run
	# script greps for that; a drift here would mean the payload moved state the snapshot
	# does not carry).
	#
	# SEED THE GLOBAL RNG, or this group is a coin flip. The match seed passed to start_battle
	# only covers battle.roll; the random bot picks its ability with a bare `randi()`
	# (scripts/player_component.gd, _random_bot_act step 4), which that seed does not reach. So
	# whether the enemy ever aims a Harmful skill at the warded team was luck: an adversarial
	# review measured this assertion at 0/3 on one sweep and 2/3 on the next three. A green run
	# proved nothing and a red run proved nothing. Seeding here (GROUP 9 is last, so nothing
	# downstream inherits it) makes the whole group reproducible.
	# =====================================================================================
	seed(20260804)
	var m9 := BattleManager.new(); m9.name = "BattleManager"; m9.shadow_mode = true; add_child(m9)
	var p9a := _build_player("BotPlayer", ["naruto", "gon", "orihime"])
	var p9b := _build_player("BotEnemy", ["eren", "misaka", "sakura"])
	# Connected BEFORE start_battle: the first turn_started fires from inside it.
	var live_running := [true]
	var pending := [-1]
	m9.turn_started.connect(func(_is_player): pending[0] = 0)
	m9.waiting_for_opponent.connect(func(): pending[0] = 1)
	m9.match_ended.connect(func(_won): live_running[0] = false)
	m9.start_battle(p9a, p9b, true, 31337, BattleManager.MatchType.BOT)

	# Permanent + system so the proof survives the death cleanse and every expiry; this is the
	# probe's evidence, not gameplay.
	var ward := [{"op": "apply", "to": "holder", "effect": {
		"kind": "mark", "turns": -1, "name_override": "Ward Proc",
		"system": true, "remove_on_death": false}}]
	for c in p9a.team.characters:
		_plant(c, c, m9, "on_skill_received", ward, {"scope": "harmful"})

	var turns := 0
	while live_running[0] and turns < 40:
		if pending[0] == -1:
			break                      # no side is owed a turn: the signal chain stalled
		var side: int = pending[0]
		pending[0] = -1
		turns += 1
		if side == 1:
			# The enemy seat's energy latch, handled exactly as bot_trainer._dispatch does
			# (training/bot_trainer.gd:396-407) — generating unconditionally double-feeds it.
			if not m9.acting_energy_prepared:
				m9.generate_team_energy(m9.enemy.team, m9.went_second)
			m9.acting_energy_prepared = false
			m9.went_second = false
			p9b.perform_turn_random(m9, null, 1)
		else:
			p9a.perform_turn_random(m9, null, 0)

	_check(turns > 1, "live match: the turn loop actually ran (%d turns)" % turns)
	var procced := 0
	for c in p9a.team.characters:
		if c.has_any_effect("Ward Proc"):
			procced += 1
	_check(procced > 0,
		"live match: the scoped trigger's `holder` payload landed in real turn flow (%d/3 carry the proof)" % procced)

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _mentions(errs: Array, needle: String) -> bool:
	for e in errs:
		if str(e).find(needle) != -1:
			return true
	return false
