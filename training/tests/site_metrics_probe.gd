extends Node

# Site-usage metrics (MetricsDB) probe.
#
# Runs against a THROWAWAY db file, not the live metrics.db, so it can assert on exact
# counts — the real store is a moving target the moment anyone logs in.
#
# What these checks are actually defending:
#   * a visit that is opened twice must not make one player look like two concurrent ones
#   * a crash (no clean end_visit) must not leave an unbounded session length
#   * per-participant match rows must still count a two-human game as ONE match
#   * day bucketing must be UTC-stable, and gaps must be real zeroes rather than dropped days
#   * cohort retention must count a return on the right day, and only for that cohort

const DB_PATH := "user://metrics_probe.db"
const DAY := 86400

var pass_n := 0
var fail_n := 0


func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)


func _ready() -> void:
	print("=== site metrics probe ===")
	# Fresh file every run: leftovers from a previous run would make every count assertion lie.
	var abs_path := ProjectSettings.globalize_path(DB_PATH)
	for suffix in ["", "-wal", "-shm"]:
		if FileAccess.file_exists(abs_path + suffix):
			DirAccess.remove_absolute(abs_path + suffix)
	var db = MetricsDB.new()
	if not db.open_db(abs_path):
		printerr("  could not open probe db")
		get_tree().quit(1)
		return

	# A fixed, hand-picked "now" so the day maths is checkable by hand instead of drifting
	# with the clock: 2026-08-10 00:00:00 UTC.
	var t0 := int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 8, "day": 10, "hour": 0, "minute": 0, "second": 0}))
	var now := t0 + 5 * DAY

	# --- visits ------------------------------------------------------------------
	db.begin_visit("alice", t0 + 3600)
	db.end_visit("alice", t0 + 3600 + 1800)                 # 30 min
	db.begin_visit("bob", t0 + 7200)
	db.end_visit("bob", t0 + 7200 + 600)                    # 10 min
	db.begin_visit("alice", t0 + DAY + 3600)                # next day, still open
	ck("distinct actives on day 0 = 2", db.active_users(t0, t0 + DAY - 1) == 2)
	ck("distinct actives across both days = 2 (alice not double-counted)",
		db.active_users(t0, t0 + 2 * DAY) == 2)
	ck("sessions counted per visit, not per user", db.visit_count() == 3)

	# Re-login without a clean disconnect. The stale row must be closed, or the user shows up
	# twice in every concurrency figure for the rest of time.
	db.begin_visit("alice", t0 + DAY + 7200)
	db.db.query("SELECT COUNT(*) AS n FROM visit WHERE open = 1")
	ck("a second login closes the abandoned visit (exactly one open row)",
		int(db.db.query_result[0]["n"]) == 1)

	# Heartbeat: this is what stands in for a clean end_visit when the process dies.
	db.touch_open_visits(["alice"], t0 + DAY + 7200 + 900)
	db.db.query("SELECT ended_at - started_at AS d FROM visit WHERE open = 1")
	ck("heartbeat advances an open visit's length (900s)",
		int(db.db.query_result[0]["d"]) == 900)

	var lens := db.session_lengths(t0, now)
	ck("session count over the window = 4", int(lens["sessions"]) == 4)
	ck("total session seconds = 1800+600+0+900 = 3300", int(lens["total"]) == 3300)
	ck("average session = 825s", int(lens["average"]) == 825)

	# --- day series --------------------------------------------------------------
	var daily := db.daily_visits(t0, now)
	ck("visits roll up into 2 distinct UTC days", daily.size() == 2)
	ck("day 0 bucket is midnight-aligned", int(daily[0]["day"]) == t0)
	ck("day 0 has 2 players / 2 sessions",
		int(daily[0]["players"]) == 2 and int(daily[0]["sessions"]) == 2)

	var hours := db.hour_histogram(t0, now)
	ck("hour histogram is always 24 buckets", hours.size() == 24)
	ck("01:00 UTC bucket holds the two 1-hour-past-midnight logins", int(hours[1]) == 2)
	ck("02:00 UTC bucket holds the 2-hour-past-midnight logins", int(hours[2]) == 2)

	# --- matches -----------------------------------------------------------------
	# One game, two humans: two rows, one match. Getting this wrong doubles every
	# engagement number on the dashboard.
	db.record_event("match", "alice", t0 + 4000, "ranked", "m1")
	db.record_event("match", "bob", t0 + 4000, "ranked", "m1")
	db.record_event("match", "alice", t0 + 5000, "quick", "m2")
	db.record_event("match", "alice", t0 + 5000, "quick", "m2")   # replay of the same write
	var mt := db.event_totals("match", t0, now)
	ck("2 distinct matches from 3 stored participant rows", int(mt["refs"]) == 2)
	ck("2 distinct players played", int(mt["players"]) == 2)
	ck("re-recording the same (match, player) is ignored", int(mt["count"]) == 3)
	var by_mode := db.matches_by_mode(t0, now)
	ck("mode split: 1 ranked + 1 quick",
		int(by_mode.get("ranked", 0)) == 1 and int(by_mode.get("quick", 0)) == 1)
	var per_user := db.matches_per_user(t0, now)
	ck("per-user matches: alice 2, bob 1",
		int(per_user.get("alice", 0)) == 2 and int(per_user.get("bob", 0)) == 1)

	# --- registrations + new/returning -------------------------------------------
	db.record_event("register", "carol", t0 + 2 * DAY, "web", "carol")
	db.record_event("register", "carol", t0 + 2 * DAY, "web", "carol")   # idempotent
	ck("registration is recorded exactly once per account",
		int(db.event_totals("register", t0, now)["count"]) == 1)

	db.begin_visit("carol", t0 + 2 * DAY + 60)
	db.end_visit("carol", t0 + 2 * DAY + 300)
	var mix := db.new_vs_returning(t0 + 2 * DAY, now)
	ck("carol counts as NEW in the window her first visit lands in",
		int(mix["new"]) == 1 and int(mix["returning"]) == 0)
	var mix2 := db.new_vs_returning(t0 + DAY, now)
	ck("alice counts as RETURNING in a window that starts after her first visit",
		int(mix2["new"]) == 1 and int(mix2["returning"]) == 1)

	# --- presence ----------------------------------------------------------------
	db.record_presence(t0 + 3600, 2, 0, 1)
	db.record_presence(t0 + 7200, 5, 2, 0)
	db.record_presence(t0 + 7200, 99, 0, 0)      # same second — must not overwrite or add
	db.record_presence(t0 + DAY + 3600, 3, 1, 0)
	var peak := db.peak_presence(t0, now)
	ck("peak concurrency = 5 (duplicate-timestamp sample ignored)", int(peak["online"]) == 5)
	var dp := db.daily_presence(t0, now)
	ck("presence rolls up into 2 days", dp.size() == 2)
	ck("day 0 peak = 5", int(dp[0]["peak"]) == 5)

	# --- retention ---------------------------------------------------------------
	# dave first shows up on day 0 and comes back on day 1 -> counts for D1.
	# erin first shows up on day 0 and never returns -> counts for neither.
	db.begin_visit("dave", t0 + 100)
	db.end_visit("dave", t0 + 200)
	db.begin_visit("dave", t0 + DAY + 100)
	db.end_visit("dave", t0 + DAY + 200)
	db.begin_visit("erin", t0 + 300)
	db.end_visit("erin", t0 + 400)
	var ret := db.retention(t0, now, now)
	var c0 := {}
	for c in ret:
		if int(c["day"]) == t0:
			c0 = c
	ck("day-0 cohort found", not c0.is_empty())
	if not c0.is_empty():
		# alice, bob, dave, erin all first appear on day 0; alice and dave return on day 1.
		ck("day-0 cohort size = 4", int(c0["size"]) == 4)
		ck("D1 return = 2 of 4", int(c0["d1"]) == 2)
		ck("D7 return = 2 of 4", int(c0["d7"]) == 2)
		ck("a cohort younger than 8 days is flagged immature", c0["mature"] == false)
	var ret_old := db.retention(t0, now, t0 + 40 * DAY)
	var mature_ok := false
	for c in ret_old:
		if int(c["day"]) == t0:
			mature_ok = c["mature"] == true
	ck("the same cohort reads mature once its week has closed", mature_ok)

	# --- excluded accounts -------------------------------------------------------
	db.begin_visit("Cheshire", t0 + 500)
	db.record_event("match", "Cheshire", t0 + 500, "ranked", "m9")
	ck("dev/test accounts never enter the visit table", db.visit_count() == 8)
	ck("dev/test accounts never enter the event log",
		int(db.event_totals("match", t0, now)["refs"]) == 2)

	# --- span --------------------------------------------------------------------
	var vs := db.visit_span()
	ck("visit span starts at the earliest visit", int(vs[0]) == t0 + 100)

	db.close_db()
	print("=== site metrics probe: %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
