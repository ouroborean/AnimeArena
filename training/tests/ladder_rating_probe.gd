extends Node

# Ladder rating probe (rewritten 2026-08-14 for the ladder rework; loss curve added 2026-08-16):
#   - Req 2: rank-disparity scaling REMOVED — the award no longer depends on the opponent's rating.
#   - Req 3: a +/-10 minimum change on every ranked result, applied via Rating's min_change floor.
#   - RANK-SCALED LOSS: a loss costs ~0.5x a win low on the ladder, ramping to ~3.0x at Challenger.
#   - the ladder-vs-bot cap (bot win) and scale (bot loss) still work, and rating never goes negative.
#   godot --headless --path <repo> res://training/tests/ladder_rating_probe.tscn

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _rating(start: int) -> Rating:
	var r := Rating.new()
	r.set_values(start, 0, 0, 0)
	return r

# Rating gain for a WIN with the given scale/cap/min_change, from a fresh object (no streak/perf leak).
func _win(start: int, scale := 1.0, cap := -1.0, min_change := 0.0) -> float:
	var r := _rating(start)
	var before: float = r.rating
	r.add_win(scale, cap, min_change)
	return r.rating - before

# Rating LOSS magnitude (positive), fresh object.
func _loss(start: int, scale := 1.0, min_change := 0.0, cap := -1.0) -> float:
	var r := _rating(start)
	var before: float = r.rating
	r.add_loss(scale, min_change, cap)
	return before - r.rating

func _ready():
	print("=== ladder rating probe ===")
	var me := 1200

	# ---- Req 2: NO rank-disparity scaling ------------------------------------------------------
	# add_win/add_loss no longer take an opponent argument — the award is purely a function of YOUR
	# own rating, so beating someone far above or losing to someone far below moves you the same.
	var w := _win(me)
	var l := _loss(me, 1.0, 10.0)
	_check(w > 0.0 and l > 0.0, "a win gains and a loss costs (%.1f / %.1f)" % [w, l])
	_check(not (Rating.new() as Object).has_method("distance_multiplier"), "distance_multiplier() is gone")
	_check(not (Rating.new() as Object).has_method("calc_max_rating_diff"), "calc_max_rating_diff() is gone")

	# ---- rank-scaled LOSS curve (owner 2026-08-16): ~0.5x a win low on the ladder, ~3.0x at Challenger ----
	_check(is_equal_approx(_rating(0).calc_loss_multiplier(), 0.5), "loss multiplier is 0.5 at the very bottom")
	_check(is_equal_approx(_rating(8000).calc_loss_multiplier(), 3.0), "loss multiplier is 3.0 at Challenger (8000)")
	_check(_rating(12000).calc_loss_multiplier() == 3.0, "loss multiplier clamps at 3.0 above Challenger")
	_check(_rating(1000).calc_loss_multiplier() < _rating(4000).calc_loss_multiplier() \
		and _rating(4000).calc_loss_multiplier() < _rating(7000).calc_loss_multiplier(), "loss multiplier rises monotonically with rating")
	# low ladder: a loss costs about HALF a win
	var lo_loss := _loss(500, 1.0, 10.0)
	var lo_win := _win(500, 1.0, -1.0, 10.0)
	_check(absf(lo_loss / lo_win - 0.5) < 0.05, "low-ladder loss is ~50%% of a win (%.1f / %.1f = %.2f)" % [lo_loss, lo_win, lo_loss / lo_win])
	# Challenger: a loss costs about TRIPLE a win (both past the floor: win=10, loss=30)
	var hi_loss := _loss(8000, 1.0, 10.0)
	var hi_win := _win(8000, 1.0, -1.0, 10.0)
	_check(is_equal_approx(hi_win, 10.0) and is_equal_approx(hi_loss, 30.0), "Challenger: a win pays 10 and a loss costs 30 (3x)")
	# the crossover: below ~Platinum a loss is cheaper than a win; above it, dearer
	_check(_loss(1000, 1.0, 10.0) < _win(1000, 1.0, -1.0, 10.0), "at Bronze a loss costs LESS than a win (climb-friendly)")
	_check(_loss(6000, 1.0, 10.0) > _win(6000, 1.0, -1.0, 10.0), "at Master a loss costs MORE than a win")

	# ---- base award still shrinks as rating climbs (unchanged curve) ----------------------------
	_check(_win(0) > _win(2000), "base award shrinks with rating (%.1f at 0 vs %.1f at 2000)" % [_win(0), _win(2000)])

	# ---- Req 3: the +/-10 floor ----------------------------------------------------------------
	# The curve now decays to ~10 only near the TOP of the ladder (~7200+), so the floor is exercised at
	# 8000 (Grandmaster/Challenger), not 6000 — the whole point of the rescale is that mid-ladder is no
	# longer floored.
	var raw_high := _win(8000)
	_check(raw_high < 10.0, "at rating 8000 the raw win is under 10 (%.2f) — the crawl this floor fixes" % raw_high)
	_check(is_equal_approx(_win(8000, 1.0, -1.0, 10.0), 10.0), "with the +/-10 floor a top-of-ladder win pays exactly 10")
	_check(is_equal_approx(_loss(8000, 0.2, 10.0), 10.0), "the +/-10 loss floor still binds when a scaled (x0.2) loss would fall below it")
	_check(_win(0, 1.0, -1.0, 10.0) > 10.0, "at low rating the award already exceeds 10, so the floor is a no-op")
	_check(_win(2000, 1.0, -1.0, 10.0) > 10.0, "at rating 2000 (Silver) the award now clears the floor — the mid-ladder fix")

	# ---- ladder-vs-bot: cap on a bot win, scale on a bot loss (both survive) --------------------
	var CAP := 25.0
	_check(is_equal_approx(_win(0, 1.0, CAP), CAP), "at rating 0 the award exceeds the bot cap, so a bot win pays exactly %.0f" % CAP)
	_check(is_equal_approx(_win(8000, 1.0, CAP, 10.0), 10.0), "bot win at top of ladder: award<cap, then floored to 10")
	_check(is_equal_approx(_loss(8000, 0.5, 10.0), 15.0), "a bot loss (x0.5) at Challenger is 3x the win x0.5 = 15")
	_check(_loss(me, 0.5) < _loss(me, 1.0), "the x0.5 bot-loss scale shrinks the loss")

	# ---- bot-LOSS cap: you never lose more to a bot than a bot win could gain -------------------
	# The rank-scaled loss peaks mid-ladder (base still high, multiplier climbing): uncapped, a x0.5 bot
	# loss there exceeds the +25 bot-win cap. The cap on add_loss fixes that — a capped bot loss == a
	# capped bot win at that rating.
	var CAP2 := 25.0
	_check(_loss(4000, 0.5) > CAP2, "an UNCAPPED bot loss can exceed the win cap (%.1f at Platinum) — the asymmetry the cap fixes" % _loss(4000, 0.5))
	_check(is_equal_approx(_loss(4000, 0.5, 10.0, CAP2), CAP2), "a CAPPED bot loss at Platinum is exactly the cap (25)")
	_check(is_equal_approx(_loss(4000, 0.5, 10.0, CAP2), _win(4000, 1.0, CAP2, 10.0)),
		"a capped bot loss matches the capped bot win (never lose more than you could gain)")
	_check(_loss(me, 0.5, 10.0, CAP2) <= CAP2 + 0.001, "the cap never makes a bot loss exceed 25 at any rating")

	# ---- perf-multiplier fix: win-rate bonus tiers actually fire (were int-division dead code) ---
	var elite := Rating.new()
	elite.set_values(1500, 120, 30, 0)   # rating 1500, 120W/30L (80% win rate), no streak
	_check(is_equal_approx(elite.calc_performance_multiplier(), 0.15),
		"120W/30L (80%%) yields the +15%% win-rate tier (was 0.0 under integer division)")

	# ---- rating can never go negative ----------------------------------------------------------
	var broke := _rating(5)
	broke.add_loss(1.0, 10.0)
	_check(broke.get_rating() >= 0, "a loss at rating 5 floors the rating at 0 (got %d)" % broke.get_rating())

	# ---- clan records: the full matrix (unchanged) ---------------------------------------------
	var SC := load("res://components/server_connection.gd")
	_check(SC.clan_record_counts("Wolves", "Bears", false, false), "clan vs a DIFFERENT clan counts")
	_check(SC.clan_record_counts("Wolves", "Clanless", false, false), "clan vs Clanless counts")
	_check(SC.clan_record_counts("Clanless", "Wolves", false, false), "...in either seat")
	_check(not SC.clan_record_counts("Wolves", "Wolves", false, false), "same clan does NOT count")
	_check(not SC.clan_record_counts("Clanless", "Clanless", false, false), "two Clanless players do not count")
	_check(not SC.clan_record_counts("Wolves", "Bears", true, false), "a bot WINNER never moves a clan record")
	_check(not SC.clan_record_counts("Wolves", "Bears", false, true), "a bot LOSER never moves one either")

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)
