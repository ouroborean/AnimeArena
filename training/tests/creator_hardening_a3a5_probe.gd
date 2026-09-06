extends Node

# Creator hardening probe — A3 (Passive validator rules + permanent-effect survival)
# and A5 (the retired `and_targeter` flag).
#   godot --headless --path <repo> res://training/tests/creator_hardening_a3a5_probe.tscn
#
# A3's premise had been READ but never OBSERVED. The editor's blank ability seeds a bare
# damage block with no `to`; `to` defaults to "target" (BlockRunner._block_targets), and
# "target" reads user.targeter.targets — which is empty at battle start, because
# Character.startup_passives runs every Passive before anyone has clicked anything. So the
# first section builds that EXACT spec, runs it through a real BattleManager, and measures
# the damage it deals. Everything after it depends on that number being 0.

var fails := 0
var passes := 0

func _check(c, l):
	if c:
		passes += 1
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

# --- fixtures ----------------------------------------------------------------
# The editor's own blank ability, verbatim from webclient/app/app.js CREATOR_BLANK_ABILITY.
# Copied rather than referenced on purpose: if the editor's seed changes, this probe should
# keep asserting what the OLD seed did until somebody re-reads it.
func _blank(n: int) -> Dictionary:
	return {"name": "Skill %d" % n, "target": "enemy", "cooldown": 0, "cost": {},
		"classes": ["Instant", "Harmful", "Damaging"],
		"blocks": [{"op": "damage", "amount": 15, "damage_type": "NORMAL"}], "requires": []}

# The blank ability with `Passive` ticked — the two clicks that produce the inert skill.
func _blank_passive() -> Dictionary:
	var p := _blank(5)
	p["name"] = "Blank Passive"
	p["classes"] = ["Instant", "Harmful", "Damaging", "Passive"]
	return p

func _spec(id: String, passive: Dictionary) -> Dictionary:
	return {"id": id, "name": "Hardening Probe", "author": "a3a5_probe", "status": "testing",
		"colors": [0], "description": "probe fixture", "abilities":
			[_blank(1), _blank(2), _blank(3), _blank(4), passive]}

# A Passive carrying one authored block, with the four filler actives around it.
func _passive_spec(id: String, blocks: Array) -> Dictionary:
	var p := {"name": "Probe Passive", "target": "self", "cooldown": 0, "cost": {},
		"classes": ["Passive"], "requires": [], "blocks": blocks}
	return _spec(id, p)

func _mk_authored(spec: Dictionary):
	# The registry's own construction path (AuthoredRegistry.build_character), called
	# directly so a spec the validator REJECTS can still be run — which is exactly what
	# the red case needs.
	var c = load("res://blocks/authored_character.tscn").instantiate()
	c.configure(spec)
	return c

func _build_player(u: String, first, names: Array) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	var is_enemy: bool = (u == "BotEnemy")
	if first != null:
		p.recruit_character(first, is_enemy)
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _total_damage_taken(m) -> int:
	var n := 0
	for c in m.all_characters():
		n += c.health.max_hp - c.health.hp
	return n

func _errs_of(def: Dictionary, spec: Dictionary) -> Array:
	return BlockValidator.validate_ability(def, spec["abilities"])

func _mentions(errs: Array, needle: String) -> bool:
	for e in errs:
		if str(e).findn(needle) != -1:
			return true
	return false

func _ready():
	print("=== creator hardening probe: A3 (passives) + A5 (and_targeter) ===")
	_observe_empty_target_chain()
	_passive_validator_rules()
	_permanent_effect_survival()
	_and_targeter_retired()
	print("=== probe done: %d passed, %d failure(s) ===" % [passes, fails])
	get_tree().quit(fails)

# --- A3, part 1: OBSERVE the empty-target chain ------------------------------
func _observe_empty_target_chain():
	print("--- the blank ability with Passive ticked ---")
	var spec := _spec("auth_a3blank", _blank_passive())
	var hero = _mk_authored(spec)

	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 := _build_player("BotPlayer", hero, ["naruto", "gon"])
	var p2 := _build_player("BotEnemy", null, ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var observed := _total_damage_taken(m)
	print("  OBSERVED: total damage on the board after startup_passives = %d" % observed)
	_check(observed == 0,
		"THE BLANK PASSIVE IS WHOLLY INERT — 0 damage dealt at battle start (observed %d)" % observed)

	# ...and it stays inert when run by hand with a genuinely empty targeter, which is the
	# state startup_passives calls it in.
	var passive = hero.moveset.base_abilities[4]
	_check(passive.ability_name == "Blank Passive", "(setup) the Passive is moveset index 4")
	hero.targeter.targets = []
	hero.targeter.main_target = null
	hero.used_ability = passive
	var before := _total_damage_taken(m)
	passive.execute(hero, m)
	_check(_total_damage_taken(m) == before,
		"...and re-running it with an empty targeter still deals nothing")

	# The prose the author reads promises the damage the skill never deals. This is the
	# whole reason the rule is worth having.
	var prose := ""
	for seg in passive.split_desc():
		prose += (seg[0] if seg is Array else str(seg)) + " "
	print("  OBSERVED: generated prose = '%s'" % prose.strip_edges())
	_check(prose.find("15") != -1,
		"...while its generated prose promises 15 damage — prose and behaviour disagree")

	m.queue_free()

# --- A3, part 2: the validator rules -----------------------------------------
func _passive_validator_rules():
	print("--- Passive validator rules ---")
	var blank := _spec("auth_a3blank", _blank_passive())
	var blank_errs := _errs_of(blank["abilities"][4], blank)
	_check(not blank_errs.is_empty() and _mentions(blank_errs, "battle start"),
		"the blank Passive is REJECTED, naming the game rule (%s)" % str(blank_errs))

	var explicit := _passive_spec("auth_a3t", [{"op": "damage", "amount": 15, "to": "target"}])
	var explicit_errs := _errs_of(explicit["abilities"][4], explicit)
	_check(not explicit_errs.is_empty() and _mentions(explicit_errs, "battle start"),
		"an explicit to:'target' on a Passive is REJECTED too (%s)" % str(explicit_errs))

	var user_to := _passive_spec("auth_a3u", [{"op": "apply", "to": "user",
		"effect": {"kind": "damage_reduction", "amount": 5, "turns": -1}}])
	_check(_errs_of(user_to["abilities"][4], user_to).is_empty(),
		"to:'user' on a Passive validates — the shape 91 of the 93 shipped passives use")

	# NOT banned: 14 of the 93 shipped passives plant hostile effects at battle start, so a
	# rule that rejected this would invent a restriction the game does not have.
	var hostile := _passive_spec("auth_a3e", [{"op": "apply", "to": "all_enemies",
		"effect": {"kind": "mark", "turns": -1, "text": "Brand"}}])
	_check(_errs_of(hostile["abilities"][4], hostile).is_empty(),
		"to:'all_enemies' on a Passive is ALLOWED (flagged for human review, not banned)")

	# The condition-filtered selectors build their own pool and never read the targeter.
	var filtered := _passive_spec("auth_a3f", [{"op": "apply", "to": "any_enemy",
		"when": {"cond": "hp_above", "value": 0},
		"effect": {"kind": "mark", "turns": -1, "text": "Brand"}}])
	_check(_errs_of(filtered["abilities"][4], filtered).is_empty(),
		"a condition-filtered selector on a Passive validates (it builds its own pool)")

	# A `group` is not a hiding place: its children run at battle start too.
	var grouped := _passive_spec("auth_a3g", [{"op": "group", "blocks":
		[{"op": "damage", "amount": 15}]}])
	_check(_mentions(_errs_of(grouped["abilities"][4], grouped), "battle start"),
		"the rule RECURSES into a group — a bare damage block inside one is still rejected")

	# ...but a trigger PAYLOAD is a different clock. BlockRunner.set_explicit_targets rebinds
	# "target" to whoever tripped the trigger, so "target" is correct there and banning it
	# would make the most useful passive shape unauthorable.
	var payload := _passive_spec("auth_a3p", [{"op": "apply", "to": "user", "effect":
		{"kind": "trigger", "trigger": "on_harmful_received", "turns": -1,
		 "then": [{"op": "damage", "amount": 10, "to": "target"}]}}])
	_check(_errs_of(payload["abilities"][4], payload).is_empty(),
		"to:'target' INSIDE a trigger payload on a Passive is still legal (%s)" %
			str(_errs_of(payload["abilities"][4], payload)))

	# An op with no `to` at all cannot be wrong about one.
	var energy := _passive_spec("auth_a3n", [{"op": "gain_energy", "amount": 1}])
	_check(_errs_of(energy["abilities"][4], energy).is_empty(),
		"an op that takes no 'to' (gain_energy) is untouched by the rule")

	# The rule must not leak onto ordinary skills: a normal ability's default `to` is
	# correct, and 4 of the editor's own blank skills are exactly this shape.
	var normal := _spec("auth_a3norm", _blank_passive())
	_check(_errs_of(normal["abilities"][0], normal).is_empty(),
		"a NON-Passive block with no 'to' still validates — the rule does not leak")

# --- A3, part 3: permanent passive effects survive a cleanse AND a revive -----
func _permanent_effect_survival():
	print("--- permanent Passive effects ---")
	# name_override on all three, not `text`: add_effect dedups on (effect_name, type, user)
	# and effect_name() falls back to the SOURCE ABILITY's name, so three marks from one
	# Passive would otherwise share a name and merge into one.
	var spec := _passive_spec("auth_a3perm", [
		{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": -1, "name_override": "Probe Brand"}},
		{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": 2, "name_override": "Probe Timer"}},
		{"op": "apply", "to": "user", "effect": {"kind": "mark", "turns": -1,
			"name_override": "Author Choice", "cleansable": true}}])
	var hero = _mk_authored(spec)
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 := _build_player("BotPlayer", hero, ["naruto", "gon"])
	var p2 := _build_player("BotEnemy", null, ["eren", "misaka", "sakura"])
	m.start_battle(p1, p2, true, 909, BattleManager.MatchType.BOT)

	var brand = _find_named(hero, "Probe Brand")
	var timer = _find_named(hero, "Probe Timer")
	var chosen = _find_named(hero, "Author Choice")
	_check(brand != null and timer != null and chosen != null,
		"(setup) the Passive applied all three marks at battle start")
	if brand == null or timer == null or chosen == null:
		m.queue_free()
		return

	_check(brand.system and not brand.remove_on_death and not brand.cleansable,
		"a turns:-1 Passive effect is auto-set system + remove_on_death:false + cleansable:false")
	_check(brand.display_system,
		"...and display_system, so surviving the cleanse does not also hide it from both players")
	_check(not timer.system and timer.cleansable and timer.remove_on_death,
		"a TIMED Passive effect is untouched — the auto-set keys on permanence, not on Passive")
	_check(chosen.cleansable,
		"an explicit cleansable:true is RESPECTED — the auto-set fills a default, it does not overrule")

	# Survival case 1: a buff-strip.
	hero.effects.cleanse_all_ally_effects(hero)
	_check(_find_named(hero, "Probe Brand") != null,
		"SURVIVAL 1: the permanent mark survives a buff-strip")
	_check(_find_named(hero, "Author Choice") == null,
		"...while the author's opt-in mark is stripped, so the assertion above can fail")

	# Survival case 2: death + revive. cleanse_death_effects runs BOTH death sweeps —
	# effects the dying character cast (system + remove_on_death) and cleansable effects
	# on them — so this is the case that needs all three fields.
	hero.die()
	hero.dead = false
	hero.health.set_health(50)
	_check(_find_named(hero, "Probe Brand") != null,
		"SURVIVAL 2: the permanent mark survives death + revive")

	m.queue_free()

func _find_named(c, nm: String):
	for e in c.effects._effects:
		if e.effect_name() == nm:
			return e
	return null

# --- A5: and_targeter is retired ---------------------------------------------
func _and_targeter_retired():
	print("--- A5: and_targeter ---")
	_check(not "and_targeter" in BlockValidator.ABILITY_FLAGS,
		"and_targeter is gone from ABILITY_FLAGS, so the palette export no longer offers it")

	var spec := _spec("auth_a5", _blank_passive())
	var flagged: Dictionary = spec["abilities"][0].duplicate(true)
	flagged["and_targeter"] = true
	var errs := BlockValidator.validate_ability(flagged, spec["abilities"])
	_check(_mentions(errs, "and_targeter"),
		"a saved spec carrying and_targeter is REJECTED on save (%s)" % str(errs))

	# The remaining four flags must still work — retiring one must not empty the row.
	var keeps: Dictionary = spec["abilities"][1].duplicate(true)
	keeps["selfless"] = true
	keeps["accurate"] = true
	keeps["invisible"] = true
	keeps["stunnable"] = false
	_check(BlockValidator.validate_ability(keeps, spec["abilities"]).is_empty(),
		"the other four flags (selfless/accurate/invisible/stunnable) still validate")

	# A hand-edited file on disk can still CARRY the field; the built ability must ignore it.
	var carrier := _spec("auth_a5c", _blank_passive())
	carrier["abilities"][0]["and_targeter"] = true
	carrier["abilities"][1]["selfless"] = true
	var built = _mk_authored(carrier)
	var ordered = built.moveset.base_abilities
	_check(ordered[0].and_targeter == false,
		"...and _build_moveset never writes it through, so a hand-edited file cannot re-enable it")
	_check(ordered[1].selfless == true,
		"(control) the same build path still writes `selfless` through")
