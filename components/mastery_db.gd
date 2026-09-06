class_name MasteryDB
extends RefCounted

# Server-side SQLite wrapper for the character-mastery ladder.
#
# Schema is one row per (character_path, username) holding total XP.
# The (character_path, xp DESC) index makes top-N queries an index
# walk instead of a sort, so we don't have to scan every Player in
# memory and re-sort for each per-character ladder request.

const DB_FILE = "mastery.db"
const TOP_LIMIT_DEFAULT = 100

var db = null


func open_db(path: String = DB_FILE) -> bool:
	db = SQLite.new()
	db.path = path
	if not db.open_db():
		push_error("[MASTERY_DB] Failed to open " + path)
		db = null
		return false
	db.query("PRAGMA journal_mode = WAL")
	db.query("PRAGMA synchronous = NORMAL")
	db.query(
		"CREATE TABLE IF NOT EXISTS character_mastery ("
		+ "character_path TEXT NOT NULL, "
		+ "username       TEXT NOT NULL, "
		+ "xp             INTEGER NOT NULL DEFAULT 0, "
		+ "updated_at     INTEGER NOT NULL, "
		+ "PRIMARY KEY (character_path, username)) WITHOUT ROWID"
	)
	db.query(
		"CREATE INDEX IF NOT EXISTS idx_mastery_char_xp "
		+ "ON character_mastery (character_path, xp DESC)"
	)
	print("[MASTERY_DB] Opened ", path)
	return true


func close_db():
	if db:
		db.close_db()
		db = null


func upsert_xp(username: String, character_path: String, xp: int) -> void:
	if db == null:
		return
	var ts = int(Time.get_unix_time_from_system())
	db.query_with_bindings(
		"INSERT INTO character_mastery (character_path, username, xp, updated_at) "
		+ "VALUES (?, ?, ?, ?) "
		+ "ON CONFLICT(character_path, username) DO UPDATE SET "
		+ "xp = excluded.xp, updated_at = excluded.updated_at",
		[character_path, username, xp, ts]
	)


# Idempotent — safe to run on every server boot. Lets the DB self-heal
# if it's ever wiped or out-of-sync with the JSON player files.
func backfill_from_players(players_dict: Dictionary) -> int:
	if db == null:
		return 0
	var written = 0
	db.query("BEGIN TRANSACTION")
	var ts = int(Time.get_unix_time_from_system())
	for username in players_dict:
		var player = players_dict[username]
		if player == null or player.character_progress == null:
			continue
		for character_path in player.character_progress.xp_data:
			var xp = int(player.character_progress.xp_data[character_path])
			db.query_with_bindings(
				"INSERT INTO character_mastery (character_path, username, xp, updated_at) "
				+ "VALUES (?, ?, ?, ?) "
				+ "ON CONFLICT(character_path, username) DO UPDATE SET "
				+ "xp = excluded.xp, updated_at = excluded.updated_at",
				[character_path, username, xp, ts]
			)
			written += 1
	db.query("COMMIT")
	print("[MASTERY_DB] Backfill wrote ", written, " rows")
	return written


func get_top(character_path: String, limit: int = TOP_LIMIT_DEFAULT, offset: int = 0) -> Array:
	if db == null:
		return []
	db.query_with_bindings(
		"SELECT username, xp FROM character_mastery "
		+ "WHERE character_path = ? "
		+ "ORDER BY xp DESC LIMIT ? OFFSET ?",
		[character_path, limit, offset]
	)
	return db.query_result.duplicate()


func get_rank(character_path: String, username: String) -> Dictionary:
	if db == null:
		return {}
	db.query_with_bindings(
		"SELECT xp FROM character_mastery WHERE character_path = ? AND username = ?",
		[character_path, username]
	)
	if db.query_result.is_empty():
		return {}
	var my_xp = int(db.query_result[0]["xp"])
	db.query_with_bindings(
		"SELECT COUNT(*) AS higher FROM character_mastery "
		+ "WHERE character_path = ? AND xp > ?",
		[character_path, my_xp]
	)
	var higher = int(db.query_result[0]["higher"])
	return {"username": username, "xp": my_xp, "rank": higher + 1}
