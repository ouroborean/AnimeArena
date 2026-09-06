extends Node

# ============================================================================
# CREATOR RULING 2 — the `event` VALUE READING (payload-only).
#
# QueryContext.value already carries the magnitude of the event a trigger/counter
# payload is reacting to (damage received/dealt, healing given), set by
# from_trigger_source. The `event` reading surfaces it to the block layer, which
# is what makes "reflect/counter for the amount I just took" authorable. It
# composes with Phase E's base/per/cap and is legal ONLY inside a reactive `then`
# (rejected with a message anywhere else — there is no event out there to read).
#
#   godot --headless --path <repo> res://training/tests/creator_event_reading_probe.tscn
#
# HAND-REVERSALS (each turns exactly its block red; quoted in the task writeup):
#   * NEUTER THE READING:  in block_runner._resolve_reading, make the `event` arm
#                  `return 0` instead of returning `_payload_event`
#                  => the 100% reflect deals 0 (section 2 goes red), while the
#                     board readings (section is unaffected) stay green.
#   * DROP THE PAYLOAD GATE:  in block_validator._validate_reading, delete the
#                  `if read == "event" and not in_payload` arm
#                  => `event` in a top-level damage validates (section 3's
#                     negative stops firing; its positive control still passes).
#   * DON'T PASS THE VALUE:  in block_runner._build_trigger, drop the third arg to
#                  set_payload_addressing (back to holder/affected only)
#                  => _payload_event stays null, the reflect deals 0 (section 2).
#   * DROP THE DIVISOR (Item 1):  in block_runner._amount, change `total` back to
#                  `base + per * _resolve_reading(...)` (drop the `/ div`)
#                  => the div:2 reflect deals the full 30, not the 15 half (section 6a-6d
#                     go red), while the div-ABSENT 100% reflect (2a) stays green.
#   * DROP THE EVENT-HOOK GATE (Item 2):  in block_validator._validate_reading, change the
#                  reject test `not event_where in BlockSchema.EVENT_TRIGGERS` back to the old
#                  `not in_payload`
#                  => `event` on a counter/recurring/on_stunned payload validates again (the
#                     section 3b negatives stop firing), while the damage/healing-hook positives
#                     (2, 3, 3b control B) stay green.
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

func _apply(caster, spec: Dictionary, to: String, targets: Array, m, harmful := true) -> void:
	var ab := _mk({"name": "Apply " + str(spec.get("kind", "")), "target": "enemy",
		"blocks": [{"op": "apply", "to": to, "effect": spec}]}, caster, harmful)
	_cast(caster, ab, targets, m)

# A valid ability spec wrapper, for validator checks.
func _ab_spec(blocks: Array) -> Dictionary:
	return {"name": "Probe", "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Harmful", "Damaging"], "blocks": blocks, "requires": []}

func _has_err(errs: Array, needle: String) -> bool:
	for e in errs:
		if needle in str(e):
			return true
	return false

# A reflect-for-the-amount payload: on_damage_received, deal (per*event)/div back at the attacker,
# clamped to `cap`. `to:"target"` inside the payload is whoever tripped the trigger — the attacker.
# `div` (default 1) is written ONLY when non-identity so the pre-div callers keep byte-identical specs.
func _reflect_trigger(per: int, cap: int, div := 1) -> Dictionary:
	var amt := {"base": 0, "per": per, "cap": cap, "each": {"read": "event"}}
	if div != 1:
		amt["div"] = div
	return {"kind": "trigger", "trigger": "on_damage_received", "turns": 5,
		"then": [{"op": "damage", "to": "target", "amount": amt}]}

func _ready():
	seed(4242)   # global RNG floor for the live-match assertions (hard rule)
	print("=== CREATOR RULING 2 — event value reading ===")

	# self_check() stays green — READINGS grew by one member; the constant-vs-constant invariants
	# Phase B/C/E rely on must be untouched.
	_check(BlockSchema.self_check().is_empty(), "self_check() is green after adding the event reading")

	# ==================================================================================
	# 1. `event` is a member of the closed READINGS enum (so it ships in the palette and
	#    the validator recognises it at all).
	# ==================================================================================
	_check("event" in BlockSchema.READINGS, "event is a member of READINGS")

	# ==================================================================================
	# 2. RUNTIME — reflect the exact damage taken back at the attacker (100%, capped-half,
	#    and a 2x multiplier). THE must-have: "reflect the amount I just took".
	# ==================================================================================

	# --- 2a. 100% reflect: DEF carries the trigger, ATK hits DEF for 30, ATK takes 30. ---
	var s = _fresh(); var m = s["m"]; var defender = s["allies"][0]; var attacker = s["foes"][0]
	defender.health.max_hp = 200; defender.health.hp = 200
	attacker.health.max_hp = 200; attacker.health.hp = 200
	_apply(defender, _reflect_trigger(1, 999), "user", [defender], m, false)
	var atk_hp0: int = int(attacker.health.hp)
	# ATK deals a clean 30 NORMAL to DEF — no DR/shields, so damage received == 30 == the event.
	var hit := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 30, "to": "target"}]}, attacker)
	_cast(attacker, hit, [defender], m)
	var reflected: int = atk_hp0 - int(attacker.health.hp)
	_check(reflected == 30, "100%% reflect: attacker takes exactly the 30 it dealt — took %d" % reflected)

	# --- 2b. capped 'half': same 30 hit, reflect clamped at 15 -> attacker takes 15. ---
	s = _fresh(); m = s["m"]; defender = s["allies"][0]; attacker = s["foes"][0]
	defender.health.max_hp = 200; defender.health.hp = 200
	attacker.health.max_hp = 200; attacker.health.hp = 200
	_apply(defender, _reflect_trigger(1, 15), "user", [defender], m, false)
	atk_hp0 = int(attacker.health.hp)
	var hit2 := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 30, "to": "target"}]}, attacker)
	_cast(attacker, hit2, [defender], m)
	reflected = atk_hp0 - int(attacker.health.hp)
	_check(reflected == 15, "capped reflect: a cap of 15 over a 30 hit deals the 15 half — took %d" % reflected)

	# --- 2c. per as a genuine multiplier: per=2 over a 20 hit -> attacker takes 40. ---
	s = _fresh(); m = s["m"]; defender = s["allies"][0]; attacker = s["foes"][0]
	defender.health.max_hp = 200; defender.health.hp = 200
	attacker.health.max_hp = 200; attacker.health.hp = 200
	_apply(defender, _reflect_trigger(2, 999), "user", [defender], m, false)
	atk_hp0 = int(attacker.health.hp)
	var hit3 := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, attacker)
	_cast(attacker, hit3, [defender], m)
	reflected = atk_hp0 - int(attacker.health.hp)
	_check(reflected == 40, "per=2 reflect: 2x a 20 hit deals 40 back (per is a genuine multiplier) — took %d" % reflected)

	# --- 2d. NEGATIVE CONTROL for 2a: WITHOUT the trigger on DEF, ATK takes nothing back. ---
	s = _fresh(); m = s["m"]; defender = s["allies"][0]; attacker = s["foes"][0]
	defender.health.max_hp = 200; defender.health.hp = 200
	attacker.health.max_hp = 200; attacker.health.hp = 200
	atk_hp0 = int(attacker.health.hp)
	var hit4 := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 30, "to": "target"}]}, attacker)
	_cast(attacker, hit4, [defender], m)
	_check(atk_hp0 - int(attacker.health.hp) == 0, "control: no reflect trigger -> attacker takes 0 back (the reflect is the trigger, not the hit)")

	# ==================================================================================
	# 3. VALIDATOR — `event` is PAYLOAD-ONLY. Rejected in a top-level amount, accepted
	#    inside a reactive `then`. Every negative paired with a positive control.
	# ==================================================================================

	# NEGATIVE: event in a TOP-LEVEL scaling damage amount is rejected, and the message names it.
	var top_event := _ab_spec([{"op": "damage", "to": "target",
		"amount": {"base": 0, "per": 1, "cap": 99, "each": {"read": "event"}}}])
	var e_top := BlockValidator.validate_ability(top_event)
	_check(_has_err(e_top, "event"), "NEGATIVE: event in a top-level amount is rejected by name")
	_check(not _has_err(e_top, "must be one of"), "  ...and it is rejected as PAYLOAD-ONLY, not as an unknown reading")

	# POSITIVE CONTROL 1: the SAME shape with read:'stacks' validates top-level (so the rejection is
	# the payload gate, not the scaling shape).
	var top_stacks := _ab_spec([{"op": "damage", "to": "target",
		"amount": {"base": 0, "per": 1, "cap": 99, "each": {"read": "stacks", "of": "all_enemies"}}}])
	_check(BlockValidator.validate_ability(top_stacks).is_empty(),
		"control: the same scaling amount reading 'stacks' validates top-level")

	# POSITIVE CONTROL 2: event INSIDE a trigger payload validates clean — the whole point.
	var payload_event := _ab_spec([{"op": "apply", "to": "user", "effect": _reflect_trigger(1, 999)}])
	var e_pay := BlockValidator.validate_ability(payload_event)
	_check(e_pay.is_empty(), "POSITIVE: event inside an on_damage_received payload validates clean — %s" % str(e_pay))

	# ==================================================================================
	# 3b. ITEM 2 — `event` is gated PER HOOK, not merely payload-vs-not. It resolves to
	#     QueryContext.value, which ONLY the damage-dealt / damage-received / healing-given
	#     hooks thread a magnitude into (BlockSchema.EVENT_TRIGGERS). A counter payload
	#     (from_counter_check), a recurring payload (from_effect_end) and a magnitude-less
	#     trigger (on_stunned, from_trigger_source with no qvalue) all leave value at 0, so
	#     `event` there is the per-hook LIE — a card that says "reflect the amount" doing
	#     nothing. Rejected by name on those; accepted on the damage/healing family. Controls
	#     pair every negative.
	# ==================================================================================
	# NEGATIVE: event in a COUNTER payload is rejected (from_counter_check carries no magnitude).
	# This is the case section 3 USED to (wrongly) assert validated — the per-hook lie Item 2 closes.
	var counter_event := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "counter", "scope": "harmful", "on": "incoming", "turns": 5,
			"then": [{"op": "damage", "to": "target",
				"amount": {"base": 0, "per": 1, "cap": 99, "each": {"read": "event"}}}]}}])
	var e_counter := BlockValidator.validate_ability(counter_event)
	_check(_has_err(e_counter, "no magnitude on 'counter'"),
		"NEGATIVE: event in a counter payload is rejected — no magnitude on that hook")
	_check(not _has_err(e_counter, "must be one of"),
		"  ...rejected as a magnitude-less hook, not as an unknown reading")

	# NEGATIVE: event in a RECURRING payload is rejected (from_effect_end carries no magnitude).
	var recurring_event := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "recurring", "turns": 5,
			"then": [{"op": "damage", "to": "target",
				"amount": {"base": 0, "per": 1, "cap": 99, "each": {"read": "event"}}}]}}])
	_check(_has_err(BlockValidator.validate_ability(recurring_event), "no magnitude on 'recurring'"),
		"NEGATIVE: event in a recurring payload is rejected — no magnitude on that hook")

	# NEGATIVE: event on a MAGNITUDE-LESS trigger hook (on_stunned) is rejected AND names the hook.
	var stun_event := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "trigger", "trigger": "on_stunned", "turns": 5,
			"then": [{"op": "damage", "to": "target",
				"amount": {"base": 0, "per": 1, "cap": 99, "each": {"read": "event"}}}]}}])
	_check(_has_err(BlockValidator.validate_ability(stun_event), "no magnitude on 'on_stunned'"),
		"NEGATIVE: event on on_stunned is rejected — that trigger threads no magnitude")

	# POSITIVE CONTROL A: the SAME on_stunned payload reading a BOARD count (stacks) validates — so the
	# rejection is the per-hook EVENT gate, not the hook, the payload, or the scaling shape.
	var stun_stacks := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "trigger", "trigger": "on_stunned", "turns": 5,
			"then": [{"op": "damage", "to": "target",
				"amount": {"base": 0, "per": 1, "cap": 99, "each": {"read": "stacks", "of": "all_enemies"}}}]}}])
	_check(BlockValidator.validate_ability(stun_stacks).is_empty(),
		"control: the same on_stunned payload reading 'stacks' validates (the gate is event-per-hook)")

	# POSITIVE CONTROL B: event on on_healing_given (a magnitude-carrying hook) validates — the gate
	# ACCEPTS the whole damage/healing family, not just on_damage_received (section 3's positive).
	var heal_event := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "trigger", "trigger": "on_healing_given", "turns": 5,
			"then": [{"op": "damage", "to": "target",
				"amount": {"base": 0, "per": 1, "cap": 99, "each": {"read": "event"}}}]}}])
	_check(BlockValidator.validate_ability(heal_event).is_empty(),
		"POSITIVE: event on on_healing_given validates — a magnitude-carrying hook")

	# ==================================================================================
	# 4. event as a COMPARE value follows the same gate (a reactive `when` may read it,
	#    a top-level `when` may not).
	# ==================================================================================
	# NEGATIVE: event compare in a TOP-LEVEL when is rejected.
	var top_when := _ab_spec([{"op": "damage", "amount": 10, "to": "target",
		"when": {"cond": "compare", "value": {"read": "event"}, "op": "gt", "than": 5}}])
	_check(_has_err(BlockValidator.validate_ability(top_when), "event"),
		"NEGATIVE: an event compare in a top-level 'when' is rejected")
	# POSITIVE: event compare inside a payload's `when` validates — "only reflect if I took > 5".
	var pay_when := _ab_spec([{"op": "apply", "to": "user",
		"effect": {"kind": "trigger", "trigger": "on_damage_received", "turns": 5,
			"then": [{"op": "damage", "to": "target", "amount": 10,
				"when": {"cond": "compare", "value": {"read": "event"}, "op": "gt", "than": 5}}]}}])
	_check(BlockValidator.validate_ability(pay_when).is_empty(),
		"POSITIVE: an event compare inside a payload 'when' validates")

	# ==================================================================================
	# 5. Generated prose mentions the event (the card is the contract, not describe()).
	# ==================================================================================
	var prose_ab := _mk(payload_event, s["allies"][1])
	var lines: Array = prose_ab.split_desc()
	var joined := " ".join(lines)
	_check("triggering event" in joined, "generated prose names the triggering event: '%s'" % joined)

	# ==================================================================================
	# 6. FRACTIONAL SCALING (Item 1) — the `div` divisor. `per` is an INT, so "reflect 50%"
	#    (per:0.5) was UNBUILDABLE; (base + per*count) / div makes any clean ratio authorable.
	#    div runs BEFORE the cap, so `cap` still bounds the FINAL reflected amount.
	# ==================================================================================

	# --- 6a. reflect 50% (THE owner's literal example): per:1, div:2 over a 30 hit -> 15. ---
	s = _fresh(); m = s["m"]; defender = s["allies"][0]; attacker = s["foes"][0]
	defender.health.max_hp = 200; defender.health.hp = 200
	attacker.health.max_hp = 200; attacker.health.hp = 200
	_apply(defender, _reflect_trigger(1, 999, 2), "user", [defender], m, false)
	atk_hp0 = int(attacker.health.hp)
	var hit50 := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 30, "to": "target"}]}, attacker)
	_cast(attacker, hit50, [defender], m)
	reflected = atk_hp0 - int(attacker.health.hp)
	_check(reflected == 15, "div:2 reflect: half of a 30 hit is 15 (per:0.5 made buildable) — took %d" % reflected)

	# --- 6b. reflect 25%: div:4 over a 40 hit -> 10. ---
	s = _fresh(); m = s["m"]; defender = s["allies"][0]; attacker = s["foes"][0]
	defender.health.max_hp = 200; defender.health.hp = 200
	attacker.health.max_hp = 200; attacker.health.hp = 200
	_apply(defender, _reflect_trigger(1, 999, 4), "user", [defender], m, false)
	atk_hp0 = int(attacker.health.hp)
	var hit25 := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 40, "to": "target"}]}, attacker)
	_cast(attacker, hit25, [defender], m)
	reflected = atk_hp0 - int(attacker.health.hp)
	_check(reflected == 10, "div:4 reflect: a quarter of a 40 hit is 10 — took %d" % reflected)

	# --- 6c. 150% is div COMPOSED with per: per:3, div:2 (= 1.5x) over a 20 hit -> 30. ---
	s = _fresh(); m = s["m"]; defender = s["allies"][0]; attacker = s["foes"][0]
	defender.health.max_hp = 200; defender.health.hp = 200
	attacker.health.max_hp = 200; attacker.health.hp = 200
	_apply(defender, _reflect_trigger(3, 999, 2), "user", [defender], m, false)
	atk_hp0 = int(attacker.health.hp)
	var hit150 := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 20, "to": "target"}]}, attacker)
	_cast(attacker, hit150, [defender], m)
	reflected = atk_hp0 - int(attacker.health.hp)
	_check(reflected == 30, "per:3 div:2 reflect: 1.5x a 20 hit is 30 (div composes with per) — took %d" % reflected)

	# --- 6d. the CAP bounds the POST-div amount: div:2 + cap:10 over a 40 hit -> min(40/2,10) = 10,
	#         NOT min(40,10)/2 = 5. Proves div runs BEFORE the cap (so _amount_hint stays honest at cap). ---
	s = _fresh(); m = s["m"]; defender = s["allies"][0]; attacker = s["foes"][0]
	defender.health.max_hp = 200; defender.health.hp = 200
	attacker.health.max_hp = 200; attacker.health.hp = 200
	_apply(defender, _reflect_trigger(1, 10, 2), "user", [defender], m, false)
	atk_hp0 = int(attacker.health.hp)
	var hitcap := _mk({"name": "Clean Hit", "target": "enemy",
		"blocks": [{"op": "damage", "amount": 40, "to": "target"}]}, attacker)
	_cast(attacker, hitcap, [defender], m)
	reflected = atk_hp0 - int(attacker.health.hp)
	_check(reflected == 10, "cap bounds the divided amount: (40/2)=20 capped at 10 -> 10 (div before cap) — took %d" % reflected)

	# POSITIVE CONTROL for the whole section: div ABSENT is the identity — section 2a's 100% reflect
	# deals the full 30 off the SAME shape. So 6a's 15 is unambiguously the divisor at work, not the cap.

	# ==================================================================================
	# 7. VALIDATOR — `div` is an optional positive int >= 1 (the crash/sign guard), NO upper cap.
	# ==================================================================================
	# NEGATIVE: div:0 is a divide-by-zero in _amount — rejected by name, with the crash-guard message.
	var e_zero := BlockValidator.validate_ability(_ab_spec([{"op": "apply", "to": "user", "effect": _reflect_trigger(1, 99, 0)}]))
	_check(_has_err(e_zero, ".div"), "NEGATIVE: div:0 is rejected by name (divide-by-zero guard)")
	_check(_has_err(e_zero, "at least 1"), "  ...as the crash guard ('at least 1'), not a balance cap")
	# NEGATIVE: a negative div would flip an unsigned amount's sign — rejected.
	_check(_has_err(BlockValidator.validate_ability(_ab_spec([{"op": "apply", "to": "user", "effect": _reflect_trigger(1, 99, -2)}])), ".div"),
		"NEGATIVE: a negative div is rejected (it would flip the sign)")
	# POSITIVE CONTROL: div:2 validates clean, so the rejection is the <1 guard, not the div key itself.
	var e_two := BlockValidator.validate_ability(_ab_spec([{"op": "apply", "to": "user", "effect": _reflect_trigger(1, 99, 2)}]))
	_check(e_two.is_empty(), "POSITIVE: div:2 (half) validates clean — %s" % str(e_two))
	# POSITIVE CONTROL: NO invented upper cap — a large div validates (the no-balance-cap rule).
	_check(BlockValidator.validate_ability(_ab_spec([{"op": "apply", "to": "user", "effect": _reflect_trigger(1, 99, 50)}])).is_empty(),
		"POSITIVE: div:50 validates — div has no invented upper cap")
	# The allowlist grew by EXACTLY div: an unknown key alongside div is still rejected as a security boundary.
	_check(_has_err(BlockValidator.validate_ability(_ab_spec([{"op": "damage", "to": "target",
		"amount": {"base": 0, "per": 1, "cap": 99, "div": 2, "wat": 1, "each": {"read": "stacks", "of": "all_enemies"}}}])), "wat"),
		"NEGATIVE: an unknown key alongside div is still rejected (allowlist grew by div only)")

	# ==================================================================================
	# 8. PROSE — a div reads "divided by N"; div ABSENT prints nothing (identity, existing cards unchanged).
	# ==================================================================================
	var dp := " ".join(_mk(_ab_spec([{"op": "apply", "to": "user", "effect": _reflect_trigger(1, 45, 2)}]), s["allies"][2]).split_desc())
	_check("divided by 2" in dp, "PROSE: a div:2 amount reads 'divided by 2' — '%s'" % dp)
	# NEGATIVE pair: the div-ABSENT reflect payload says nothing about dividing.
	var noprose := " ".join(_mk(payload_event, s["allies"][2]).split_desc())
	_check(not ("divided by" in noprose), "PROSE control: a div-absent amount omits the divisor clause — '%s'" % noprose)

	print("=== DONE: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
