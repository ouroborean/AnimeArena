# Throwaway (backend port proof): generate a card for EVERY roster character, so the port is proven
# against the whole character space (archetype-count 1..5, same-universe size 0..8) rather than a
# hand-picked sample. Alternates unlock/mastery so both seed shapes are covered across the roster.
#   godot --headless --path . --script res://training/tests/bounty_roster_probe.gd
extends SceneTree

func _init():
	var rows := []
	var t0 := Time.get_ticks_msec()
	var i := 0
	for p in CharacterDatabase.char_name_list():
		var btype := "mastery" if i % 2 == 1 else "unlock"
		var rr := str(i % 4)          # sweep reroll counts 0..3 across the roster too
		var seed_input: String = "portproof" + p + rr
		if btype == "mastery":
			seed_input += Bounty.MASTERY_SUFFIX
		var b = Bounty.get_bounty("portproof", p, rr, btype)
		rows.append({
			"group": "roster",
			"player": "portproof", "path": p, "rerolls": rr, "type": btype,
			"seed_input": seed_input, "seed_hash": hash(seed_input),
			"missions": b.missions,
		})
		b.free()
		i += 1
		if i % 25 == 0:
			print("  ...", i, "/174 (", Time.get_ticks_msec() - t0, "ms)")
	DirAccess.make_dir_recursive_absolute("res://backend_port/bounty")
	var f := FileAccess.open("res://backend_port/bounty/roster_fixture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"cases": rows}, "  ", false))
	f.close()
	print("[ROSTER] cases=", rows.size(), " ms=", Time.get_ticks_msec() - t0)
	quit()
