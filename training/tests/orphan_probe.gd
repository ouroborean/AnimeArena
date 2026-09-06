extends Node

# Memory-leak probe: measures ORPHANED NODES created per full battle lifecycle
# (build -> play several bot turns -> tear down -> settle frames). Orphans are
# Nodes outside the scene tree that nothing freed — the server leak signature
# (478k orphans after one active day).
# Run: godot --headless --path <repo> res://training/tests/orphan_probe.tscn
# Exit code 0 when the per-battle orphan delta is small (post-fix), 1 otherwise.

const CYCLES := 3
const TURNS_PER_BATTLE := 12

var _pending := -1
var _over := false
var manager: BattleManager = null

func orphans() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy: bool = (u == "BotEnemy")
	for cn in names: p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func _on_turn(_a): _pending = 0
func _on_wait(): _pending = 1
func _on_end(_won): _over = true
func _on_panel(_t, _r, exec_order: Dictionary):
	var order: Array = []
	for key in exec_order.keys(): order.append(key)
	manager.allotment_accepted(order, [])

func _ready():
	print("=== orphan-per-battle probe ===")
	var deltas: Array = []
	for cycle in range(CYCLES):
		var before := orphans()
		manager = BattleManager.new()
		manager.name = "BattleManager"
		manager.shadow_mode = true
		add_child(manager)
		var p1 := _build_player("BotPlayer", ["naruto", "orihime", "diane"])
		var p2 := _build_player("BotEnemy", ["eren", "mash", "squalo"])
		_pending = -1; _over = false
		manager.turn_started.connect(_on_turn)
		manager.waiting_for_opponent.connect(_on_wait)
		manager.match_ended.connect(_on_end)
		manager.random_panel_needed.connect(_on_panel)
		seed(1000 + cycle)   # legacy bot decision RNG
		manager.start_battle(p1, p2, true, 1000 + cycle, BattleManager.MatchType.BOT)
		var steps := 0
		while not _over and steps < TURNS_PER_BATTLE and _pending != -1:
			var side := _pending
			_pending = -1
			var player_obj = manager.player if side == 0 else manager.enemy
			if side == 1:
				manager.generate_team_energy(manager.enemy.team, manager.went_second)
				manager.went_second = false
			player_obj.perform_turn_random(manager, null, side)
			steps += 1
		manager.queue_free()
		manager = null
		for i in range(4):
			await get_tree().process_frame
		var delta := orphans() - before
		deltas.append(delta)
		print("  cycle %d: %d turns, orphan delta = %+d  (total orphans now %d)" % [cycle, steps, delta, orphans()])
	var worst := 0
	for d in deltas: worst = maxi(worst, int(d))
	print("=== worst per-battle orphan delta: %d ===" % worst)
	# Post-fix target: a handful at most. Pre-fix this is hundreds per battle.
	get_tree().quit(0 if worst <= 25 else 1)
