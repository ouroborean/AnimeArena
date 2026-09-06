class_name MetricsDB
extends RefCounted

# Server-side SQLite store for SITE USAGE — who visits, how often, for how long.
#
# This is deliberately separate from StatsDB (which answers "how is this CHARACTER
# doing"). Nothing in the codebase recorded a visit before this: Player carries no
# login timestamp and stats.db only ever saw completed matches, so questions like
# "how many people played yesterday" or "when are we busiest" had no answer at all.
#
# Three tables, each a different SHAPE of question:
#
#   visit    — one row per logged-in session (open -> closed). Answers actives/DAU,
#              session counts, session length, return rate, first-seen cohorts.
#   event    — an append-only log of point-in-time facts (registrations, matches
#              played). Answers "how many X per day", and — because match rows carry
#              the match id — "how many distinct matches" from the same rows.
#   presence — a periodic sample of how many people are online at once. Concurrency
#              cannot be reconstructed from visit rows without an interval scan per
#              pixel, and peak concurrency is the number that actually sizes a server.
#
# Everything is aggregated at READ time (no pre-rolled daily table): the volumes here
# are tiny next to a match archive, and a rollup would have to be rebuilt on every
# definition change. Day bucketing is UTC (started_at / 86400) so the numbers do not
# shift with the box's timezone; the dashboard labels itself UTC to match.
#
# ONLY HUMANS ARE RECORDED. Ultra Bots hold real sessions and play real ranked games,
# so if they were logged they would show up as some of the most "active players" on the
# site. Every write site is gated by the caller (see server_connection) rather than
# here, since only the caller can tell a bot seat from a person.

const DB_FILE = "metrics.db"
const MATCHES_DIR = "stats/matches/"
const DAY := 86400

# Usernames excluded from the usage aggregates — the same dev/test accounts StatsDB
# drops from character stats, for the same reason: their play is not player behaviour.
# Reusing StatsDB.EXCLUDED_USERS keeps one list instead of two that drift apart.

var db = null


static func is_excluded_user(username) -> bool:
	return StatsDB.is_excluded_user(username)


func open_db(path: String = DB_FILE) -> bool:
	db = SQLite.new()
	db.path = path
	if not db.open_db():
		push_error("[METRICS_DB] Failed to open " + path)
		db = null
		return false
	db.query("PRAGMA journal_mode = WAL")
	db.query("PRAGMA synchronous = NORMAL")
	# open=1 means "session still live". ended_at is heartbeat-updated while the visit is
	# open (see touch_open_visits), so a server crash costs at most one heartbeat of
	# duration instead of leaving the row unbounded — which is why there is no separate
	# "last_seen" column and why a dangling row is still usable after a hard kill.
	db.query(
		"CREATE TABLE IF NOT EXISTS visit ("
		+ "visit_id   INTEGER PRIMARY KEY AUTOINCREMENT, "
		+ "username   TEXT NOT NULL, "
		+ "started_at INTEGER NOT NULL, "
		+ "ended_at   INTEGER NOT NULL, "
		+ "resumed    INTEGER NOT NULL DEFAULT 0, "
		+ "open       INTEGER NOT NULL DEFAULT 1)"
	)
	db.query("CREATE INDEX IF NOT EXISTS idx_visit_time ON visit (started_at)")
	db.query("CREATE INDEX IF NOT EXISTS idx_visit_user ON visit (username, started_at)")
	db.query("CREATE INDEX IF NOT EXISTS idx_visit_open ON visit (open)")
	db.query(
		"CREATE TABLE IF NOT EXISTS event ("
		+ "event_id INTEGER PRIMARY KEY AUTOINCREMENT, "
		+ "ts       INTEGER NOT NULL, "
		+ "kind     TEXT NOT NULL, "
		+ "username TEXT NOT NULL DEFAULT '', "
		+ "detail   TEXT NOT NULL DEFAULT '', "
		+ "ref      TEXT NOT NULL DEFAULT '')"
	)
	db.query("CREATE INDEX IF NOT EXISTS idx_event_kind_ts ON event (kind, ts)")
	# Partial unique index: makes re-running a backfill (or recording the same match twice)
	# a no-op via INSERT OR IGNORE, without constraining the ref-less rows where one user
	# legitimately has many rows of the same kind.
	db.query(
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_event_dedupe "
		+ "ON event (kind, username, ref) WHERE ref <> ''"
	)
	db.query(
		"CREATE TABLE IF NOT EXISTS presence ("
		+ "ts       INTEGER PRIMARY KEY, "
		+ "online   INTEGER NOT NULL, "
		+ "in_match INTEGER NOT NULL, "
		+ "queued   INTEGER NOT NULL) WITHOUT ROWID"
	)
	# Any visit still flagged open belongs to a PREVIOUS process — this one has no sessions
	# yet. Close them where they were last seen instead of leaving rows that would count as
	# "online now" forever and inflate every concurrent/duration figure after a crash.
	db.query("UPDATE visit SET open = 0 WHERE open = 1")
	print("[METRICS_DB] Opened ", path)
	return true


func close_db():
	if db:
		db.close_db()
		db = null


# --- WRITES ---------------------------------------------------------------------

## A player just came online. `resumed` marks a reconnect into a held session rather
## than a fresh login, so "sessions" can be read either way (a tab reload during a match
## is not really a second visit).
func begin_visit(username: String, ts: int, resumed: bool = false) -> void:
	if db == null or username == "" or is_excluded_user(username):
		return
	# A visit already open for this user means the previous one was never closed (double
	# login, missed disconnect). Close it first so a user can never hold two open visits
	# and count twice in the concurrency figures.
	db.query_with_bindings(
		"UPDATE visit SET open = 0 WHERE open = 1 AND username = ?", [username])
	db.query_with_bindings(
		"INSERT INTO visit (username, started_at, ended_at, resumed, open) VALUES (?, ?, ?, ?, 1)",
		[username, ts, ts, (1 if resumed else 0)]
	)


## Player went offline for good (session wiped). Idempotent: a second call finds no open row.
func end_visit(username: String, ts: int) -> void:
	if db == null or username == "":
		return
	db.query_with_bindings(
		"UPDATE visit SET ended_at = ?, open = 0 WHERE open = 1 AND username = ?", [ts, username])


## Heartbeat for everyone currently online, called alongside the presence sample. This is
## what makes an open visit's duration survive a crash — without it the row would still say
## it ended the second it began.
func touch_open_visits(usernames: Array, ts: int) -> void:
	if db == null or usernames.is_empty():
		return
	for uname in usernames:
		if str(uname) == "":
			continue
		db.query_with_bindings(
			"UPDATE visit SET ended_at = ? WHERE open = 1 AND username = ?", [ts, str(uname)])


## Point-in-time fact. `ref` (a match id, say) makes the row idempotent — see idx_event_dedupe.
func record_event(kind: String, username: String, ts: int, detail: String = "", ref: String = "") -> void:
	if db == null or kind == "" or is_excluded_user(username):
		return
	db.query_with_bindings(
		"INSERT OR IGNORE INTO event (ts, kind, username, detail, ref) VALUES (?, ?, ?, ?, ?)",
		[ts, kind, username, detail, ref]
	)


## One concurrency sample. Keyed on ts, so a double-fire in the same second is ignored
## rather than double-counted into the daily peak.
func record_presence(ts: int, online: int, in_match: int, queued: int) -> void:
	if db == null:
		return
	db.query_with_bindings(
		"INSERT OR IGNORE INTO presence (ts, online, in_match, queued) VALUES (?, ?, ?, ?)",
		[ts, online, in_match, queued]
	)


# --- READS ----------------------------------------------------------------------
# Every read takes an explicit [from_ts, to_ts] window in unix seconds. Passing 0 for
# either end means unbounded on that side.

func _lo(from_ts: int) -> int:
	return from_ts if from_ts > 0 else 0


func _hi(to_ts: int) -> int:
	return to_ts if to_ts > 0 else 99999999999


func _rows() -> Array:
	return db.query_result.duplicate(true)


## Distinct people who had at least one visit in the window — the DAU/WAU/MAU number,
## with the window doing the work of the D/W/M.
func active_users(from_ts: int, to_ts: int) -> int:
	if db == null:
		return 0
	db.query_with_bindings(
		"SELECT COUNT(DISTINCT username) AS n FROM visit WHERE started_at >= ? AND started_at <= ?",
		[_lo(from_ts), _hi(to_ts)]
	)
	return 0 if db.query_result.is_empty() else int(db.query_result[0]["n"])


## Per-UTC-day visit rollup: {day (unix seconds at midnight), players, sessions, seconds}.
func daily_visits(from_ts: int, to_ts: int) -> Array:
	if db == null:
		return []
	db.query_with_bindings(
		"SELECT (started_at / 86400) * 86400 AS day, "
		+ "COUNT(DISTINCT username) AS players, "
		+ "COUNT(*) AS sessions, "
		+ "SUM(MAX(ended_at - started_at, 0)) AS seconds "
		+ "FROM visit WHERE started_at >= ? AND started_at <= ? GROUP BY day ORDER BY day",
		[_lo(from_ts), _hi(to_ts)]
	)
	return _rows()


## Per-UTC-day event rollup for one kind: {day, count, players, refs}.
## `refs` counts DISTINCT ref values, which is what turns the per-participant match rows
## into a match COUNT (two players, one game).
func daily_events(kind: String, from_ts: int, to_ts: int) -> Array:
	if db == null:
		return []
	db.query_with_bindings(
		"SELECT (ts / 86400) * 86400 AS day, "
		+ "COUNT(*) AS count, "
		+ "COUNT(DISTINCT username) AS players, "
		+ "COUNT(DISTINCT ref) AS refs "
		+ "FROM event WHERE kind = ? AND ts >= ? AND ts <= ? GROUP BY day ORDER BY day",
		[kind, _lo(from_ts), _hi(to_ts)]
	)
	return _rows()


## Totals for one event kind over the whole window: {count, players, refs}.
func event_totals(kind: String, from_ts: int, to_ts: int) -> Dictionary:
	if db == null:
		return {"count": 0, "players": 0, "refs": 0}
	db.query_with_bindings(
		"SELECT COUNT(*) AS count, COUNT(DISTINCT username) AS players, COUNT(DISTINCT ref) AS refs "
		+ "FROM event WHERE kind = ? AND ts >= ? AND ts <= ?",
		[kind, _lo(from_ts), _hi(to_ts)]
	)
	if db.query_result.is_empty():
		return {"count": 0, "players": 0, "refs": 0}
	var r = db.query_result[0]
	return {"count": int(r["count"]), "players": int(r["players"]), "refs": int(r["refs"])}


## Matches split by mode over the window: {detail -> match count}. Counts DISTINCT ref
## per mode so a two-human game is one match, not two.
func matches_by_mode(from_ts: int, to_ts: int) -> Dictionary:
	if db == null:
		return {}
	db.query_with_bindings(
		"SELECT detail, COUNT(DISTINCT ref) AS n FROM event "
		+ "WHERE kind = 'match' AND ts >= ? AND ts <= ? GROUP BY detail",
		[_lo(from_ts), _hi(to_ts)]
	)
	var out := {}
	for r in db.query_result:
		out[str(r["detail"])] = int(r["n"])
	return out


## Session-length summary in seconds: {sessions, total, average, median}.
## Median is a separate ORDER BY/OFFSET query rather than an average, because a handful of
## tab-left-open marathons drag the mean far away from what a typical visit looks like.
func session_lengths(from_ts: int, to_ts: int) -> Dictionary:
	var out := {"sessions": 0, "total": 0, "average": 0, "median": 0}
	if db == null:
		return out
	db.query_with_bindings(
		"SELECT COUNT(*) AS n, SUM(MAX(ended_at - started_at, 0)) AS total FROM visit "
		+ "WHERE started_at >= ? AND started_at <= ?",
		[_lo(from_ts), _hi(to_ts)]
	)
	if db.query_result.is_empty() or int(db.query_result[0]["n"]) == 0:
		return out
	out["sessions"] = int(db.query_result[0]["n"])
	out["total"] = int(db.query_result[0]["total"] if db.query_result[0]["total"] != null else 0)
	out["average"] = int(round(float(out["total"]) / float(out["sessions"])))
	db.query_with_bindings(
		"SELECT MAX(ended_at - started_at, 0) AS d FROM visit "
		+ "WHERE started_at >= ? AND started_at <= ? ORDER BY d LIMIT 1 OFFSET ?",
		[_lo(from_ts), _hi(to_ts), int(out["sessions"] / 2)]
	)
	if not db.query_result.is_empty():
		out["median"] = int(db.query_result[0]["d"])
	return out


## When people actually play: visit starts bucketed into the 24 UTC hours. Returns a
## 24-element Array of ints, so hour N is always index N even where nobody ever logs in.
func hour_histogram(from_ts: int, to_ts: int) -> Array:
	var out := []
	out.resize(24)
	out.fill(0)
	if db == null:
		return out
	db.query_with_bindings(
		"SELECT ((started_at / 3600) % 24) AS hour, COUNT(*) AS n FROM visit "
		+ "WHERE started_at >= ? AND started_at <= ? GROUP BY hour",
		[_lo(from_ts), _hi(to_ts)]
	)
	for r in db.query_result:
		var h := int(r["hour"])
		if h >= 0 and h < 24:
			out[h] = int(r["n"])
	return out


## Per-UTC-day concurrency: {day, peak, average}. Days with no sample are simply absent —
## the caller fills the gap, so a dead day reads as zero rather than as a missing bar.
func daily_presence(from_ts: int, to_ts: int) -> Array:
	if db == null:
		return []
	db.query_with_bindings(
		"SELECT (ts / 86400) * 86400 AS day, MAX(online) AS peak, AVG(online) AS average "
		+ "FROM presence WHERE ts >= ? AND ts <= ? GROUP BY day ORDER BY day",
		[_lo(from_ts), _hi(to_ts)]
	)
	return _rows()


## The busiest single sample in the window: {ts, online} (ts 0 when there are no samples).
func peak_presence(from_ts: int, to_ts: int) -> Dictionary:
	if db == null:
		return {"ts": 0, "online": 0}
	db.query_with_bindings(
		"SELECT ts, online FROM presence WHERE ts >= ? AND ts <= ? ORDER BY online DESC, ts DESC LIMIT 1",
		[_lo(from_ts), _hi(to_ts)]
	)
	if db.query_result.is_empty():
		return {"ts": 0, "online": 0}
	return {"ts": int(db.query_result[0]["ts"]), "online": int(db.query_result[0]["online"])}


## Most-present players in the window: {username, sessions, seconds, last_seen}.
func top_players(from_ts: int, to_ts: int, limit: int = 15) -> Array:
	if db == null:
		return []
	db.query_with_bindings(
		"SELECT username, COUNT(*) AS sessions, SUM(MAX(ended_at - started_at, 0)) AS seconds, "
		+ "MAX(started_at) AS last_seen FROM visit "
		+ "WHERE started_at >= ? AND started_at <= ? "
		+ "GROUP BY username ORDER BY seconds DESC, sessions DESC LIMIT ?",
		[_lo(from_ts), _hi(to_ts), limit]
	)
	return _rows()


## Matches played per user in the window: {username -> matches}. Merged into the top-players
## table by the caller so one row shows both "was here" and "actually played".
func matches_per_user(from_ts: int, to_ts: int) -> Dictionary:
	if db == null:
		return {}
	db.query_with_bindings(
		"SELECT username, COUNT(DISTINCT ref) AS n FROM event "
		+ "WHERE kind = 'match' AND ts >= ? AND ts <= ? GROUP BY username",
		[_lo(from_ts), _hi(to_ts)]
	)
	var out := {}
	for r in db.query_result:
		out[str(r["username"])] = int(r["n"])
	return out


## New vs returning split for the window: {new, returning}. "New" = first-ever visit landed
## inside the window; "returning" = was already seen before it. This is the difference between
## traffic that is growth and traffic that is retention, which a bare active count hides.
func new_vs_returning(from_ts: int, to_ts: int) -> Dictionary:
	if db == null:
		return {"new": 0, "returning": 0}
	db.query_with_bindings(
		"SELECT COUNT(*) AS n FROM (SELECT username, MIN(started_at) AS first FROM visit "
		+ "GROUP BY username) WHERE first >= ? AND first <= ?",
		[_lo(from_ts), _hi(to_ts)]
	)
	var fresh := 0 if db.query_result.is_empty() else int(db.query_result[0]["n"])
	var total := active_users(from_ts, to_ts)
	return {"new": fresh, "returning": max(total - fresh, 0)}


## Distinct (username, UTC day) pairs — the raw material for retention cohorts. Deliberately
## unaggregated: cohort maths needs the whole grid, and it is a few thousand rows at most.
func user_day_grid(from_ts: int, to_ts: int) -> Array:
	if db == null:
		return []
	db.query_with_bindings(
		"SELECT username, (started_at / 86400) * 86400 AS day FROM visit "
		+ "WHERE started_at >= ? AND started_at <= ? GROUP BY username, day ORDER BY day",
		[_lo(from_ts), _hi(to_ts)]
	)
	return _rows()


## Every user's first-visit day, for placing them in a cohort.
func first_seen_days() -> Dictionary:
	if db == null:
		return {}
	db.query("SELECT username, (MIN(started_at) / 86400) * 86400 AS day FROM visit GROUP BY username")
	var out := {}
	for r in db.query_result:
		out[str(r["username"])] = int(r["day"])
	return out


## Day-1 / Day-7 return rate by signup cohort. For each day in the window, of the users whose
## FIRST visit was that day, what share came back the next day, and what share came back at all
## within the following week. Cohorts whose 7-day window has not closed yet are still returned
## (with `mature` false) so the UI can grey them instead of showing a rate that can only rise.
func retention(from_ts: int, to_ts: int, now_ts: int) -> Array:
	if db == null:
		return []
	var first := first_seen_days()
	if first.is_empty():
		return []
	# All visit days for the cohort members, unbounded on the right so a return AFTER the
	# window still counts — a cohort's retention is a property of the cohort, not the chart.
	var grid := user_day_grid(0, 0)
	var days_by_user := {}
	for r in grid:
		var u := str(r["username"])
		if not u in days_by_user:
			days_by_user[u] = {}
		days_by_user[u][int(r["day"])] = true
	var cohorts := {}
	for u in first:
		var d: int = first[u]
		if d < _lo(from_ts) or d > _hi(to_ts):
			continue
		if not d in cohorts:
			cohorts[d] = {"day": d, "size": 0, "d1": 0, "d7": 0}
		cohorts[d]["size"] += 1
		var seen: Dictionary = days_by_user.get(u, {})
		if seen.has(d + DAY):
			cohorts[d]["d1"] += 1
		for k in range(1, 8):
			if seen.has(d + k * DAY):
				cohorts[d]["d7"] += 1
				break
	var out := []
	for d in cohorts:
		var c: Dictionary = cohorts[d]
		c["mature"] = (now_ts - int(d)) >= 8 * DAY
		out.append(c)
	out.sort_custom(func(a, b): return int(a["day"]) < int(b["day"]))
	return out


## Oldest and newest recorded activity, so the dashboard can say when tracking actually began
## instead of implying the whole window is real data.
func span() -> Array:
	if db == null:
		return [0, 0]
	var lo := 0
	var hi := 0
	db.query("SELECT MIN(started_at) AS lo, MAX(ended_at) AS hi FROM visit")
	if not db.query_result.is_empty() and db.query_result[0]["lo"] != null:
		lo = int(db.query_result[0]["lo"])
		hi = int(db.query_result[0]["hi"])
	db.query("SELECT MIN(ts) AS lo, MAX(ts) AS hi FROM event")
	if not db.query_result.is_empty() and db.query_result[0]["lo"] != null:
		var elo := int(db.query_result[0]["lo"])
		var ehi := int(db.query_result[0]["hi"])
		lo = elo if lo == 0 else min(lo, elo)
		hi = max(hi, ehi)
	return [lo, hi]


## Oldest and newest VISIT, which is when session tracking (as opposed to backfilled match
## history) started. The dashboard needs both spans: match events reach back years further
## than visits do, and presenting them as one continuous history would be a lie.
func visit_span() -> Array:
	if db == null:
		return [0, 0]
	db.query("SELECT MIN(started_at) AS lo, MAX(ended_at) AS hi FROM visit")
	if db.query_result.is_empty() or db.query_result[0]["lo"] == null:
		return [0, 0]
	return [int(db.query_result[0]["lo"]), int(db.query_result[0]["hi"])]


func count_kind(kind: String) -> int:
	if db == null:
		return 0
	db.query_with_bindings("SELECT COUNT(*) AS n FROM event WHERE kind = ?", [kind])
	return 0 if db.query_result.is_empty() else int(db.query_result[0]["n"])


func visit_count() -> int:
	if db == null:
		return 0
	db.query("SELECT COUNT(*) AS n FROM visit")
	return 0 if db.query_result.is_empty() else int(db.query_result[0]["n"])


# --- BACKFILL -------------------------------------------------------------------

## Seed 'match' events from the historical per-match JSON archive, so the dashboard has real
## engagement history on its very first boot instead of starting from an empty chart.
##
## This does NOT invent visits: a match record proves someone PLAYED, not when they logged in
## or for how long, and fabricating a session from it would put made-up numbers in the same
## column as measured ones. Session metrics therefore start the day this ships, and the UI says so.
## INSERT OR IGNORE + the (kind, username, ref) unique index makes re-running this harmless.
func backfill_matches(matches_dir: String = MATCHES_DIR) -> int:
	if db == null or not DirAccess.dir_exists_absolute(matches_dir):
		return 0
	var written := 0
	db.query("BEGIN TRANSACTION")
	for file_name in DirAccess.get_files_at(matches_dir):
		if not file_name.ends_with(".json"):
			continue
		var file = FileAccess.open(matches_dir + file_name, FileAccess.READ)
		if file == null:
			continue
		var json = JSON.new()
		if json.parse(file.get_line()) != OK:
			continue
		var data = json.get_data()
		if not (data is Dictionary):
			continue
		var mid := str(data.get("match_id", file_name.get_basename()))
		var mode := mode_label(int(data.get("match_type", -1)))
		if mode == "":
			continue
		var played := _record_timestamp(data, file_name)
		if played <= 0:
			continue
		for key in ["player1_username", "player2_username"]:
			var uname := str(data.get(key, ""))
			if uname == "" or is_excluded_user(uname):
				continue
			record_event("match", uname, played, mode, mid)
			written += 1
	db.query("COMMIT")
	print("[METRICS_DB] Backfilled ", written, " historical match rows")
	return written


## BattleManager.MatchType -> the label stored in event.detail. Kept here (rather than at the
## call site) so the live recorder and the backfill can never disagree about what a mode is
## called — a mismatch would silently split one mode into two series on the chart.
static func mode_label(match_type: int) -> String:
	match match_type:
		BattleManager.MatchType.PRIVATE: return "private"
		BattleManager.MatchType.QUICK: return "quick"
		BattleManager.MatchType.BOT: return "bot"
		BattleManager.MatchType.RANKED: return "ranked"
		BattleManager.MatchType.CAMPAIGN: return "campaign"
	return ""


## Unix seconds for an archived record; mirrors StatsDB._record_timestamp (date dict, then the
## YYYYMMDD filename prefix, then 0 = "unknown", which the caller drops rather than guessing).
func _record_timestamp(data: Dictionary, file_name: String) -> int:
	var d = data.get("date", null)
	if d is Dictionary and d.has("year"):
		return int(Time.get_unix_time_from_datetime_dict({
			"year": int(d.get("year", 1970)), "month": int(d.get("month", 1)),
			"day": int(d.get("day", 1)), "hour": int(d.get("hour", 0)),
			"minute": int(d.get("minute", 0)), "second": int(d.get("second", 0)),
		}))
	var stamp := file_name.substr(0, 8)
	if stamp.length() == 8 and stamp.is_valid_int():
		return int(Time.get_unix_time_from_datetime_dict({
			"year": int(stamp.substr(0, 4)), "month": int(stamp.substr(4, 2)),
			"day": int(stamp.substr(6, 2)), "hour": 0, "minute": 0, "second": 0,
		}))
	return 0
