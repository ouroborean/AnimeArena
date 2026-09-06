extends Node
# Ultra Bots mastery (owner 2026-08-16). TWO requirements:
#   (1) Ultra bots ACCRUE character mastery from wins so their profile shows real per-character stats
#       — the mastery award in handle_server_match_ended is now ephemeral-gated; here we verify the
#       underlying _award_bot_mastery raises/lowers a bot's team XP, and that the is_ephemeral gate that
#       drives it selects ultra (not ephemeral) bots.
#   (2) Any playercard an Ultra bot has equipped must be BACKED by >= level-3 mastery in that character
#       — verified via _build_ultra_bot_player / _ultra_bot_apply_card_and_mastery.
# Bare ServerConnection (off-tree; _ready does not boot a server).
#   godot --headless --path <repo> res://training/tests/ultra_bots_mastery_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _team_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u)
	p.is_ultra_bot = true
	for cn in names:
		p.recruit_character(Character.from_character_name(cn), false)
	return p

func _ready():
	print("=== Ultra Bots mastery probe ===")
	var S = load("res://components/server_connection.gd").new()
	var L3: int = MasteryConfig.XP_THRESHOLDS[int(MasteryConfig.UNLOCK_THRESHOLDS["playercard"])]  # 475

	# ---- _mastery_card_character parsing ----
	_check(S._mastery_card_character("playercard_mastery_naruto") == "naruto", "mastery card -> its character")
	_check(S._mastery_card_character("playercard_color_red") == "", "color card -> no character")
	_check(S._mastery_card_character("playercard_color_default") == "", "default card -> no character")
	_check(S._mastery_card_character("playercard_mastery_notacharacter") == "", "unknown-char mastery card -> empty (guarded)")

	# ---- req 2: a built ultra bot's equipped card is a TEAM mastery card backed by >= level 3 ----
	var bot: Player = S._build_ultra_bot_player({"username": "CardBot", "rating": 1200, "preferred_team": ["naruto", "sakura", "hinata"]})
	_check(bot != null, "built ultra bot")
	var card_ch: String = S._mastery_card_character(str(bot.equipped_player_card))
	_check(card_ch != "", "built bot equips a mastery playercard (%s)" % str(bot.equipped_player_card))
	_check(card_ch in bot.equipped_characters, "the card's character is one of the bot's own team (%s)" % card_ch)
	_check(bot.character_progress.get_level(card_ch) >= 3, "bot has >= level-3 mastery in its card's character (xp=%d, floor=%d)" % [bot.character_progress.get_xp(card_ch), L3])
	# ---- card XP is a plausible multiple of 20 (NOT the raw 475 threshold — the forensic mod-20 tell) ----
	_check(int(bot.character_progress.get_xp(card_ch)) % 20 == 0, "card-char XP is a legal multiple of 20 (xp=%d)" % bot.character_progress.get_xp(card_ch))
	_check(int(bot.character_progress.get_xp(card_ch)) != 475, "card-char XP is NOT the raw level-3 threshold 475")
	# ---- the OTHER favored characters are backed at level 2 (multiple of 20) so their lesser title words unlock ----
	for other in ["naruto", "sakura", "hinata"]:
		if other == card_ch:
			continue
		_check(bot.character_progress.get_level(other) >= 2, "favored '%s' seeded to >= level 2 (xp=%d)" % [other, bot.character_progress.get_xp(other)])
		_check(int(bot.character_progress.get_xp(other)) % 20 == 0, "favored '%s' XP is a multiple of 20" % other)

	# ---- roster player_card override is respected AND still floored ----
	var bot2: Player = S._build_ultra_bot_player({"username": "OverrideBot", "rating": 1200, "preferred_team": ["eren", "misaka", "gray"], "player_card": "playercard_mastery_gray"})
	_check(str(bot2.equipped_player_card) == "playercard_mastery_gray", "roster player_card override wins")
	_check(bot2.character_progress.get_level("gray") >= 3, "the override card's character is floored to level 3")

	# ---- raise-only: never lowers mastery already above the floor ----
	var bot3: Player = S._build_ultra_bot_player({"username": "RichBot", "rating": 1200, "preferred_team": ["naruto", "sakura", "hinata"]})
	var rc: String = S._mastery_card_character(str(bot3.equipped_player_card))
	bot3.character_progress.xp_data[rc] = 60000   # ~level 20
	var before := int(bot3.character_progress.get_xp(rc))
	var changed: bool = S._ultra_bot_apply_card_and_mastery(bot3, {"username": "RichBot", "preferred_team": ["naruto", "sakura", "hinata"]})
	_check(int(bot3.character_progress.get_xp(rc)) == before and not changed, "re-applying does NOT lower mastery already above the floor (raise-only, idempotent)")

	# ---- roster avatar_url: blank placeholder is a no-op; a supplied URL wins ----
	var av_trim: String = S._ultra_bot_roster_avatar({"avatar_url": "  https://cdn.example/a.png  "})
	_check(av_trim == "https://cdn.example/a.png", "roster avatar_url is trimmed")
	_check(S._ultra_bot_roster_avatar({}) == "" and S._ultra_bot_roster_avatar({"avatar_url": ""}) == "", "absent / blank avatar_url -> \"\" (no-op)")
	var abot: Player = S._build_ultra_bot_player({"username": "AvatarBot", "preferred_team": ["naruto", "sakura", "hinata"], "avatar_url": "https://cdn.example/naru.png"})
	_check(str(abot.avatar_url) == "https://cdn.example/naru.png", "supplied avatar_url is applied to the built bot")
	var abot2: Player = S._build_ultra_bot_player({"username": "BlankAvatarBot", "preferred_team": ["naruto", "sakura", "hinata"], "avatar_url": ""})
	_check(str(abot2.avatar_url) != "", "blank avatar_url keeps the auto-assigned cosmetic avatar (not blanked)")

	# ---- req 1: an ultra bot ACCRUES mastery from a win (each team character +XP_PER_WIN) ----
	var wbot := _team_player("WinBot", ["naruto", "sakura", "hinata"])
	var n0 := int(wbot.character_progress.get_xp("naruto"))
	S._award_bot_mastery(wbot, true)
	_check(int(wbot.character_progress.get_xp("naruto")) == n0 + MasteryConfig.XP_PER_WIN, "win awards XP_PER_WIN to each team character")
	S._award_bot_mastery(wbot, false)
	_check(int(wbot.character_progress.get_xp("sakura")) == max(0, MasteryConfig.XP_PER_WIN - MasteryConfig.XP_PER_LOSS), "loss deducts XP_PER_LOSS")

	# ---- the gate that lets the award run for ultra bots but skip ephemeral ones ----
	var ultra := _team_player("U", ["naruto", "sakura", "hinata"]); ultra.bot_player = true
	var eph: Player = load("res://components/player_component.tscn").instantiate(); eph.bot_player = true
	_check(not ultra.is_ephemeral_bot(), "ultra bot is NOT ephemeral -> receives mastery")
	_check(eph.is_ephemeral_bot(), "ephemeral bot IS ephemeral -> mastery skipped")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
