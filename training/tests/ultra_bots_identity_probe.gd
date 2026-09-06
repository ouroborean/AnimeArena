extends Node
# Phase 1 (Ultra Bots) — the identity foundation: a durable, UNFORGEABLE, player-DISGUISED is_ultra_bot
# marker plus the roster/account builder. Runs against pure functions on a bare ServerConnection (NOT
# added to the tree — its _ready would boot a whole game server) and Player save/load round-trips.
#   godot --headless --path <repo> res://training/tests/ultra_bots_identity_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _ready():
	print("=== Ultra Bots identity probe (Phase 1) ===")
	var S = load("res://components/server_connection.gd").new()   # bare: _ready does NOT fire off-tree

	# ---- roster loads from ultra_bots.json ----
	var roster = S._load_ultra_bot_roster()
	_check(roster is Array and roster.size() >= 1, "ultra_bots.json roster loads (%d bot(s))" % [(roster.size() if roster is Array else -1)])

	# ---- builder produces a valid persistent bot Player ----
	var entry = {"username": "ProbeBot_XYZ", "rating": 1337, "preferred_team": ["naruto", "sakura", "hinata"], "title": "Probe"}
	var bot = S._build_ultra_bot_player(entry)
	_check(bot != null, "builder returns a Player")
	_check(bot.username == "ProbeBot_XYZ", "builder sets username")
	_check(bot.is_ultra_bot == true, "builder marks is_ultra_bot = true")
	_check(int(bot.rank.get_rating()) == 1337, "builder sets the starting rating")
	_check(bot.equipped_characters.size() == 3, "builder sets a 3-char preferred team")
	_check(str(bot.avatar_url) != "", "builder assigns a cosmetic avatar")

	# ---- team validation drops junk + duplicates and back-fills to exactly 3 distinct ----
	var team = S._ultra_bot_team(["naruto", "not_a_real_char", "naruto"])   # 1 valid, 1 junk, 1 dup
	_check(team.size() == 3, "team validator back-fills to exactly 3")
	_check("naruto" in team, "team validator keeps the valid preferred pick")
	var distinct := {}
	for c in team: distinct[c] = true
	_check(distinct.size() == 3, "team has 3 DISTINCT characters")

	# ---- save() persists the marker; load_player round-trips it ----
	var data = bot.save()
	_check(data.get("is_ultra_bot", null) == true, "save() persists is_ultra_bot")
	var reloaded = Player.load_player(data)
	_check(reloaded.is_ultra_bot == true, "load_player restores is_ultra_bot")

	# ---- back-compat: a save with NO key loads as a normal (human) account ----
	data.erase("is_ultra_bot")
	var human_load = Player.load_player(data)
	_check(human_load.is_ultra_bot == false, "load_player defaults a keyless (pre-existing) account to false")

	# ---- DISGUISE: the marker must never reach a player-facing surface ----
	_check(not ("is_ultra_bot" in bot.display_package()), "display_package() (opponent view) HIDES is_ultra_bot")
	_check(not ("is_ultra_bot" in bot.make_cosmetic_update()), "make_cosmetic_update() (client echo) HIDES is_ultra_bot")

	# ---- UNFORGEABLE: a crafted cosmetic payload cannot flip a human into a bot ----
	var victim = Player.new_gen("HumanVictim", "", {})
	victim.set_username("HumanVictim")
	_check(victim.is_ultra_bot == false, "fresh human account is_ultra_bot=false")
	var forged = victim.make_cosmetic_update()
	forged["is_ultra_bot"] = true                       # attacker injects the flag
	victim.absorb_cosmetic_update(forged)
	_check(victim.is_ultra_bot == false, "absorb_cosmetic_update IGNORES a forged is_ultra_bot (unforgeable)")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
