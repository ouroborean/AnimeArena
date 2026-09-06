extends Node

# LADDER bots must field the trained high-performance teams from training/team_pool.json; the
# quick-queue fallback and the explicit Bot Match button must keep the old colour-balanced random
# draft. These checks drive the REAL ServerConnection helpers, and the last ones prove the random
# mode is genuinely different and that a missing pool still degrades gracefully.
#   godot --headless --path <repo> res://training/tests/bot_team_pool_probe.tscn

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _ready():
	print("=== bot team pool probe ===")
	# ServerConnection is a big node with a _ready that opens sockets/DBs; we only want its two
	# pure helpers, so instantiate the SCRIPT alone rather than the scene.
	var sc = load("res://components/server_connection.gd").new()

	var pool: Array = sc._load_bot_team_pool()
	_check(not pool.is_empty(), "the pool loaded (%d usable team(s))" % pool.size())

	# Every entry must be a legal, fieldable team.
	var roster: Array = CharacterDatabase.char_name_list()
	var shape_ok := true
	var excluded_hit := ""
	var unknown_hit := ""
	var dupe_hit := ""
	for team in pool:
		if typeof(team) != TYPE_ARRAY or team.size() != 3:
			shape_ok = false
			continue
		var seen := {}
		for c in team:
			if c in sc.BOT_EXCLUDED_CHARS:
				excluded_hit = str(c)
			if not c in roster:
				unknown_hit = str(c)
			if seen.has(c):
				dupe_hit = str(c)
			seen[c] = true
	_check(shape_ok, "every entry is a 3-character array")
	_check(excluded_hit == "", "no entry contains an excluded character (found '%s')" % excluded_hit)
	_check(unknown_hit == "", "every character still exists in char_name_list (found '%s')" % unknown_hit)
	_check(dupe_hit == "", "no entry repeats a character (found '%s')" % dupe_hit)

	# The raw file has entries the filter is expected to reject, so prove filtering happened rather
	# than the loader just passing everything through.
	var raw = JSON.parse_string(FileAccess.get_file_as_string(sc.BOT_TEAM_POOL_PATH))
	var raw_n: int = raw["teams"].size() if typeof(raw) == TYPE_DICTIONARY else 0
	var raw_excluded := 0
	for entry in raw["teams"]:
		for c in entry["chars"]:
			if str(c) in sc.BOT_EXCLUDED_CHARS:
				raw_excluded += 1
				break
	print("       raw file: %d team(s), %d contain an excluded character" % [raw_n, raw_excluded])
	_check(pool.size() == raw_n - raw_excluded,
		"exactly the excluded-character teams were dropped (%d = %d - %d)" % [pool.size(), raw_n, raw_excluded])

	# Picks must come FROM the pool, and over many draws should not be a single fixed team.
	var keys := {}
	for team in pool:
		keys[",".join(PackedStringArray(team))] = true
	var picked := {}
	var off_pool := ""
	for i in range(200):
		var t: Array = sc._pick_bot_team(true)
		var k := ",".join(PackedStringArray(t))
		if not keys.has(k):
			off_pool = k
		picked[k] = true
	_check(off_pool == "", "LADDER: every pick came from the pool (stray: '%s')" % off_pool)
	_check(picked.size() > 1, "LADDER: picks vary across draws (%d distinct in 200)" % picked.size())
	print("       sample ladder pick: %s" % [sc._pick_bot_team(true)])

	# ---- the NON-ladder modes must keep the old random draft ----
	# The pool covers only part of the roster, so a random draft should routinely field characters
	# that appear in NO pool team. 200 draws makes that essentially certain if the mode is right.
	var pool_chars := {}
	for team in pool:
		for c in team:
			pool_chars[c] = true
	var rand_keys := {}
	var saw_off_pool_char := false
	var rand_illegal := ""
	for i in range(200):
		var t: Array = sc._pick_bot_team(false)
		if t.size() != 3:
			rand_illegal = "size %d" % t.size()
		for c in t:
			if c in sc.BOT_EXCLUDED_CHARS or not c in roster:
				rand_illegal = str(c)
			if not pool_chars.has(c):
				saw_off_pool_char = true
		rand_keys[",".join(PackedStringArray(t))] = true
	_check(rand_illegal == "", "QUICK/BOT: random draft only fields legal characters (bad: '%s')" % rand_illegal)
	_check(saw_off_pool_char,
		"QUICK/BOT: the random draft reaches characters the pool never uses (%d pool chars of %d roster)" % [pool_chars.size(), roster.size()])
	_check(rand_keys.size() > pool.size(),
		"QUICK/BOT: the random draft is broader than the pool (%d distinct teams in 200 vs %d pool teams)" % [rand_keys.size(), pool.size()])
	print("       sample random pick: %s" % [sc._pick_bot_team(false)])

	# A pick must be a COPY: handing out the cached array would let a caller mutate the pool.
	# The mutation appends a 4th seat to ONE team, which can never change the number of teams —
	# so the pool's CONTENTS are what has to be compared. Snapshot them before the append.
	var a: Array = sc._pick_bot_team(true)
	var before := JSON.stringify(sc._load_bot_team_pool())
	a.append("naruto")
	var after := JSON.stringify(sc._load_bot_team_pool())
	_check(after == before, "the pool CONTENTS are not mutated by a caller (a handed-out team is a copy)")
	var still_three := true
	for team in sc._load_bot_team_pool():
		if team.size() != 3:
			still_three = false
	_check(still_three, "...and no cached entry grew a 4th seat")

	# Fallback: with the pool emptied, bots must still get a legal random team rather than break.
	sc._bot_team_pool = []
	sc._bot_team_pool_loaded = true
	var fb: Array = sc._pick_bot_team(true)
	print("       fallback pick: %s" % [fb])
	_check(fb.size() == 3, "LADDER with an empty pool falls back to a random team")
	var fb_ok := true
	for c in fb:
		if c in sc.BOT_EXCLUDED_CHARS or not c in roster:
			fb_ok = false
	_check(fb_ok, "...all legal and non-excluded")
	_check(fb[0] != fb[1] and fb[1] != fb[2] and fb[0] != fb[2], "...and distinct")

	sc.free()
	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
