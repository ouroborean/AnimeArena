extends Node

# Effect visibility probe.
#
# `system` does two unrelated jobs: it makes an effect survive the cleanses (clear_non_system_effects
# keeps ONLY system effects on a dead holder; the death cleanse spares a system effect whose
# remove_on_death is false) AND it strips the effect from the wire, hiding it from BOTH players. The
# owner's rule is that only genuinely hidden information, or things neither player benefits from
# seeing, should be hidden — so `Effect.display_system` opts an effect out of the hiding while
# keeping the survival semantics.
#
# This probe asserts against the REAL wire serializer (_serialize_wire_team, the only producer of
# snapshot.sides[].team[].effects) in both directions: the player-facing machinery must appear, and
# the genuinely blank bookkeeping must still not.
#   godot --headless --path <repo> res://training/tests/effect_visibility_probe.tscn

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build_player(u, names):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	var is_enemy = (u == "BotEnemy")
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _cast(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.used_ability = ab
	ab.execute(caster, m)
	return ab

# Every effect the wire actually carries for one character, as [{name, effect_type, description}].
func _wire(m, team, index: int) -> Array:
	return m._serialize_wire_team(team)[index]["effects"]

func _find(rows: Array, nm: String, etype: int) -> Variant:
	for r in rows:
		if String(r["name"]) == nm and int(r["effect_type"]) == etype:
			return r
	return null

func _has(rows: Array, nm: String) -> bool:
	for r in rows:
		if String(r["name"]) == nm:
			return true
	return false

func _ready():
	print("=== effect visibility probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["yoruichi", "frieza", "stark"])
	var p2 = _build_player("BotEnemy", ["killua", "misaka", "gray"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	var y = p1.team.characters[0]
	var f = p1.team.characters[1]
	var s = p1.team.characters[2]
	var foe = p2.team.characters[0]

	# ============================================================ Yoruichi
	_cast(m, y, 0, [y])                      # Shunko: Gather — plants a watcher on every enemy
	var foe_rows = _wire(m, p2.team, 0)
	var brand = _find(foe_rows, "Shunko: Gather", EffectType.Type.ACTION_USE_TRIGGER)
	_check(brand != null, "Gather's per-enemy brand reaches the wire (it is the defender's whole read)")
	if brand != null:
		_check(bool(brand["system"]) and bool(brand["display_system"]),
			"...and it kept system (it must survive clear_non_system_effects on a dead enemy)")
		_check("5 Piercing damage" in String(brand["description"]),
			"...with the LIVE damage in its tooltip: %s" % String(brand["description"]))
		_check("Paralyzes their cooldowns" in String(brand["description"]),
			"...and the Paralyze spelled out")
		_check(not ("Shatters" in String(brand["description"])),
			"...and no Shatter clause while Black Cat is down")

	_cast(m, y, 0, [y])                      # stack 2
	foe_rows = _wire(m, p2.team, 0)
	brand = _find(foe_rows, "Shunko: Gather", EffectType.Type.ACTION_USE_TRIGGER)
	var brand_txt := "" if brand == null else String(brand["description"])
	_check(brand != null and "10 Piercing damage" in brand_txt,
		"the brand's tooltip tracks the stack count live (%s)" % brand_txt)

	_cast(m, y, 2, [y])                      # Black Cat Warrior Princess
	foe_rows = _wire(m, p2.team, 0)
	brand = _find(foe_rows, "Shunko: Gather", EffectType.Type.ACTION_USE_TRIGGER)
	brand_txt = "" if brand == null else String(brand["description"])
	_check(brand != null and "20 Piercing damage" in brand_txt and "Shatters" in brand_txt,
		"Black Cat's +10 and Shatter show up in the brand's tooltip (%s)" % brand_txt)
	var y_rows = _wire(m, p1.team, 0)
	var banner = _find(y_rows, "Black Cat Warrior Princess", EffectType.Type.MARK)
	_check(banner != null, "Black Cat puts a mark on Yoruichi saying what it actually does")
	if banner != null:
		_check("10 more damage" in String(banner["description"]) and "Shatters" in String(banner["description"]),
			"...naming both halves of the buff: %s" % String(banner["description"]))
	_check(_find(y_rows, "Black Cat Warrior Princess", EffectType.Type.ABILITY_SWAP) != null,
		"...alongside the swap effect, which only says which skill replaced which")
	_check(_find(y_rows, "Shunko: Gather", EffectType.Type.MARK) != null,
		"her stack counter is on the wire too")

	# ============================================================ Frieza
	_cast(m, f, 0, [foe])                    # Death Beam, use 1 of 3
	var f_rows = _wire(m, p1.team, 1)
	var focus = _find(f_rows, "Death Beam Focus", EffectType.Type.MARK)
	_check(focus != null, "the Death Beam count toward Barrage is VISIBLE (it was caster-only)")
	if focus != null:
		_check(bool(focus["display_mag"]) and int(focus["mag"]) == 1, "...with the count on the badge (mag %d)" % int(focus["mag"]))
		_check(String(focus["visibility"]) == "all", "...to both players, not just Frieza's side")

	_cast(m, f, 1, [f])                      # Nova Strike
	f_rows = _wire(m, p1.team, 1)
	_check(_find(f_rows, "Nova Strike", EffectType.Type.TICKING_TRIGGER) != null,
		"Nova Strike's payout is a visible ticking step, not hidden machinery")
	_check(_find(f_rows, "Nova Strike", EffectType.Type.SHIELD) != null, "...and the Shield itself is on the wire")
	var decay = _find(f_rows, "Nova Strike Decay", EffectType.Type.MARK)
	_check(decay != null and String(decay["visibility"]) == "all",
		"the Shield decay counter is visible to both players")
	var emperor = _find(f_rows, "Last Emperor", EffectType.Type.ON_DEATH_TRIGGER)
	_check(emperor != null, "Last Emperor is on the wire (it needs system to outlive the death that fires it)")
	if emperor != null:
		_check(bool(emperor["system"]) and bool(emperor["display_system"]),
			"...with system + display_system, so it still survives the death cleanse")

	# ============================================================ Stark
	var ally_rows = _wire(m, p1.team, 0)     # Yoruichi is one of Stark's allies
	var umbrella = _find(ally_rows, "Superhuman Resilience", EffectType.Type.DAMAGE_REDIRECT)
	_check(umbrella != null, "who is under Stark's umbrella is visible — it decides who to attack")
	if umbrella != null:
		_check(not ("0.0" in String(umbrella["description"])),
			"...and does NOT show the factory's false zero-percent text: " + String(umbrella["description"]))
		_check("redirected to Stark" in String(umbrella["description"]) and "20" in String(umbrella["description"]),
			"...it names the destination and the pool")

	# ---- and the genuine machinery is still hidden from BOTH sides ----
	var s_rows = _wire(m, p1.team, 2)
	_check(not _has(s_rows, "Superhuman Resilience") or _find(s_rows, "Superhuman Resilience", EffectType.Type.START_OF_TURN_TRIGGER) == null,
		"Stark's budget-refill ticker stays hidden (pure bookkeeping)")
	# character/stark.gd sources BOTH slot-contest triggers to base_abilities[5], so they serialize
	# under that ability's name — "Cleaving Light", NOT "Axe Smash" (the slot they rewrite). Naming
	# the wrong one made this assertion pass unconditionally, which is exactly the kind of check that
	# looks like coverage and is not: prove the triggers really exist first, then that neither reaches
	# the wire.
	var live_machinery := 0
	for et in [EffectType.Type.START_OF_TURN_TRIGGER, EffectType.Type.DAMAGE_DEALT_TRIGGER]:
		for e in s.effects.get_effects_by_type(et):
			if e.source != null and String(e.source.ability_name) == "Cleaving Light":
				live_machinery += 1
	_check(live_machinery == 2, "Stark's two slot re-evaluation triggers are actually installed (got %d)" % live_machinery)
	for et in [EffectType.Type.START_OF_TURN_TRIGGER, EffectType.Type.DAMAGE_DEALT_TRIGGER]:
		_check(_find(s_rows, "Cleaving Light", et) == null,
			"...and neither reaches the wire (effect_type %d)" % int(et))
	_cast(m, s, 2, [s])                      # Cowardice
	s_rows = _wire(m, p1.team, 2)
	_check(_find(s_rows, "Cowardice", EffectType.Type.MARK) != null, "Cowardice's public mark is on the wire")
	_check(_find(s_rows, "Cowardice", EffectType.Type.TICKING_TRIGGER) != null, "...and its regen ticking step")
	_check(_find(s_rows, "Cowardice", EffectType.Type.DAMAGE_REDIRECT) == null,
		"...but its reverse-redirect machinery is NOT duplicated onto the wire")
	_check(_find(s_rows, "Cowardice", EffectType.Type.START_OF_TURN_TRIGGER) == null,
		"...nor its blank budget refill")

	# ---- nothing that reaches the wire may carry an empty tooltip ----
	var blanks: Array = []
	for team in [p1.team, p2.team]:
		var rows_all = m._serialize_wire_team(team)
		for ch in rows_all:
			for r in ch["effects"]:
				if String(r["description"]).strip_edges() == "":
					blanks.append(String(r["name"]) + "/" + str(r["effect_type"]))
	_check(blanks.is_empty(), "no serialized effect has a blank tooltip (%s)" % [blanks])

	print("=== %s ===" % ("ALL PASS" if fails == 0 else "%d FAILURES" % fails))
	get_tree().quit(0 if fails == 0 else 1)
