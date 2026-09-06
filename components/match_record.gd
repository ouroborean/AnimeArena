class_name MatchRecord
extends RefCounted

var match_id: String
var match_type: int
var date: Dictionary
var player1_username: String
var player2_username: String
var player1_team: Array
var player2_team: Array
var winner_username: String
var loser_username: String


static func create(match_obj, winner: String) -> MatchRecord:
	var record = MatchRecord.new()
	record.date = Time.get_datetime_dict_from_system(true)
	record.match_id = match_obj.match_uid if match_obj.match_uid != "" else ("%04d%02d%02d_%d" % [int(record.date.get("year", 0)), int(record.date.get("month", 0)), int(record.date.get("day", 0)), randi()])
	record.match_type = match_obj.match_type

	var players_list = match_obj.players.values()
	if players_list.size() >= 2:
		record.player1_username = players_list[0].username
		record.player2_username = players_list[1].username
		record.player1_team = _get_team_paths(players_list[0])
		record.player2_team = _get_team_paths(players_list[1])
	elif players_list.size() == 1:
		record.player1_username = players_list[0].username
		record.player1_team = _get_team_paths(players_list[0])

	record.winner_username = winner
	if record.player1_username == winner:
		record.loser_username = record.player2_username
	else:
		record.loser_username = record.player1_username

	return record


static func _get_team_paths(player) -> Array:
	var paths = []
	for character in player.team.characters:
		paths.append(character.path_name)
	return paths


func to_dict() -> Dictionary:
	return {
		"match_id": match_id,
		"match_type": match_type,
		"date": date,
		"player1_username": player1_username,
		"player2_username": player2_username,
		"player1_team": player1_team,
		"player2_team": player2_team,
		"winner_username": winner_username,
		"loser_username": loser_username,
	}


static func from_dict(data: Dictionary) -> MatchRecord:
	var record = MatchRecord.new()
	record.match_id = data.get("match_id", "")
	record.match_type = data.get("match_type", 0)
	record.date = data.get("date", {})
	record.player1_username = data.get("player1_username", "")
	record.player2_username = data.get("player2_username", "")
	record.player1_team = data.get("player1_team", [])
	record.player2_team = data.get("player2_team", [])
	record.winner_username = data.get("winner_username", "")
	record.loser_username = data.get("loser_username", "")
	return record
