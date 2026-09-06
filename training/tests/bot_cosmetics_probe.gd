extends Node

# Bot cosmetics: every server-side bot gets a random avatar + playercard from the shipped assets.
#
# THE BUG THIS REPLACES: _make_server_bot assigned `avatar_texture`, a Godot Texture. What the wire
# actually carries is `avatar_url` (Player.display_package), so on a headless server that assignment
# reached nobody and every bot rendered the default avatar. It also guessed randi_range(1, 72) at a
# folder holding 89 mixed numeric/named files, so two thirds were unreachable even in principle.
#
# What is asserted: the pools are enumerated from disk (not hardcoded), every pick names a file that
# EXISTS, queue bots vary, and campaign enemies are STABLE on their name so a scripted opponent does
# not change face between retries.

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _exists(res_path: String) -> bool:
	# In an exported build the .png is replaced by an imported .ctex, so ResourceLoader (which knows
	# about the remap) is the honest test, not FileAccess.
	return ResourceLoader.exists(res_path) or FileAccess.file_exists(res_path)

func _ready():
	print("=== bot cosmetics probe ===")
	var S = load("res://components/server_connection.gd").new()

	S._load_cosmetic_pools()
	_check(S._avatar_pool.size() > 0, "avatar pool enumerated from disk (%d)" % S._avatar_pool.size())
	_check(S._playercard_pool.size() > 0, "playercard pool enumerated from disk (%d)" % S._playercard_pool.size())
	# The old hardcoded guess was 1..72; the folder really holds 89. Pin that the pool is not that.
	_check(S._avatar_pool.size() > 72, "the pool is larger than the old hardcoded 1..72 guess")

	var bots := []
	for i in range(40):
		var b = load("res://components/player_component.tscn").instantiate()
		S._apply_bot_cosmetics(b)
		bots.append(b)

	var bad_av := ""
	var bad_card := ""
	for b in bots:
		if not _exists(b.avatar_url):
			bad_av = b.avatar_url
		if not _exists("res://assets/cosmetics/playercards/" + b.equipped_player_card + ".png"):
			bad_card = b.equipped_player_card
	_check(bad_av == "", "every avatar_url names a file that exists (bad: '%s')" % bad_av)
	_check(bad_card == "", "every playercard names a file that exists (bad: '%s')" % bad_card)

	# It ships avatar_url, not a Texture — this is the whole point of the change.
	_check(str(bots[0].avatar_url).begins_with("res://assets/avatars/"),
		"avatar_url is a res:// path the client can resolve: %s" % str(bots[0].avatar_url))
	var pkg = bots[0].display_package()
	_check(pkg.has("avatar_url") and str(pkg["avatar_url"]) == str(bots[0].avatar_url),
		"display_package carries it onto the wire")
	_check(pkg.has("player_card") and str(pkg["player_card"]) == str(bots[0].equipped_player_card),
		"...and carries the playercard too")

	# Variety: 40 draws over 89 avatars and 163 cards should not collapse to one value.
	var av_seen := {}
	var card_seen := {}
	for b in bots:
		av_seen[b.avatar_url] = true
		card_seen[b.equipped_player_card] = true
	_check(av_seen.size() > 5, "queue bots vary their avatar (%d distinct in 40)" % av_seen.size())
	_check(card_seen.size() > 5, "queue bots vary their playercard (%d distinct in 40)" % card_seen.size())

	# Campaign enemies are stable on their name.
	var c1 = load("res://components/player_component.tscn").instantiate()
	var c2 = load("res://components/player_component.tscn").instantiate()
	var c3 = load("res://components/player_component.tscn").instantiate()
	S._apply_bot_cosmetics(c1, "Enemy Forces")
	S._apply_bot_cosmetics(c2, "Enemy Forces")
	S._apply_bot_cosmetics(c3, "Rival Squad")
	_check(c1.avatar_url == c2.avatar_url and c1.equipped_player_card == c2.equipped_player_card,
		"the SAME campaign enemy name always gets the same look")
	_check(c3.avatar_url != c1.avatar_url or c3.equipped_player_card != c1.equipped_player_card,
		"a DIFFERENT campaign enemy name gets a different look")
	_check(_exists(c1.avatar_url), "the stable pick is a real file too")

	for b in bots:
		b.queue_free()
	c1.queue_free()
	c2.queue_free()
	c3.queue_free()
	S.free()
	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
