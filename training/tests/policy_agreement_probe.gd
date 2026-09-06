extends Node

# WHY: three separate interventions (semantic features resumed, semantic features
# cold-started, potential-based reward shaping) all landed at 49-51% head-to-head
# against their controls at n>=2000. Two explanations remain and they imply totally
# different next steps:
#
#   (A) The policies are genuinely DIFFERENT but equally strong -> we are at a
#       ceiling set by the GAME (team draw / energy RNG decide most matches), and
#       more policy work is wasted effort.
#   (B) The policies are effectively the SAME BOT -> training converges to a narrow
#       attractor regardless of features or reward, and the bottleneck is the policy
#       class / optimiser, not the information we feed it.
#
# This measures it directly: over identical real decision states, how often do two
# checkpoints pick a DIFFERENT action? High agreement => (B).

var pass_n := 0

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	for cn in names:
		# char_name_list contains entries that cannot actually be built (no scene,
		# retired characters, the campaign-only Vessel). Skip rather than crash.
		var c = Character.from_character_name(cn)
		if c == null:
			continue
		p.recruit_character(c, u == "B")
	for c in p.team.characters:
		c.bot_character = true
	return p

## argmax (ability_name, target) for one character under one policy, T=0.
func _pick(pol, obs, character) -> String:
	var best_score := -INF
	var best := "none"
	for cand in obs.own_candidates(character):
		for scored in pol.score_candidate(obs, character, cand, {}, null):
			if scored["score"] > best_score:
				best_score = scored["score"]
				var tgt = scored["primary_target"]
				best = str(cand["ability"].ability_name) + "->" + (str(tgt.path_name) if tgt != null else "-")
	return best

func _ready() -> void:
	print("=== policy agreement probe ===")
	var paths := {
		"legacy_gen_8": "res://training/checkpoints/legacy_pre_semantic/gen_8.json",
		"cold_gen_5":   "res://training/checkpoints/control_noshaping/gen_5.json",
		"shaped_gen_5": "res://training/checkpoints/gen_5.json",
		"legacy_gen_1": "res://training/checkpoints/legacy_pre_semantic/gen_1.json",
	}
	var pols := {}
	for k in paths:
		if FileAccess.file_exists(paths[k]):
			pols[k] = BotPolicyV3.load_from_path(paths[k])
		else:
			printerr("  missing: %s" % paths[k])
	print("  loaded %d policies" % pols.size())

	# Draw teams from the LIVE roster rather than hard-coding names: several
	# characters have been removed over time (kakashi, uryuu, ...) and a stale name
	# crashes Character.from_character_name.
	# Fixed, known-buildable teams: a number of character .tscn files in
	# char_name_list have broken ext_resource UIDs and fail to load (kitara,
	# orihime, ...), which is a pre-existing data problem, not a probe problem.
	# Vary the SEED instead to reach different board states (energy, turn order).
	var rosters := []
	for k in range(8):
		rosters.append([["naruto", "gon", "ichigo"], ["eren", "misaka", "sakura"]])

	var names: Array = pols.keys()
	var agree := {}
	var total := 0
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			agree[names[i] + " vs " + names[j]] = 0

	for r in rosters:
		var m := BattleManager.new(); m.name = "BattleManager"; m.shadow_mode = true; add_child(m)
		var p1 := _build_player("A", r[0])
		var p2 := _build_player("B", r[1])
		m.start_battle(p1, p2, true, 777 + total, BattleManager.MatchType.BOT)
		var obs := BotObservation.for_player(m, p1)
		for character in p1.team.characters:
			if character.dead:
				continue
			if obs.own_candidates(character).is_empty():
				continue
			total += 1
			var picks := {}
			for k in names:
				picks[k] = _pick(pols[k], obs, character)
			for i in range(names.size()):
				for j in range(i + 1, names.size()):
					if picks[names[i]] == picks[names[j]]:
						agree[names[i] + " vs " + names[j]] += 1
			if total <= 3:
				for k in names:
					print("      %-14s -> %s" % [k, picks[k]])
				print("      ---")
		m.queue_free()

	print("")
	print("  decision states sampled: %d" % total)
	print("  PAIRWISE ARGMAX AGREEMENT:")
	for k in agree:
		var pct := 100.0 * float(agree[k]) / maxf(total, 1)
		print("    %-34s %5.1f%%" % [k, pct])
	print("")
	print("  High agreement (>80%%) => the interventions produce THE SAME BOT;")
	print("  low agreement => genuinely different policies of equal strength.")
	get_tree().quit(0)
