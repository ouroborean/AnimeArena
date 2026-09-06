extends Node

# Date-windowed character stats. The point of the feature is being able to ask
# "how did this character do SINCE the patch" — the running aggregate can never
# answer that, so these checks pin that the windowed path is genuinely a different
# query and not just the same totals with a label on them.

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func _sum(rows: Array, key: String) -> int:
	var n := 0
	for r in rows:
		n += int(r.get(key, 0))
	return n

func _ready() -> void:
	print("=== stats date-window probe ===")
	var db = StatsDB.new()
	if not db.open_db():
		printerr("  could not open stats.db")
		get_tree().quit(1)
		return

	ck("per-appearance table is populated", not db.character_match_is_empty())
	var span: Array = db.character_match_span()
	ck("data span is sane (%d .. %d)" % [span[0], span[1]], span[0] > 0 and span[1] >= span[0])

	var all_rows: Array = db.get_usage_rows()
	var win_all: Array = db.get_usage_rows_between(0, 0)
	ck("aggregate has rows (%d)" % all_rows.size(), all_rows.size() > 0)
	ck("unbounded window has rows (%d)" % win_all.size(), win_all.size() > 0)

	# The appearance table can be SMALLER than the aggregate, and legitimately is on any
	# server that predates it. The backfill reads stats/matches/*.json, and StatsManager
	# never writes a record for a match containing a bot (_should_record), while the LIVE
	# aggregate has always counted bot games. So historical BOT (and ladder-vs-bot) rows
	# are simply not recoverable — the events were never archived.
	# What must always hold: the windowed path never INVENTS appearances.
	var agg_picks := _sum(all_rows, "picks")
	var win_picks := _sum(win_all, "picks")
	print("       aggregate picks=%d   unbounded-window picks=%d" % [agg_picks, win_picks])
	ck("unbounded window never exceeds the all-time aggregate", win_picks <= agg_picks)
	# PvP is what the backfill CAN recover, so that slice should line up closely. A large
	# gap here would mean the backfill is dropping archived matches, which is a real bug.
	var agg_q := 0
	var win_q := 0
	for r in all_rows:
		if int(r.get("match_type", -1)) == BattleManager.MatchType.QUICK:
			agg_q += int(r.get("picks", 0))
	for r in win_all:
		if int(r.get("match_type", -1)) == BattleManager.MatchType.QUICK:
			win_q += int(r.get("picks", 0))
	print("       QUICK: aggregate=%d  windowed=%d" % [agg_q, win_q])
	ck("archived PvP history was recovered by the backfill (within 5%%)",
		agg_q > 0 and float(win_q) / float(agg_q) >= 0.95)

	# A window that ENDS before the data starts must be empty - proves filtering happens.
	var before: Array = db.get_usage_rows_between(1, span[0] - 1)
	ck("a window ending before the first match is EMPTY (%d rows)" % before.size(), before.is_empty())

	# A window covering only the LAST day must be a strict subset.
	var last_day: Array = db.get_usage_rows_between(span[1] - 86400, 0)
	var last_picks := _sum(last_day, "picks")
	print("       last-24h picks=%d of %d total" % [last_picks, win_picks])
	ck("last-24h window is a strict subset of all time", last_picks > 0 and last_picks < win_picks)

	# Splitting the span in two must partition the total exactly - no gap, no overlap.
	var mid: int = span[0] + int((span[1] - span[0]) / 2.0)
	var lo: Array = db.get_usage_rows_between(span[0], mid)
	var hi: Array = db.get_usage_rows_between(mid + 1, span[1])
	var lo_p := _sum(lo, "picks")
	var hi_p := _sum(hi, "picks")
	print("       split: %d + %d = %d (expected %d)" % [lo_p, hi_p, lo_p + hi_p, win_picks])
	ck("two halves of the span sum EXACTLY to the whole", lo_p + hi_p == win_picks)

	# wins+losses must equal picks in every windowed row, or the SUM(won)/SUM(1-won)
	# arithmetic is wrong.
	var consistent := true
	for r in win_all:
		if int(r.get("wins", 0)) + int(r.get("losses", 0)) != int(r.get("picks", 0)):
			consistent = false
	ck("wins + losses == picks in every windowed row", consistent)

	# Idempotency: re-running the appearance backfill must not add anything, or every
	# reboot would inflate the history.
	var again: int = db.backfill_appearances()
	var after: Array = db.get_usage_rows_between(0, 0)
	print("       re-backfill touched %d rows" % again)
	ck("re-running the backfill does NOT double-count", _sum(after, "picks") == win_picks)

	db.close_db()
	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
