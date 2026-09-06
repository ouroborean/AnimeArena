extends Node
# Ultra Bots FAVORED characters (<3) + colour-matched fill + occasional team switch (owner 2026-08-16).
# A bot ALWAYS fields its 1-3 favored characters; the remaining seats are a random colour-matched draft it
# occasionally re-rolls between games. Bare ServerConnection (off-tree).
#   godot --headless --path <repo> res://training/tests/ultra_bots_team_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _ready():
	print("=== Ultra Bots favored-team probe ===")
	var S = load("res://components/server_connection.gd").new()

	# ---- favored sanitize: valid / distinct / non-excluded, capped at 3 ----
	_check(S._ultra_bot_favored_sanitized(["naruto", "sakura"]) == ["naruto", "sakura"], "2 valid favored kept as-is")
	_check(S._ultra_bot_favored_sanitized(["naruto", "naruto", "sakura"]) == ["naruto", "sakura"], "duplicate dropped")
	_check(S._ultra_bot_favored_sanitized(["naruto", "toga", "sakura"]) == ["naruto", "sakura"], "excluded (toga) dropped")
	_check(S._ultra_bot_favored_sanitized(["naruto", "notarealchar", "sakura"]) == ["naruto", "sakura"], "unknown name dropped")
	_check(S._ultra_bot_favored_sanitized(["naruto", "sakura", "hinata", "gon"]).size() == 3, "capped at 3")
	_check(S._ultra_bot_favored_sanitized([]) == [], "empty favored -> empty")

	# ---- _ultra_bot_team: favored always present, filled to a distinct 3 ----
	for fav in [["naruto"], ["naruto", "sakura"], ["gon", "hisoka", "killua"]]:
		var t: Array = S._ultra_bot_team(fav)
		var ok: bool = t.size() == 3
		for f in fav: ok = ok and (f in t)
		var seen := {}
		for c in t: seen[c] = true
		_check(ok and seen.size() == 3, "team from favored %s -> full distinct 3 incl. favored (%s)" % [str(fav), str(t)])

	# ---- the fill VARIES (random colour-matched) when < 3 favored ----
	var teams := {}
	for i in range(40):
		teams[",".join(S._ultra_bot_team(["naruto"]))] = true
	_check(teams.size() > 1, "single-favored fill produces varied teams over 40 rolls (%d distinct)" % teams.size())

	# ---- a bot with NO valid favorites fields a RESHUFFLING random team (not frozen) ----
	var b0: Player = S._build_ultra_bot_player({"username": "NoFav", "preferred_team": ["notarealchar", "toga"]})
	_check(S._ultra_bot_favored.get("NoFav", ["x"]) == [], "all-invalid preferred_team -> empty favored core")
	var novteams := {}
	for i in range(40):
		var mt0: Array = S._ultra_bot_pick_match_team("NoFav", b0)
		novteams[",".join(mt0)] = true
	_check(novteams.size() > 1, "no-favorites bot varies its team over 40 games (%d distinct, not frozen)" % novteams.size())

	# ---- build records the favored core + fields a full team ----
	var b1: Player = S._build_ultra_bot_player({"username": "FavOne", "preferred_team": ["gray"]})
	_check(S._ultra_bot_favored.get("FavOne", []) == ["gray"], "build records the 1-favored core")
	_check(b1.equipped_characters.size() == 3 and ("gray" in b1.equipped_characters), "build fields a full team incl. the favored char")

	# ---- 3-favored is fixed; 1-favored always keeps its favorite across games ----
	var b3: Player = S._build_ultra_bot_player({"username": "FavThree", "preferred_team": ["gon", "hisoka", "killua"]})
	var first := ""
	var fixed := true
	for i in range(10):
		var mt: Array = S._ultra_bot_pick_match_team("FavThree", b3)
		mt.sort()
		if first == "": first = ",".join(mt)
		fixed = fixed and (",".join(mt) == first) and mt.size() == 3
	_check(fixed, "3-favored bot fields a fixed team every game")
	var always := true
	for i in range(20):
		var mt2: Array = S._ultra_bot_pick_match_team("FavOne", b1)
		always = always and ("gray" in mt2) and mt2.size() == 3
	_check(always, "1-favored bot ALWAYS fields its favored char across 20 games")

	# ---- the earned mastery card is for a FAVORED character (consistent through fill re-rolls) ----
	var card_ch: String = S._mastery_card_character(str(b1.equipped_player_card))
	_check(card_ch == "gray", "mastery card is the favored character's card (%s)" % str(b1.equipped_player_card))
	_check(b1.character_progress.get_level("gray") >= 3, "favored char is floored to level 3 (card-backed)")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
