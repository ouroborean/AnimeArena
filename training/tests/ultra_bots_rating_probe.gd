extends Node
# Phase 7 (Ultra Bots) — full-rating reconciliation. An ULTRA bot ranked game moves REAL, uncapped
# rating for the human AND for the bot's own rank (it climbs/falls like a player), while the EPHEMERAL
# 30s-fallback bot keeps the capped/scaled throwaway treatment. Verifies the is_ephemeral_bot() predicate
# + the two rating outcomes it selects between.
#   godot --headless --path <repo> res://training/tests/ultra_bots_rating_probe.tscn

const RANKED := 3        # BattleManager.MatchType.RANKED
const CAP := 25.0        # RANKED_BOT_RATING_CAP

var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _player(bot_player, ultra) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.bot_player = bot_player
	p.is_ultra_bot = ultra
	return p

func _rank(rating) -> Rank:
	var r: Rank = load("res://components/rank_component.gd").new()
	r.set_values(0, 0, 0, rating)
	return r

func _ready():
	print("=== Ultra Bots rating probe (Phase 7) ===")

	# ---- the discriminator: only the EPHEMERAL fallback bot is "ephemeral" ----
	_check(not _player(false, false).is_ephemeral_bot(), "human is NOT ephemeral")
	_check(_player(true, false).is_ephemeral_bot(), "ephemeral fallback bot IS ephemeral (bot_player, not ultra)")
	_check(not _player(true, true).is_ephemeral_bot(), "ULTRA bot is NOT ephemeral (treated like a human)")

	# ---- rating outcome the match-end path now selects between (at rating 0, base award ~100) ----
	# Human beating an ULTRA bot: vs_bot=false -> add_win(RANKED, opp, 1.0) uncapped -> FULL award.
	var h_ultra := _rank(0)
	var before_u: int = h_ultra.get_rating()        # get_rating() is untyped -> explicit int, not :=
	h_ultra.add_win(RANKED, 0, 1.0)                 # cap defaults to -1.0 (uncapped)
	var gain_vs_ultra: int = h_ultra.get_rating() - before_u

	# Human beating an EPHEMERAL bot: vs_bot=true -> add_win(RANKED, opp, 1.0, CAP) -> capped.
	var h_ephem := _rank(0)
	var before_e: int = h_ephem.get_rating()
	h_ephem.add_win(RANKED, 0, 1.0, CAP)
	var gain_vs_ephem: int = h_ephem.get_rating() - before_e

	_check(gain_vs_ultra > CAP, "human beating an ULTRA bot gains FULL, uncapped rating (%d > %d)" % [gain_vs_ultra, int(CAP)])
	_check(gain_vs_ephem <= CAP, "human beating an EPHEMERAL bot is capped (%d <= %d)" % [gain_vs_ephem, int(CAP)])
	_check(gain_vs_ultra > gain_vs_ephem, "an ultra-bot game moves rating MORE than an ephemeral-bot game")

	# ---- the ULTRA bot's OWN rank moves (it isn't skipped like an ephemeral seat) ----
	var ub := _rank(1500)
	var ub_before: int = ub.get_rating()
	ub.add_loss(RANKED, 0, 1.0, -1.0)               # full, uncapped loss — the P7 path runs this on the ultra side
	_check(ub.get_rating() < ub_before, "the ULTRA bot's own rating FALLS on a loss (moves like a player)")
	_check(ub.losses == 1, "the ULTRA bot's W/L record updates (losses = 1)")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
