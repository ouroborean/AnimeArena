class_name MatchReplayLog
extends RefCounted

const REPLAY_DIR = "replays/"
const REPLAY_VERSION = 2

var match_id: String = ""
var match_type: int = 0
var date: Dictionary = {}
var p1_username: String = ""
var p2_username: String = ""
var p1_characters: Array = []
var p2_characters: Array = []
# v2: full display_package() dicts captured at match start — the same shape the
# battle client already renders as the opponent info card (username, rank/rating,
# frames, hats, title, avatar_url, clan, ...). {} on v1 replays.
var p1_display: Dictionary = {}
var p2_display: Dictionary = {}
var first_player_role: String = "p1"
var winner_role: String = ""
var initial_snapshot: Dictionary = {}
var turns: Array = []


static func begin(match_obj) -> MatchReplayLog:
	var log = MatchReplayLog.new()
	log.date = Time.get_datetime_dict_from_system(true)
	log.match_id = match_obj.match_uid if match_obj.match_uid != "" else str(match_obj.match_id)
	log.match_type = match_obj.match_type

	var keys = match_obj.players.keys()
	if keys.size() >= 2:
		var p1 = match_obj.players[keys[0]]
		var p2 = match_obj.players[keys[1]]
		log.p1_username = p1.username
		log.p2_username = p2.username
		for character in p1.team.characters:
			log.p1_characters.append(character.path_name)
		for character in p2.team.characters:
			log.p2_characters.append(character.path_name)
		log.p1_display = p1.display_package()
		log.p2_display = p2.display_package()

	var acting_key = match_obj.acting_player
	log.first_player_role = "p1" if acting_key == keys[0] else "p2"
	return log


func record_initial_snapshot(snapshot: Dictionary) -> void:
	initial_snapshot = snapshot.duplicate(true)


func record_turn(events: Array, snapshot: Dictionary) -> void:
	turns.append({
		"events": events.duplicate(true),
		"snapshot": snapshot.duplicate(true),
	})


func set_winner(winner_username: String) -> void:
	if winner_username == p1_username:
		winner_role = "p1"
	elif winner_username == p2_username:
		winner_role = "p2"


func finalize(winner_username: String) -> void:
	set_winner(winner_username)
	save_to_file()


func save_to_file() -> void:
	download_as_file()


# Triggers a browser download of the replay JSON.
func download_as_file() -> void:
	var json_string = JSON.stringify(to_dict())
	var filename = match_id + ".replay"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(json_string.to_utf8_buffer(), filename)
		print("[REPLAY] Browser download triggered: ", filename)
	else:
		# Fallback for non-web: save to user:// directory
		var path = "res://" + filename
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_line(json_string)
			print("[REPLAY] Written to ", path, " (", turns.size(), " turns)")
		else:
			push_warning("[REPLAY] Failed to write ", path)


func to_dict() -> Dictionary:
	return {
		"version": REPLAY_VERSION,
		"match_id": match_id,
		"match_type": match_type,
		"date": date,
		"p1_username": p1_username,
		"p2_username": p2_username,
		"p1_characters": p1_characters,
		"p2_characters": p2_characters,
		"first_player_role": first_player_role,
		"winner_role": winner_role,
		"p1_display": p1_display,
		"p2_display": p2_display,
		"initial_snapshot": initial_snapshot,
		"turns": turns,
	}


static func from_dict(data: Dictionary) -> MatchReplayLog:
	var log = MatchReplayLog.new()
	log.match_id = str(data.get("match_id", ""))
	log.match_type = int(data.get("match_type", 0))
	log.date = data.get("date", {})
	log.p1_username = data.get("p1_username", "")
	log.p2_username = data.get("p2_username", "")
	log.p1_characters = data.get("p1_characters", [])
	log.p2_characters = data.get("p2_characters", [])
	log.first_player_role = data.get("first_player_role", "p1")
	log.winner_role = data.get("winner_role", "")
	# v1 replays have no display packages — default {} so they still parse.
	log.p1_display = data.get("p1_display", {})
	log.p2_display = data.get("p2_display", {})
	log.initial_snapshot = data.get("initial_snapshot", {})
	log.turns = data.get("turns", [])
	return log


static func load_from_file(path: String) -> MatchReplayLog:
	if not FileAccess.file_exists(path):
		push_warning("[REPLAY] File not found: ", path)
		return null
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[REPLAY] Cannot open: ", path)
		return null
	return from_json_string(file.get_line())


static func from_json_string(json_string: String) -> MatchReplayLog:
	var json = JSON.new()
	var result = json.parse(json_string)
	if result != OK:
		push_warning("[REPLAY] Parse error: ", json.get_error_message())
		return null
	var data = json.get_data()
	if not data is Dictionary:
		push_warning("[REPLAY] Invalid replay format")
		return null
	return from_dict(data)


func turn_count() -> int:
	return turns.size()


func get_turn_events(index: int) -> Array:
	if index < 0 or index >= turns.size():
		return []
	return turns[index].get("events", [])


func get_turn_snapshot(index: int) -> Dictionary:
	if index < 0 or index >= turns.size():
		return {}
	return turns[index].get("snapshot", {})
