extends Node

# Rank tiers as a PURE FUNCTION of rating, plus the removal of the sub-1000 loss floor that
# made the bottom of the ladder unreachable-downward.
# Bands are 1000 rating wide (Rank.TIER_SPAN) with 4 divisions of 250 (Rank.DIVISION_SPAN):
# Iron 0-999 .. Grandmaster 7000-7999, and Challenger open-ended at 8000+.

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func ck_tier(rating: int, want_rank, want_div: int) -> void:
	var got: Array = Rank.tier_for_rating(rating)
	var name_of := func(t): return Rank.Type.keys()[t].capitalize()
	ck("%5d -> %s %d" % [rating, name_of.call(want_rank), want_div],
		got[0] == want_rank and got[1] == want_div)

func _fresh() -> Rank:
	var r := Rank.new()
	r.set_values(0, 0, 0, 0)
	return r

func _ready() -> void:
	print("=== rank tier probe ===")
	var T = Rank.Type

	# --- band boundaries (1000 wide, 4 divisions of 250) --------------------
	ck_tier(0, T.IRON, 1)
	ck_tier(249, T.IRON, 1)
	ck_tier(250, T.IRON, 2)
	ck_tier(999, T.IRON, 4)
	ck_tier(1000, T.BRONZE, 1)
	ck_tier(1999, T.BRONZE, 4)
	ck_tier(2000, T.SILVER, 1)
	ck_tier(3000, T.GOLD, 1)
	ck_tier(4000, T.PLATINUM, 1)
	ck_tier(5000, T.DIAMOND, 1)
	ck_tier(6000, T.MASTER, 1)
	ck_tier(6999, T.MASTER, 4)
	ck_tier(7000, T.GRANDMASTER, 1)

	# Grandmaster is a fixed rank (7000-7999); Challenger (8000+) is the open-ended top with no division.
	ck_tier(7999, T.GRANDMASTER, 4)
	ck_tier(8000, T.CHALLENGER, 1)
	ck_tier(50000, T.CHALLENGER, 1)
	var huge: Array = Rank.tier_for_rating(1000000)
	ck("an absurd rating still resolves to Challenger", huge[0] == T.CHALLENGER)
	ck("...with a valid division", huge[1] >= 1 and huge[1] <= Rank.DIVISIONS)

	# Negative/garbage input must not produce a negative enum index.
	ck_tier(-500, T.IRON, 1)

	# Every band must be reachable and ordered — no gaps, no overlaps.
	var seen := {}
	var last_rank := -1
	var last_div := -1
	var ordered := true
	for r in range(0, 8100, 25):
		var t: Array = Rank.tier_for_rating(r)
		seen[t[0]] = true
		var key: int = int(t[0]) * 10 + t[1]
		if key < last_rank * 10 + last_div:
			ordered = false
		last_rank = int(t[0]); last_div = t[1]
	ck("all ranks are reachable by rating", seen.size() == Rank.Type.size())
	ck("tier never goes DOWN as rating goes up", ordered)

	# --- the live property is derived, not stored ---------------------------
	var rk := _fresh()
	ck("a new player is Iron 1", rk.rank == T.IRON and rk.rank_tier == 1)
	rk.rating.rating = 1450
	ck("bumping rating alone moves the badge to Bronze 2", rk.rank == T.BRONZE and rk.rank_tier == 2)
	ck("to_str reflects it", rk.to_str() == "Bronze 2")
	rk.rating.rating = 0
	ck("dropping the rating drops the badge back to Iron 1", rk.rank == T.IRON and rk.rank_tier == 1)
	ck("rating_floor_for(DIAMOND) is 5000", Rank.rating_floor_for(T.DIAMOND) == 5000)

	# --- the sub-1000 floor is GONE -----------------------------------------
	# Start just ACROSS a band boundary so "back down a rank" is exercised: 1010 is Bronze 1, and one
	# ranked loss there (~44 on the rescaled curve) lands back inside Iron.
	var lo := _fresh()
	lo.rating.rating = 1010
	ck("(setup) 1010 is Bronze 1", lo.rank == Rank.Type.BRONZE and lo.rank_tier == 1)
	lo.add_loss(3, 1010)                      # match_type 3 == RANKED
	ck("a ranked loss COSTS rating (1010 -> %d)" % lo.get_rating(), lo.get_rating() < 1010)
	ck("...and can carry you back down a rank (Bronze 1 -> %s %d)"
			% [Rank.Type.keys()[lo.rank].capitalize(), lo.rank_tier], lo.rank == Rank.Type.IRON)
	lo.free()

	var zero := _fresh()
	zero.add_loss(3, 0)
	ck("rating cannot go negative", zero.get_rating() >= 0)
	ck("a 0-rated player stays Iron 1", zero.rank == Rank.Type.IRON and zero.rank_tier == 1)
	zero.free()

	# A player at 1000 must now be able to fall below it (the old clamp forbade this).
	var mid := _fresh()
	mid.rating.rating = 1010
	for i in range(6):
		mid.add_loss(3, 1010)
	ck("a 1000-rated player can now fall below 1000 (-> %d)" % mid.get_rating(), mid.get_rating() < 1000)
	mid.free()

	# --- the dormant promo machinery is gone --------------------------------
	ck("check_rank_change is gone", not rk.has_method("check_rank_change"))
	ck("rank_up is gone", not rk.has_method("rank_up"))
	ck("derank is gone", not rk.has_method("derank"))
	rk.free()

	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
