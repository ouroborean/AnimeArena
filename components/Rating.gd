class_name Rating

var rating = 0
var wins = 0
var losses = 0
var streak = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

#For loading from the server at runtime maybe?
func set_values(_rating, _wins, _losses, _streak):
	rating = _rating
	wins = _wins
	losses = _losses
	streak = _streak

func get_rating():
	return int(rating)


#Wins get a Performance Multiplier up to 30%
# scale shrinks the rating movement without touching the W/L record or streak — used so a ranked game
# against a BOT barely moves the ladder (x0.50 on a bot loss). `cap` (negative = uncapped) bounds the
# award from ABOVE (ladder-vs-bot caps a bot win). `min_change` floors it from BELOW (the ladder +/-10
# floor, so a high-rating player never crawls up 2-3 points a win). Opponent rating no longer affects
# the award: rank-disparity scaling was removed 2026-08-14 — you gain/lose on your OWN rating alone.
func add_win(scale := 1.0, cap := -1.0, min_change := 0.0):
	var gain: float = calc_base_award() * (1 + calc_performance_multiplier()) * scale
	if cap >= 0.0:
		gain = min(gain, cap)
	# Floor is applied AFTER the cap, so callers must keep cap >= min_change (they do: the bot-win cap
	# is 25, the floor is 10). A cap set below the floor would let the floor win and exceed the cap —
	# an unenforced but currently-safe invariant; keep it if you ever retune RANKED_BOT_RATING_CAP.
	gain = maxf(gain, min_change)
	rating += gain
	wins += 1
	streak += 1


# Losses are RANK-SCALED (owner 2026-08-16, see calc_loss_multiplier): a MULTIPLE of the win award —
# ~0.5x low on the ladder (climbing is forgiving), ramping to ~3.0x at Challenger (hard to hold the top).
# No performance multiplier (only wins get that).
#
# The only floor is 0. This used to clamp to `minimum = rating` below 1000, which meant a loss under
# 1000 cost NOTHING: every player ratcheted monotonically up to 1000 in ~12 wins and could never fall
# back, so the whole population compressed into 1000-2500 and the bottom of the ladder was
# unreachable-downward. Rank tiers are a pure function of this number (Rank.tier_for_rating), so that
# clamp would have made Iron and Bronze a one-time on-ramp rather than real tiers.
func add_loss(scale := 1.0, min_change := 0.0, cap := -1.0):
	# The loss reference is the WIN magnitude at this rating: the base award floored at the same ladder
	# minimum a win uses (min_change). That matters at the TOP, where the base curve has collapsed to the
	# +/-10 floor — "3x the win" must mean 3x that 10 (=30), not 3x the raw ~1 the curve would give.
	var ref_win: float = maxf(calc_base_award(), min_change)
	var loss: float = ref_win * calc_loss_multiplier() * scale
	if cap >= 0.0:
		loss = min(loss, cap)   # a ranked BOT loss is capped the same as a bot win, so you never lose more to a bot than one could gain
	loss = maxf(loss, min_change)
	rating -= loss
	if rating < 0.0:
		rating = 0.0
	losses += 1
	streak = 0

# Rank-scaled loss multiplier: 0.5 at the bottom of the ladder, rising on a t^2 curve to 3.0 once you reach
# Challenger (rating 8000+, then clamped). So a low-ladder loss costs ~half a win, a Challenger loss ~triple.
# The t^2 shape keeps Iron..Gold under 1.0 (a loss costs less than a win, so climbing is forgiving), crosses
# 1.0 around Platinum, then ramps hard through the elite tiers.
const LOSS_MULT_LOW := 0.5
const LOSS_MULT_TOP := 3.0
const CHALLENGER_RATING := 8000.0   # Rank.Type.CHALLENGER floor (8 * Rank.TIER_SPAN) — the multiplier's ceiling
func calc_loss_multiplier() -> float:
	var t: float = clampf(float(rating) / CHALLENGER_RATING, 0.0, 1.0)
	return LOSS_MULT_LOW + (LOSS_MULT_TOP - LOSS_MULT_LOW) * t * t


#Falls gently across the low/mid ladder, dropping to the +10 floor only near Grandmaster
func calc_base_award():
	# A gentle QUADRATIC falloff, deliberately NOT a hyperbola. A hyperbola (N/(rating+C)) is steepest at
	# the very start, so gains were nearly halved after a single rank-up; this instead stays near the top
	# through the low and mid ladder and only drops off approaching the top of the 1000-wide, 8-rank
	# ladder (Iron 0 .. Challenger 8000+; see Rank.TIER_SPAN). Anchored award(0)=100 and award(7000)=10
	# with a flat start: ~98 at 1000, ~93 at 2000, ~71 at 4000 (Platinum), ~54 at 5000, ~34 at 6000, and
	# ~10 at 7000 (Grandmaster), where the +/-10 ladder floor takes over. Floored at 1.0 so calc never
	# returns <= 0 — a negative here would make add_loss ADD rating.
	var frac = float(rating) / 7000.0
	return max(100.0 - 90.0 * frac * frac, 1.0)

#Scales from 50 - 5
func calc_base_scaling():
	return max((50 - (rating * .0225)), 5.0)

# Rank-disparity scaling REMOVED 2026-08-14 (owner: "players always gain/lose based on their own rank,
# not the opponent's"). calc_max_rating_diff / distance_multiplier / DISTANCE_SWING are gone — the award
# no longer depends on the gap to the opponent, so beating someone far above you (or losing to someone
# far below) moves your rating exactly the same as an even match would.

func calc_performance_multiplier():
	var multi = 0.0
	var win_rate
	if losses == 0:
		win_rate = 1.0
	else:
		win_rate = float(wins) / float(wins + losses)   # FLOAT division — int division floored every ratio to 0 once you had a loss, so the win-rate bonus tiers never fired
	if wins >= 50 and win_rate >= .5:
		multi =.05
	if wins >= 100 and win_rate >= .66:
		multi = .10
	if wins >= 100 and win_rate >= .75:
		multi = .15
	multi += (get_current_streak() * .03)
	if multi > .3:
		return .3
	return multi

func get_current_streak():
	return streak
