class_name StatsManager
extends RefCounted

const STATS_DIR = "stats/"
const MATCHES_DIR = "stats/matches/"

# Set by ServerConnection on server-side boot. Stays null on client-side
# StatsManager instances, so _award_mastery_xp skips the DB write cleanly.
var mastery_db: MasteryDB = null


func _init():
	if not DirAccess.dir_exists_absolute(STATS_DIR):
		DirAccess.make_dir_absolute(STATS_DIR)
	if not DirAccess.dir_exists_absolute(MATCHES_DIR):
		DirAccess.make_dir_absolute(MATCHES_DIR)


func record_match(match_obj, winner_username: String) -> MatchRecord:
	if not _should_record(match_obj):
		print("[STATS] Skipping record — match type ", match_obj.match_type, " is not recorded")
		return null

	var record = MatchRecord.create(match_obj, winner_username)
	print("[STATS] Recording match ", record.match_id, ": ", record.player1_username, " vs ", record.player2_username, " — winner: ", winner_username)
	_write_match_record(record)
	_update_character_aggregates(record)
	_award_mastery_xp(match_obj, winner_username)
	return record


func _should_record(match_obj) -> bool:
	if match_obj.match_type == BattleManager.MatchType.PRIVATE:
		return false
	if match_obj.match_type == BattleManager.MatchType.BOT:
		return false
	# Ranked can now seat a BOT (the 30s ranked fallback), and a bot seat is not meta data: its
	# username is a throwaway and its team is random, so recording one would put fake players in the
	# match archive and fold noise into every character's global win rate.
	for peer_id in match_obj.players:
		if match_obj.players[peer_id].bot_player:
			return false
	return true


func get_character_stats(character_name: String) -> Dictionary:
	return _load_character_stats(character_name)


# --- Persistence ---

func _write_match_record(record: MatchRecord):
	var path = MATCHES_DIR + record.match_id + ".json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_line(JSON.stringify(record.to_dict()))
		print("[STATS] Match record written to ", path)
	else:
		print("[STATS] ERROR: Could not write match record to ", path)


func _update_character_aggregates(record: MatchRecord):
	var all_chars = []
	for char_name in record.player1_team:
		all_chars.append({
			"name": char_name,
			"won": record.player1_username == record.winner_username,
			"partners": record.player1_team.filter(func(c): return c != char_name),
			"enemies": record.player2_team,
		})
	for char_name in record.player2_team:
		all_chars.append({
			"name": char_name,
			"won": record.player2_username == record.winner_username,
			"partners": record.player2_team.filter(func(c): return c != char_name),
			"enemies": record.player1_team,
		})

	for entry in all_chars:
		var stats = _load_character_stats(entry.name)
		stats["picks"] += 1
		if entry.won:
			stats["wins"] += 1
		else:
			stats["losses"] += 1

		for partner in entry.partners:
			if not partner in stats["partners"]:
				stats["partners"][partner] = {"wins": 0, "losses": 0, "picks": 0}
			stats["partners"][partner]["picks"] += 1
			if entry.won:
				stats["partners"][partner]["wins"] += 1
			else:
				stats["partners"][partner]["losses"] += 1

		for enemy_name in entry.enemies:
			if not enemy_name in stats["enemies"]:
				stats["enemies"][enemy_name] = {"wins": 0, "losses": 0, "picks": 0}
			stats["enemies"][enemy_name]["picks"] += 1
			if entry.won:
				stats["enemies"][enemy_name]["wins"] += 1
			else:
				stats["enemies"][enemy_name]["losses"] += 1

		_save_character_stats(entry.name, stats)

	print("[STATS] Character aggregates updated for ", all_chars.size(), " character entries")


func _load_character_stats(character_name: String) -> Dictionary:
	var path = STATS_DIR + character_name + ".stats"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			var result = json.parse(file.get_line())
			if result == OK:
				var data = json.get_data()
				if data is Dictionary:
					if not "schema_version" in data:
						data["schema_version"] = 1
					if not "partners" in data:
						data["partners"] = {}
					if not "enemies" in data:
						data["enemies"] = {}
					return data

	return {
		"schema_version": 1,
		"wins": 0,
		"losses": 0,
		"picks": 0,
		"partners": {},
		"enemies": {},
	}


func _save_character_stats(character_name: String, stats: Dictionary):
	var path = STATS_DIR + character_name + ".stats"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_line(JSON.stringify(stats))


func _award_mastery_xp(match_obj, winner_username: String):
	for peer_id in match_obj.players:
		var player = match_obj.players[peer_id]
		var won = (player.username == winner_username)
		for character in player.team.characters:
			var before_xp = player.character_progress.get_xp(character.path_name)
			if won:
				player.character_progress.award_xp(character.path_name, MasteryConfig.XP_PER_WIN)
			else:
				player.character_progress.deduct_xp(character.path_name, MasteryConfig.XP_PER_LOSS)
			var after_xp = player.character_progress.get_xp(character.path_name)
			var after_level = player.character_progress.get_level(character.path_name)
			if mastery_db != null:
				mastery_db.upsert_xp(player.username, character.path_name, after_xp)
