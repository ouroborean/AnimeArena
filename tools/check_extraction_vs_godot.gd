# READ-ONLY equivalence probe: does data/*.json match what the LIVE Godot server would
# actually produce? Writes NOTHING and touches no server state.
#
# tools/reference_data.py proves data/ matches the .gd SOURCE by parsing it. This proves the
# other half — that parsing the source is the same as running it. Run it once after any change
# to the extractor; the Python check is the one you run routinely (it needs no Godot).
#
#   "<godot>" --headless --path . --script res://tools/check_extraction_vs_godot.gd
#
# Exit 1 on any mismatch.
extends SceneTree

var failures := 0
var checks := 0


func _init():
	var chars = _json("res://data/characters/character_lists.json")
	_eq("char_name_list", CharacterDatabase.char_name_list(), chars["char_name_list"])
	_eq("starter_character_list", CharacterDatabase.starter_character_list(), chars["starter_character_list"])
	_eq("starter_squads", CharacterDatabase.starter_squads(), chars["starter_squads"])

	# Universe enum ordinals — persisted in save data, so this one is load-bearing.
	var uni_json = _json("res://data/nexus/universe_enum.json")["ordinals"]
	var uni_live := {}
	for key in CharacterConcept.Universe:
		uni_live[key] = CharacterConcept.Universe[key]
	_eq("CharacterConcept.Universe ordinals", uni_live, uni_json)

	# by_universe(): keys are enum ordinals; JSON can only key by string, so stringify.
	var live_by_uni = CharacterDatabase.by_universe()
	var by_uni := {}
	for k in live_by_uni:
		by_uni[str(k)] = live_by_uni[k]
	_eq("by_universe()", by_uni, _json("res://data/characters/by_universe.json")["by_universe_ordinal"])

	var bh = load("res://components/bucket_handler.gd").new()
	var concepts = _json("res://data/nexus/all_chars.json")["concepts"]
	_eq("all_chars size", bh.all_chars.size(), concepts.size())
	var concept_mismatch := 0
	var first_bad := ""
	for path in bh.all_chars:
		var c = bh.all_chars[path]
		if not concepts.has(path):
			concept_mismatch += 1
			if first_bad == "":
				first_bad = path + " (absent from JSON)"
			continue
		var j = concepts[path]
		var portrait = "" if c.portrait_texture == null else c.portrait_texture.resource_path
		if j["name"] != c.character_name or j["description"] != c.description \
				or int(j["universe_ordinal"]) != int(c.universe) or j["portrait"] != portrait:
			concept_mismatch += 1
			if first_bad == "":
				first_bad = "%s live=[%s|%s|%d|%s] json=[%s|%s|%d|%s]" % [
					path, c.character_name, c.description, int(c.universe), portrait,
					j["name"], j["description"], int(j["universe_ordinal"]), j["portrait"]]
	_eq("all_chars field-by-field mismatches" + ("" if first_bad == "" else "  first: " + first_bad),
			0, concept_mismatch)
	_eq("PERMANENT_EXCLUDED", bh.PERMANENT_EXCLUDED,
			_json("res://data/nexus/nexus_tables.json")["permanent_excluded"])
	bh.free()

	var b = load("res://scripts/bounty.gd").new()
	var bj = _json("res://data/bounty/bounty_tables.json")
	_eq("bounty.mission_types", b.mission_types, bj["mission_types"])
	_eq("bounty.winning_patterns", b.winning_patterns, bj["winning_patterns"])
	_eq("bounty.archetypes", b.archetypes, bj["archetypes"])
	_eq("bounty.categories", b.categories, bj["categories"])
	b.free()

	var r = load("res://components/rank_component.gd").new()
	var rj = _json("res://data/ladder/rank_tables.json")
	_eq("rank.rp_thresholds", _by_tier_name(r.rp_thresholds), rj["rp_thresholds"])
	_eq("rank.ranked_streak_thresholds", _by_tier_name(r.ranked_streak_thresholds),
			rj["ranked_streak_thresholds"])
	_eq("rank TIER_SPAN", Rank.TIER_SPAN, rj["tier_span"])
	_eq("rank DIVISION_SPAN", Rank.DIVISION_SPAN, rj["division_span"])
	_eq("rank DIVISIONS", Rank.DIVISIONS, rj["divisions"])
	r.free()

	var mj = _json("res://data/server/matchmaking.json")
	var bands := []
	for band in ServerConnection.GATE_BANDS:
		bands.append({"max_delta_rating": band[0], "wait_multiplier": float(band[1])})
	_eq("GATE_BANDS", bands, mj["gate_bands"])
	_eq("ADMIN_USERNAMES", ServerConnection.ADMIN_USERNAMES, mj["admin_usernames"])
	_eq("MM_TICK", ServerConnection.MM_TICK, mj["mm_tick_seconds"])

	var p = load("res://scripts/player_component.gd").new()
	_eq("title_data", p.title_data, _json("res://data/server/title_data.json")["title_data"])
	p.free()

	var msj = _json("res://data/progression/mastery.json")
	_eq("MasteryConfig.MAX_LEVEL", MasteryConfig.MAX_LEVEL, msj["max_level"])
	_eq("MasteryConfig.XP_THRESHOLDS", Array(MasteryConfig.XP_THRESHOLDS), msj["xp_thresholds"])
	_eq("MasteryConfig.XP_PER_WIN", MasteryConfig.XP_PER_WIN, msj["xp_per_win"])
	_eq("MasteryConfig.XP_PER_LOSS", MasteryConfig.XP_PER_LOSS, msj["xp_per_loss"])
	_eq("MasteryConfig.XP_FLOOR", MasteryConfig.XP_FLOOR, msj["xp_floor"])
	_eq("MasteryConfig.UNLOCK_THRESHOLDS", MasteryConfig.UNLOCK_THRESHOLDS, msj["unlock_thresholds"])

	var ej = _json("res://data/engine/enums.json")["enums"]
	_eq_enum(ej, "Energy.Type", Energy.Type)
	_eq_enum(ej, "TargetType.Type", TargetType.Type)
	_eq_enum(ej, "DamageType.Type", DamageType.Type)
	_eq_enum(ej, "EffectType.Type", EffectType.Type)
	_eq_enum(ej, "StatType.Type", StatType.Type)
	_eq_enum(ej, "Element.Type", Element.Type)
	_eq_enum(ej, "EndingType.Type", EndingType.Type)
	_eq_enum(ej, "BattleLogEvent.Kind", BattleLogEvent.Kind)
	_eq_enum(ej, "BattleManager.MatchType", BattleManager.MatchType)
	_eq_enum(ej, "BattleManager.Gamestate", BattleManager.Gamestate)
	_eq_enum(ej, "Rank.Type", Rank.Type)
	_eq_enum(ej, "Clan.Rank", Clan.Rank)
	_eq_enum(ej, "CharacterConcept.Universe", CharacterConcept.Universe)
	_eq_enum(ej, "ServerConnection.Connection", ServerConnection.Connection)

	var ntj = _json("res://data/engine/name_tables.json")
	_eq("RESERVED_EFFECT_NAMES", Character.RESERVED_EFFECT_NAMES, ntj["reserved_effect_names"])
	_eq("HERO_SHIELD_BOUND", Character.HERO_SHIELD_BOUND, ntj["hero_shield_bound"])

	var acj = _json("res://data/engine/ability_classes.json")
	_eq("Ability.CLASS_NAMES", Ability.CLASS_NAMES, acj["class_names"])
	_eq("Ability.FREE_SKILLS_MARK", Ability.FREE_SKILLS_MARK, acj["free_skills_mark"])

	# character/jinwoo.gd has no class_name, so reach its consts through the script itself.
	var jw = load("res://character/jinwoo.gd").get_script_constant_map()
	var jwj = _json("res://data/characters/jinwoo_form_kits.json")
	_eq("jinwoo FORM_KITS", jw["FORM_KITS"], jwj["form_kits"])
	_eq("jinwoo DEFAULT_KEYS", jw["DEFAULT_KEYS"], jwj["default_keys"])

	print("[EQUIV] %d checks, %d failure(s)" % [checks, failures])
	if failures > 0:
		print("[EQUIV] data/ does NOT match the live Godot values — re-run tools/reference_data.py --write")
		quit(1)
		return
	print("[EQUIV] data/ is equivalent to the live Godot reference data.")
	quit(0)


func _json(path):
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("[EQUIV] could not read " + path)
		quit(1)
	return parsed


# Rank tables are keyed by the Type enum; re-key by NAME so they survive JSON.
func _by_tier_name(table: Dictionary) -> Dictionary:
	var keys = Rank.Type.keys()
	var out := {}
	for k in table:
		out[keys[int(k)]] = table[k]
	return out


func _eq_enum(json_enums: Dictionary, qualified: String, live: Dictionary) -> void:
	if not json_enums.has(qualified):
		_eq("enum " + qualified + " present in JSON", true, false)
		return
	var expected := {}
	for k in live:
		expected[k] = live[k]
	_eq("enum " + qualified, expected, json_enums[qualified]["members"])


# JSON round-trips every number through float, so compare the STRINGIFIED forms —
# otherwise an int 100 read back as 100.0 would read as a spurious mismatch.
func _eq(label, live, from_json) -> void:
	checks += 1
	var a = JSON.stringify(_norm(live))
	var b = JSON.stringify(_norm(from_json))
	if a == b:
		print("  ok  ", label)
		return
	failures += 1
	print("FAIL  ", label)
	print("        live: ", a.substr(0, 300))
	print("        json: ", b.substr(0, 300))


func _norm(v):
	if v is float and v == floor(v):
		return int(v)
	if v is Array:
		var out := []
		for x in v:
			out.append(_norm(x))
		return out
	if v is Dictionary:
		var keys = v.keys()
		keys.sort_custom(func (x, y): return str(x) < str(y))
		var out := {}
		for k in keys:
			out[str(k)] = _norm(v[k])
		return out
	return v
