extends Node
# Verifies the spread breakpoints (1000/rank), the open-ended numberless Challenger, and the
# continuous-decay rating curve.  godot --headless --path . res://training/tests/rank_restructure_probe.tscn

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _ready():
	# --- breakpoints (TIER_SPAN 1000): Master 6000, GM 7000, Challenger 8000+ ---
	_check(Rank.tier_for_rating(0)[0] == Rank.Type.IRON, "0 -> Iron")
	_check(Rank.tier_for_rating(999)[0] == Rank.Type.IRON, "999 -> Iron")
	_check(Rank.tier_for_rating(1000)[0] == Rank.Type.BRONZE, "1000 -> Bronze")
	_check(Rank.tier_for_rating(2000)[0] == Rank.Type.SILVER, "2000 -> Silver (was Diamond under old 400/rank)")
	_check(Rank.tier_for_rating(5999)[0] == Rank.Type.DIAMOND, "5999 -> Diamond")
	_check(Rank.tier_for_rating(6000)[0] == Rank.Type.MASTER, "6000 -> Master (much harder than old 2400)")
	_check(Rank.tier_for_rating(6999)[0] == Rank.Type.MASTER, "6999 -> Master")
	_check(Rank.tier_for_rating(7000)[0] == Rank.Type.GRANDMASTER, "7000 -> Grandmaster")
	_check(Rank.tier_for_rating(7999)[0] == Rank.Type.GRANDMASTER, "7999 -> Grandmaster")
	_check(Rank.tier_for_rating(8000)[0] == Rank.Type.CHALLENGER, "8000 -> Challenger")
	_check(Rank.tier_for_rating(9000)[0] == Rank.Type.CHALLENGER, "9000 -> Challenger (the top grinder)")
	_check(Rank.tier_for_rating(50000)[0] == Rank.Type.CHALLENGER, "50000 -> Challenger (open-ended)")

	# --- divisions: 4 per rank, 250 wide; GM is now a normal fixed 4-division rank ---
	_check(Rank.tier_for_rating(6000)[1] == 1, "Master floor -> division 1")
	_check(Rank.tier_for_rating(6250)[1] == 2, "Master +250 -> division 2")
	_check(Rank.tier_for_rating(6999)[1] == 4, "Master top -> division 4")
	_check(Rank.tier_for_rating(7000)[1] == 1 and Rank.tier_for_rating(7999)[1] == 4, "GM spans divisions 1..4")

	# --- Challenger: numberless (tier pinned to 1, never counts up) ---
	_check(Rank.tier_for_rating(8000)[1] == 1 and Rank.tier_for_rating(50000)[1] == 1, "Challenger tier fixed at 1 (client renders no number)")

	# --- rating_floor_for + dicts + emblem all know Challenger ---
	_check(Rank.rating_floor_for(Rank.Type.MASTER) == 6000, "rating_floor Master = 6000")
	_check(Rank.rating_floor_for(Rank.Type.CHALLENGER) == 8000, "rating_floor Challenger = 8000")
	_check(Rank.rank_emblem(Rank.Type.CHALLENGER) != null, "Challenger emblem resolves (no KeyError)")
	var rk = Rank.new()
	_check(rk.rp_thresholds.has(Rank.Type.CHALLENGER), "rp_thresholds has Challenger")
	_check(rk.ranked_streak_thresholds.has(Rank.Type.CHALLENGER), "ranked_streak_thresholds has Challenger")
	rk.free()

	# --- rating curve (gentle quadratic falloff): ~100@0, ~93@2000, ~71@4000, ~10@7000, floored at 1 ---
	var rt = load("res://components/Rating.gd").new()
	rt.rating = 0;      _check(abs(rt.calc_base_award() - 100.0) < 0.5, "award@0 ~= 100")
	rt.rating = 1000;   _check(abs(rt.calc_base_award() - 98.2) < 0.8, "award@1000 (Bronze) ~= 98 — a single rank-up barely moves it")
	rt.rating = 2000;   _check(abs(rt.calc_base_award() - 92.7) < 0.8, "award@2000 (Silver) ~= 93")
	rt.rating = 4000;   _check(abs(rt.calc_base_award() - 70.6) < 0.8, "award@4000 (Platinum) ~= 71 — still high near Platinum")
	rt.rating = 7000;   _check(abs(rt.calc_base_award() - 10.0) < 0.8, "award@7000 (Grandmaster) ~= 10")
	rt.rating = 100000; _check(rt.calc_base_award() >= 1.0, "award floored at 1 (never returns <= 0)")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
