class_name MatchReplayPlayer
extends Node

signal replay_ready(p1_player, p2_player, snapshot, match_type)
signal replay_finished()

var replay_log: MatchReplayLog
var current_turn_index: int = -1
var playing: bool = false
var playback_speed: float = 1.0
var _battle_manager: BattleManager

var _step_timer: Timer


func _ready():
	_step_timer = Timer.new()
	_step_timer.one_shot = true
	_step_timer.timeout.connect(_advance_turn)
	add_child(_step_timer)


func load_replay(path: String) -> bool:
	replay_log = MatchReplayLog.load_from_file(path)
	if replay_log == null:
		return false
	current_turn_index = -1
	playing = false
	return true


func load_replay_from_log(log: MatchReplayLog) -> void:
	replay_log = log
	current_turn_index = -1
	playing = false


func bind_manager(manager: BattleManager) -> void:
	_battle_manager = manager


func start_playback() -> void:
	if replay_log == null or _battle_manager == null:
		return
	playing = true
	_schedule_next()


func pause_playback() -> void:
	playing = false
	_step_timer.stop()


func toggle_playback() -> void:
	if playing:
		pause_playback()
	else:
		start_playback()


func step_forward() -> void:
	if replay_log == null or _battle_manager == null:
		return
	_advance_turn()


func set_speed(speed: float) -> void:
	playback_speed = clamp(speed, 0.25, 4.0)


func is_at_end() -> bool:
	if replay_log == null:
		return true
	return current_turn_index >= replay_log.turn_count() - 1


func _schedule_next() -> void:
	if not playing or is_at_end():
		return
	var delay = 2.0 / playback_speed
	_step_timer.wait_time = delay
	_step_timer.start()


func _advance_turn() -> void:
	if replay_log == null or _battle_manager == null:
		return
	current_turn_index += 1
	if current_turn_index >= replay_log.turn_count():
		playing = false
		replay_finished.emit()
		return

	var events = replay_log.get_turn_events(current_turn_index)
	var snapshot = replay_log.get_turn_snapshot(current_turn_index)
	_battle_manager.apply_turn_result(events, snapshot)

	if is_at_end():
		playing = false
		replay_finished.emit()
	elif playing:
		_schedule_next()
