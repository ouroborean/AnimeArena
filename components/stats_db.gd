class_name StatsDB
extends RefCounted

# Server-side SQLite store for character usage / win-rate aggregates.
#
# One row per (character_path, match_type) holding cumulative picks / wins /
# losses. Keying by match_type keeps the raw modes distinct (PRIVATE=0,
# QUICK=1, BOT=2, RANKED=3 — see BattleManager.MatchType) so any bucketing (e.g.
# "PvP" = QUICK+RANKED vs "Bot" = BOT) is a read-time roll-up, never a
# lossy write-time decision. Only characters a HUMAN actually fielded are
# recorded — a bot seat's synthetic team is not a player "pick".
#
# This supersedes the loose, unread stats/<char>.stats flat files as the
# queryable source of truth. It mirrors mastery_db.gd (WAL journaling,
# parameterized upserts, boot-time self-heal) so writes are atomic and
# crash-safe across concurrent match-ends instead of a truncate-rewrite race.

const DB_FILE = "stats.db"
const MATCHES_DIR = "stats/matches/"

# Usernames whose fielded characters are excluded from the usage aggregates
# (admin / test / dev accounts whose play would skew the real-player meta). Only
# the excluded account's OWN team is dropped — its opponents still count normally,
# since a real player's win/loss against a test account is still real data.
const EXCLUDED_USERS: Array = ["Cheshire", "Suffering"]

var db = null


# Exact-case membership test, matching how usernames are stored on disk.
static func is_excluded_user(username) -> bool:
	return username != null and str(username) in EXCLUDED_USERS


func open_db(path: String = DB_FILE) -> bool:
	db = SQLite.new()
	db.path = path
	if not db.open_db():
		push_error("[STATS_DB] Failed to open " + path)
		db = null
		return false
	db.query("PRAGMA journal_mode = WAL")
	db.query("PRAGMA synchronous = NORMAL")
	db.query(
		"CREATE TABLE IF NOT EXISTS character_usage ("
		+ "character_path TEXT NOT NULL, "
		+ "match_type     INTEGER NOT NULL, "
		+ "picks          INTEGER NOT NULL DEFAULT 0, "
		+ "wins           INTEGER NOT NULL DEFAULT 0, "
		+ "losses         INTEGER NOT NULL DEFAULT 0, "
		+ "updated_at     INTEGER NOT NULL, "
		+ "PRIMARY KEY (character_path, match_type)) WITHOUT ROWID"
	)
	db.query(
		"CREATE INDEX IF NOT EXISTS idx_usage_picks "
		+ "ON character_usage (match_type, picks DESC)"
	)
	# Per-appearance rows, so stats can be windowed by DATE. character_usage is a running
	# aggregate keyed on (character_path, match_type) whose updated_at is overwritten on
	# every write, so it can only ever answer "all time" — there is no way to subtract a
	# period back out of it. This table keeps one row per (match, character) with the
	# match's timestamp, which is what makes "how did this character do since the patch"
	# answerable at all. The aggregate is left exactly as it was and still serves the
	# unfiltered view, so nothing existing changes behaviour or needs migrating.
	db.query(
		"CREATE TABLE IF NOT EXISTS character_match ("
		+ "match_id       TEXT NOT NULL, "
		+ "character_path TEXT NOT NULL, "
		+ "match_type     INTEGER NOT NULL, "
		+ "won            INTEGER NOT NULL, "
		+ "played_at      INTEGER NOT NULL, "
		+ "PRIMARY KEY (match_id, character_path)) WITHOUT ROWID"
	)
	# The window predicate is always on played_at, so lead with it.
	db.query(
		"CREATE INDEX IF NOT EXISTS idx_cm_time "
		+ "ON character_match (played_at, match_type)"
	)
	print("[STATS_DB] Opened ", path)
	return true


## True when the per-appearance table has no rows — the caller uses this to decide
## whether to backfill it from the historical match records.
func character_match_is_empty() -> bool:
	if db == null:
		return true
	db.query("SELECT COUNT(*) AS n FROM character_match")
	if db.query_result.is_empty():
		return true
	return int(db.query_result[0]["n"]) == 0


## One row per character per match. INSERT OR IGNORE keyed on (match_id, character_path)
## makes this idempotent: re-running a backfill, or recording a match twice, cannot
## double-count an appearance the way a blind aggregate increment would.
func record_character_appearance(match_id: String, character_path: String,
		match_type: int, won: bool, played_at: int) -> void:
	if db == null or character_path == "" or match_id == "":
		return
	db.query_with_bindings(
		"INSERT OR IGNORE INTO character_match "
		+ "(match_id, character_path, match_type, won, played_at) VALUES (?, ?, ?, ?, ?)",
		[match_id, character_path, match_type, (1 if won else 0), played_at]
	)


## Aggregate the per-appearance rows over a time window, returning the SAME row shape as
## get_usage_rows() so the caller can treat both identically.
## from_ts/to_ts are unix seconds; pass 0 for "unbounded" on either end.
func get_usage_rows_between(from_ts: int, to_ts: int) -> Array:
	if db == null:
		return []
	var lo := from_ts if from_ts > 0 else 0
	var hi := to_ts if to_ts > 0 else 99999999999
	db.query_with_bindings(
		"SELECT character_path, match_type, "
		+ "COUNT(*) AS picks, "
		+ "SUM(won) AS wins, "
		+ "SUM(1 - won) AS losses "
		+ "FROM character_match WHERE played_at >= ? AND played_at <= ? "
		+ "GROUP BY character_path, match_type",
		[lo, hi]
	)
	return db.query_result.duplicate(true)


## Oldest and newest appearance timestamps, so the UI can show the real span of data
## instead of offering a date range that contains nothing.
func character_match_span() -> Array:
	if db == null:
		return [0, 0]
	db.query("SELECT MIN(played_at) AS lo, MAX(played_at) AS hi FROM character_match")
	if db.query_result.is_empty() or db.query_result[0]["lo"] == null:
		return [0, 0]
	return [int(db.query_result[0]["lo"]), int(db.query_result[0]["hi"])]


func close_db():
	if db:
		db.close_db()
		db = null


func is_empty() -> bool:
	if db == null:
		return true
	db.query("SELECT COUNT(*) AS n FROM character_usage")
	if db.query_result.is_empty():
		return true
	return int(db.query_result[0]["n"]) == 0


# Increment one character's tally for a single completed game. `won` decides
# whether this appearance counts as a win or a loss; `picks` always +1.
func record_character(character_path: String, match_type: int, won: bool) -> void:
	if db == null or character_path == "":
		return
	var ts = int(Time.get_unix_time_from_system())
	db.query_with_bindings(
		"INSERT INTO character_usage (character_path, match_type, picks, wins, losses, updated_at) "
		+ "VALUES (?, ?, 1, ?, ?, ?) "
		+ "ON CONFLICT(character_path, match_type) DO UPDATE SET "
		+ "picks = picks + 1, "
		+ "wins = wins + excluded.wins, "
		+ "losses = losses + excluded.losses, "
		+ "updated_at = excluded.updated_at",
		[character_path, match_type, (1 if won else 0), (0 if won else 1), ts]
	)


# Return every aggregate row as a plain Array of Dictionaries
# {character_path, match_type, picks, wins, losses}. The caller buckets.
func get_usage_rows() -> Array:
	if db == null:
		return []
	db.query("SELECT character_path, match_type, picks, wins, losses FROM character_usage")
	return db.query_result.duplicate(true)


# One-time seed from the historical per-match JSON logs under stats/matches/.
# Those records carry match_type + both full teams + the winner, so the DB can
# be rebuilt exactly (correctly attributed per mode) without any lossy guess.
# Runs ONLY on a fresh/empty table — guarded by the caller via is_empty() — so
# it never double-counts across reboots. PRIVATE records (if any) are skipped,
# matching the live recording policy.
func backfill_from_match_records(matches_dir: String = MATCHES_DIR) -> int:
	if db == null:
		return 0
	if not DirAccess.dir_exists_absolute(matches_dir):
		return 0
	var written = 0
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
		var match_type = int(data.get("match_type", -1))
		# PRIVATE (0) is excluded from stats; historical logs never contain BOT/PRIVATE
		# anyway (StatsManager skipped them), so in practice this is QUICK/RANKED only.
		if match_type == BattleManager.MatchType.PRIVATE:
			continue
		var winner = str(data.get("winner_username", ""))
		var p1 = str(data.get("player1_username", ""))
		var p2 = str(data.get("player2_username", ""))
		var mid := str(data.get("match_id", file_name.get_basename()))
		var played := _record_timestamp(data, file_name)
		if not is_excluded_user(p1):
			for path in data.get("player1_team", []):
				record_character(str(path), match_type, p1 == winner)
				record_character_appearance(mid, str(path), match_type, p1 == winner, played)
				written += 1
		if not is_excluded_user(p2):
			for path in data.get("player2_team", []):
				record_character(str(path), match_type, p2 == winner)
				record_character_appearance(mid, str(path), match_type, p2 == winner, played)
				written += 1
	db.query("COMMIT")
	print("[STATS_DB] Backfill from match records wrote ", written, " character rows")
	return written


## Backfill ONLY the per-appearance table, for the case where character_usage was already
## populated by an earlier build (so the is_empty() guard on the aggregate backfill is
## false) but character_match is still empty. Without this, existing installs would have
## no history to window over and date filtering would look broken until enough new matches
## accumulated. record_character_appearance is INSERT OR IGNORE, so this is safe to re-run.
func backfill_appearances(matches_dir: String = MATCHES_DIR) -> int:
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
		var match_type = int(data.get("match_type", -1))
		if match_type == BattleManager.MatchType.PRIVATE:
			continue
		var winner = str(data.get("winner_username", ""))
		var p1 = str(data.get("player1_username", ""))
		var p2 = str(data.get("player2_username", ""))
		var mid := str(data.get("match_id", file_name.get_basename()))
		var played := _record_timestamp(data, file_name)
		if not is_excluded_user(p1):
			for path in data.get("player1_team", []):
				record_character_appearance(mid, str(path), match_type, p1 == winner, played)
				written += 1
		if not is_excluded_user(p2):
			for path in data.get("player2_team", []):
				record_character_appearance(mid, str(path), match_type, p2 == winner, played)
				written += 1
	db.query("COMMIT")
	print("[STATS_DB] Appearance backfill wrote ", written, " rows")
	return written


## Unix seconds for a historical record. Records carry a `date` dict
## {year, month, day, hour, minute, second}; fall back to the YYYYMMDD prefix on the
## filename, and finally to 0 (which simply lands outside any real window rather than
## inventing a plausible-looking timestamp).
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
