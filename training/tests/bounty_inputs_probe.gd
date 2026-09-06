# Throwaway: for a handful of paths, dump the EXACT per-path inputs generate_from_details computes
# (bounty_types, the character's universe, the same-universe list) alongside the card, so a
# reimplementation mismatch can be localised to data rather than to the RNG.
#   godot --headless --path . --script res://training/tests/bounty_inputs_probe.gd
extends SceneTree

func _init():
	var out := []
	for p in ["goku", "lizandpatty", "denji", "naruto", "cell"]:
		var b = load("res://scripts/bounty.gd").new()
		var ci = Character.from_character_name(p)
		var ud = CharacterDatabase.by_universe(p)
		var row := {
			"path": p,
			"universe": ci.universe,
			"path_name_property": ci.path_name,
			"bounty_types": b.get_archetypes(p),
			"same_universe": ud[ci.universe],
			"same_universe_len": ud[ci.universe].size(),
		}
		ci.free()
		b.free()
		# and the real card for one fixed input, plus the raw draw stream from the same seed
		var seed_input: String = "abc" + p + "0"
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(seed_input)
		var mt_stream := []
		for i in range(10):
			mt_stream.append(rng.randi_range(0, 5))
		row["seed_input"] = seed_input
		row["seed_hash"] = hash(seed_input)
		row["ten_consecutive_randi_range_0_5"] = mt_stream
		var bb = Bounty.get_bounty("abc", p, "0", "unlock")
		row["missions_len"] = bb.missions.size()
		row["missions_first5"] = bb.missions.slice(0, 5)
		bb.free()
		out.append(row)
	DirAccess.make_dir_recursive_absolute("res://backend_port/bounty")
	var f := FileAccess.open("res://backend_port/bounty/inputs_fixture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": out}, "  ", false))
	f.close()
	for r in out:
		print("[INPUTS] ", r.path, " univ=", r.universe, " bt=", r.bounty_types,
			" |su|=", r.same_universe_len, " missions_len=", r.missions_len)
	quit()
