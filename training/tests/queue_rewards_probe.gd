extends Node

# Probe for the queue reward rules:
#   Quick   — NO win/loss, 100 AP win / 50 loss
#   Bot     — NO win/loss, 50 AP win / 0 loss
#   Ranked  — W/L recorded, 500/50 vs a human, 250/50 vs a bot
#   Ranked vs a bot moves rating at x0.10 on a win and x0.50 on a loss
# Run: godot --headless --path <repo> res://training/tests/queue_rewards_probe.tscn

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func ck_eq(label: String, got, want) -> void:
	ck("%s (got %s, want %s)" % [label, str(got), str(want)], got == want)

func _fresh_rank() -> Rank:
	var r: Rank = load("res://components/rank_component.tscn").instantiate() if ResourceLoader.exists("res://components/rank_component.tscn") else null
	if r == null:
		r = Rank.new()
	r.set_values(0, 0, 0, 1000)
	r.wins = 0
	r.losses = 0
	r.streak = 0
	r._ranked_streak = 0
	return r

func _ready() -> void:
	print("=== queue rewards probe ===")
	var sc = load("res://components/server_connection.gd").new()
	var MT = BattleManager.MatchType

	# --- AP table ------------------------------------------------------------
	ck_eq("Bot (practice) win", sc._calculate_ap_gain(MT.BOT, true, true), 50)
	ck_eq("Bot (practice) loss", sc._calculate_ap_gain(MT.BOT, false, true), 0)
	ck_eq("Quick win", sc._calculate_ap_gain(MT.QUICK, true), 100)
	ck_eq("Quick loss", sc._calculate_ap_gain(MT.QUICK, false), 50)
	# A quick-queue bot FALLBACK is MatchType.BOT with practice=false — it is a Quick match.
	ck_eq("Quick-queue bot fallback win pays Quick", sc._calculate_ap_gain(MT.BOT, true, false, true), 100)
	ck_eq("Quick-queue bot fallback loss pays Quick", sc._calculate_ap_gain(MT.BOT, false, false, true), 50)
	ck_eq("Ranked win vs human", sc._calculate_ap_gain(MT.RANKED, true), 500)
	ck_eq("Ranked loss vs human", sc._calculate_ap_gain(MT.RANKED, false), 50)
	ck_eq("Ranked win vs bot", sc._calculate_ap_gain(MT.RANKED, true, false, true), 250)
	ck_eq("Ranked loss vs bot", sc._calculate_ap_gain(MT.RANKED, false, false, true), 50)
	ck_eq("Private win", sc._calculate_ap_gain(MT.PRIVATE, true), 0)
	ck_eq("Private loss", sc._calculate_ap_gain(MT.PRIVATE, false), 0)
	# "Flat" means the table has NO streak/rank input at all — the payout is a pure function of
	# (match_type, won, practice, vs_bot) and nothing else. Comparing one call to an identical
	# call proves nothing (x == x); reading the REAL signature is what makes the claim
	# falsifiable, because reintroducing streak scaling means adding an input here.
	var ap_args: Array = []
	for mi in sc.get_method_list():
		if str(mi["name"]) == "_calculate_ap_gain":
			for arg in mi["args"]:
				ap_args.append(str(arg["name"]))
			break
	ck("AP has no streak input — the table's inputs are exactly (match_type, won, practice, vs_bot), got %s" % [ap_args],
		ap_args == ["match_type", "won", "practice", "vs_bot"])

	# --- W/L is ranked-only --------------------------------------------------
	# add_win/add_loss only ever run for RANKED now (handle_server_match_ended), so the
	# non-ranked branches of Rank must leave rating alone even if called.
	var r := _fresh_rank()
	r.add_win(MT.QUICK, 1000)
	ck_eq("a QUICK-typed add_win leaves rating untouched", r.get_rating(), 1000)
	ck_eq("...and does not move the ranked streak", r._ranked_streak, 0)
	r.free()

	# --- ranked rating scaling ----------------------------------------------
	var human_w := _fresh_rank()
	human_w.add_win(MT.RANKED, 1000)          # full
	var full_gain: float = human_w.get_rating() - 1000.0
	human_w.free()

	var bot_w := _fresh_rank()
	bot_w.add_win(MT.RANKED, 1000, 0.1)       # ranked vs bot
	var bot_gain: float = bot_w.get_rating() - 1000.0
	bot_w.free()

	ck("a full ranked win actually gains rating (%d)" % int(full_gain), full_gain > 0.0)
	# The +/-10 floor now applies to ALL ladder matches (incl. bots, per the 2026-08-14 rework), so a
	# bot win is floored at 10 rather than being 1/10th of a human win.
	ck("a ranked bot win is floored at the +/-10 minimum (%d)" % int(bot_gain), is_equal_approx(bot_gain, 10.0))
	ck("a bot win is still no larger than a full human win (%d <= %d)" % [int(bot_gain), int(full_gain)],
		bot_gain <= full_gain + 0.001)

	var human_l := _fresh_rank()
	human_l.rating.rating = 1500              # above the 1000 floor so a loss can bite
	human_l.add_loss(MT.RANKED, 1500)
	var full_loss: float = 1500.0 - human_l.get_rating()
	human_l.free()

	var bot_l := _fresh_rank()
	bot_l.rating.rating = 1500
	bot_l.add_loss(MT.RANKED, 1500, 0.5)
	var bot_loss: float = 1500.0 - bot_l.get_rating()
	bot_l.free()

	ck("a full ranked loss actually costs rating (%d)" % int(full_loss), full_loss > 0.0)
	ck("a ranked bot loss is floored at the +/-10 minimum (%d)" % int(bot_loss), is_equal_approx(bot_loss, 10.0))

	# --- a bot ranked game is still a real W/L on the record ------------------
	var rec := _fresh_rank()
	rec.add_win(MT.RANKED, 1000, 0.1)
	ck_eq("ranked bot win still counts as a win", rec.wins, 1)
	ck_eq("ranked bot win still moves the ranked streak", rec._ranked_streak, 1)
	rec.free()

	# --- the removed fossils stay removed ------------------------------------
	var fossil := _fresh_rank()
	ck("add_quick_match_win is gone", not fossil.has_method("add_quick_match_win"))
	ck("add_quick_match_loss is gone", not fossil.has_method("add_quick_match_loss"))
	fossil.free()
	ck("_handle_bot_match_ending is gone", not sc.has_method("_handle_bot_match_ending"))

	# --- constants match the spec -------------------------------------------
	ck_eq("ranked bot delay is a fixed 30s", sc.RANKED_BOT_DELAY, 30.0)
	# RANKED_BOT_RATING_CAP caps BOTH a bot win and a bot loss (renamed from ...WIN... 2026-08-14 when
	# the same cap was applied to bot losses so you can't lose more to a bot than a bot win could gain).
	ck_eq("ranked bot rating cap (win & loss)", sc.RANKED_BOT_RATING_CAP, 25.0)
	ck_eq("ranked bot LOSS rating scale", sc.RANKED_BOT_LOSS_RATING_SCALE, 0.5)

	sc.free()
	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
