extends Node
class_name Rank

enum Type {
	IRON,
	BRONZE,
	SILVER,
	GOLD,
	PLATINUM,
	DIAMOND,
	MASTER,
	GRANDMASTER,
	CHALLENGER   # open-ended top rank above GM 4, no division number
}

var _rp: int = 0
var _ranked_streak: int = 0
var wins: int = 0
var losses: int = 0
var streak: int = 0

# --- tiers are a PURE FUNCTION of rating ------------------------------------
# Each band is 1000 rating wide (TIER_SPAN) and splits into 4 divisions of 250 (DIVISION_SPAN), so the
# ladder runs Iron 0 .. Grandmaster 7999 with Challenger open-ended above 8000. The rating curve in
# Rating.gd is fitted to this span: a win is +100 at rating 0 and falls only gently through the low/mid
# ladder (still ~70 at 4000/Platinum), then drops off to the +/-10 floor at ~7000 (Grandmaster). (The
# earlier 400-wide bands paired with a curve that hit the floor at 2000, which left every rank from
# Silver up stuck at +10; both the width and the curve were rescaled to fix that.)
#
# There is deliberately NO stored rank and NO demotion buffer: `rank`/`rank_tier` are read-only
# properties derived on every read, so a badge can never disagree with the rating behind it and
# there is no promotion state to migrate, corrupt, or resync.
const TIER_SPAN := 1000       # rating points per rank (spread out: Master 6000, GM 7000, Challenger 8000+)
const DIVISION_SPAN := 250    # rating points per division within a rank (4 divisions x 250 = 1000)
const DIVISIONS := 4          # Iron 1 (lowest) .. Iron 4 (highest)
const RANKED_MIN_RATING_CHANGE := 10.0   # every ladder result moves rating by at least this much (win OR loss), incl. vs bots

var rank: Type:
	get: return tier_for_rating(get_rating())[0]
var rank_tier: int:
	get: return tier_for_rating(get_rating())[1]

# rating -> [Type, division]. Saturates at Grandmaster, which is open-ended (2800+).
static func tier_for_rating(p_rating: int) -> Array:
	var r: int = maxi(p_rating, 0)
	var band: int = r / TIER_SPAN
	var top: int = Type.size() - 1   # CHALLENGER — the open-ended top rank, no divisions
	if band >= top:
		# Challenger has no ceiling and no division number. Tier is fixed at 1 so the ranked-queue
		# bucket ([rank][tier], tiers 1..5 seeded at boot) resolves; the client renders it numberless.
		return [Type.CHALLENGER, 1]
	# Grandmaster (band 7) is now a normal fixed rank with 4 divisions, like every rank below it.
	var div: int = (r % TIER_SPAN) / DIVISION_SPAN + 1
	return [band as Type, div]

# Lowest rating that still counts as this rank — for "next rank at N" progress bars.
static func rating_floor_for(p_rank: Type) -> int:
	return int(p_rank) * TIER_SPAN
var derank_threshold = 5
var rating: Rating

var rp_thresholds = {
	Type.IRON: 3,
	Type.BRONZE: 5,
	Type.SILVER: 7,
	Type.GOLD: 10,
	Type.PLATINUM: 15,
	Type.DIAMOND: 20,
	Type.MASTER: 25,
	Type.GRANDMASTER: 50,
	Type.CHALLENGER: 50
}

var ranked_streak_thresholds = {
	Type.IRON: 2,
	Type.BRONZE: 3,
	Type.SILVER: 5,
	Type.GOLD: 7,
	Type.PLATINUM: 9,
	Type.DIAMOND: 12,
	Type.MASTER: 15,
	Type.GRANDMASTER: 20,
	Type.CHALLENGER: 20
}

static func rank_emblem(p_rank):
	var rank_emblems = {
		Type.IRON: load("res://assets/ui/badges/iron small.png"),
		Type.BRONZE: load("res://assets/ui/badges/bronze small.png"),
		Type.SILVER: load("res://assets/ui/badges/silver small.png"),
		Type.GOLD: load("res://assets/ui/badges/gold small.png"),
		Type.PLATINUM: load("res://assets/ui/badges/platnium small.png"),
		Type.DIAMOND: load("res://assets/ui/badges/diamond small.png"),
		Type.MASTER: load("res://assets/ui/badges/masters small.png"),
		Type.GRANDMASTER: load("res://assets/ui/badges/masters small.png"),
		Type.CHALLENGER: load("res://assets/ui/badges/masters small.png")
	}
	return rank_emblems[p_rank]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func add_loss(match_type, opponent_rating=0, rating_scale := 1.0, rating_cap := -1.0):
	losses += 1
	if streak >= 0:
		streak = -1
	else:
		streak -= 1
	if match_type == 3:
		if _ranked_streak >= 0:
			_ranked_streak = -1
		else:
			_ranked_streak -= 1
		rating.add_loss(rating_scale, RANKED_MIN_RATING_CHANGE, rating_cap)   # opponent_rating unused (rank-disparity scaling removed); rating_cap caps bot losses

func get_rating():
	if not rating:
		rating = load("res://components/Rating.gd").new()
	return rating.get_rating()

func to_str():
	return Type.keys()[rank].capitalize() + " " + str(rank_tier)

# (check_rank_change / derank / rank_up were removed here. They were an RP-and-promo-series design
#  that never ran — rank_up() was commented out to a bare `pass` and check_rank_change() had no
#  callers — and they are superseded by tier_for_rating(): the badge now moves the instant the
#  rating does, with no promotion state to hold. rp_thresholds / ranked_streak_thresholds above are
#  what that design would have needed; they are kept only as a reference if you ever want a
#  promo-series layer on top of the derived tier.)

func set_values(wins, losses, streak, _rating):
	if not rating:
		rating = load("res://components/Rating.gd").new()
	rating.set_values(_rating, wins, losses, streak)



# rating_scale shrinks ONLY the ladder rating movement (a ranked game against a bot still counts as a
# real win on the record and still moves the ranked streak — it just barely moves the ladder).
func add_win(match_type, opponent_rating=0, rating_scale := 1.0, rating_cap := -1.0):
	wins += 1

	if streak <= 0:
		streak = 1
	else:
		streak += 1
	if match_type == 3:
		if _ranked_streak <= 0:
			_ranked_streak = 1
		else:
			_ranked_streak += 1
		rating.add_win(rating_scale, rating_cap, RANKED_MIN_RATING_CHANGE)   # opponent_rating no longer used (rank-disparity scaling removed)

# (add_quick_match_win / add_quick_match_loss were removed here: they were the fossil of the old
# "Quick moves the streak" rule, had zero call sites, and were named exactly like the thing someone
# would reach for — calling either would reintroduce the Quick-affects-record behaviour that Quick
# Match no longer has.)

# (gain_ranked_point / lose_ranked_point went with check_rank_change — they were the only callers
#  and had no callers of their own. `_rp` is still loaded/saved so no save file breaks.)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
