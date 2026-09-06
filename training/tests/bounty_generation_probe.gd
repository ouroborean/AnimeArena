# Throwaway (backend port proof): run the REAL Bounty.get_bounty over a matrix of inputs and dump
# every resulting 25-square card, so a non-Godot generator can be diffed square-for-square.
# Read-only: it never touches ausers/ or any live state, it only re-derives cards from inputs.
#   godot --headless --path . --script res://training/tests/bounty_generation_probe.gd
extends SceneTree

func _init():
	var cases := []

	# --- Group A: the EXACT inputs currently in flight on this server. -------------------------
	# (usernames + bounty keys were read out of ausers/*.dat read-only; rerolls are 0 for all
	# three accounts, and server_connection.gd looks rerolls up under the SUFFIXED key.)
	var live := [
		["Cheshire", "uranus", "0", "mastery"],
		["Dimbly", "cell", "0", "unlock"],
		["Dimbly", "rakko", "0", "unlock"],
		["Dimbly", "uranus", "0", "unlock"],
		["Suffering", "byakuya", "0", "unlock"],
		["Suffering", "kitara", "0", "unlock"],
		["Suffering", "todoroki", "0", "unlock"],
		["Suffering", "stark", "0", "mastery"],
	]
	for l in live:
		cases.append({"player": l[0], "path": l[1], "rerolls": l[2], "type": l[3], "group": "live"})

	# --- Group B: synthetic matrix. -----------------------------------------------------------
	# Usernames stress the hash (space, empty, Latin-1, CJK, an ASTRAL code point that a naive
	# UTF-16 port would hash as two surrogates). Paths stress the branch structure:
	#   naruto      2 archetypes, 6 same-universe others
	#   goku        1 archetype  (bounty_types has length 1 -> randi_range(0,0), still a draw)
	#   jinwoo      5 archetypes, SOLO universe -> universe list EMPTY -> the specific_odds==1
	#               branch is skipped and NO extra draw happens
	#   denji       2 archetypes, exactly 1 same-universe other
	#   lizandpatty 1 archetype, member of a category that contains a NON-roster ghost entry
	var usernames := ["abc", "Player One", "ÄÖÜ日本語" + String.chr(0x1F642), ""]
	var paths := ["naruto", "goku", "jinwoo", "denji", "lizandpatty"]
	for u in usernames:
		for p in paths:
			for rr in ["0", "1", "2", "3"]:
				for t in ["unlock", "mastery"]:
					cases.append({"player": u, "path": p, "rerolls": rr, "type": t, "group": "matrix"})

	var rows := []
	var t0 := Time.get_ticks_msec()
	var i := 0
	for c in cases:
		var seed_input: String = c.player + c.path + str(c.rerolls)
		if c.type == "mastery":
			seed_input += Bounty.MASTERY_SUFFIX
		var b = Bounty.get_bounty(c.player, c.path, c.rerolls, c.type)
		rows.append({
			"group": c.group,
			"player": c.player,
			"path": c.path,
			"rerolls": c.rerolls,
			"type": c.type,
			"seed_input": seed_input,
			"seed_hash": hash(seed_input),
			"requires_bounty_target": b.requires_bounty_target,
			"bounty_target_path": b.bounty_target_path,
			"bounty_path": b.bounty_path,
			"missions": b.missions,
		})
		b.free()
		i += 1
		if i % 20 == 0:
			print("  ...", i, "/", cases.size(), " (", Time.get_ticks_msec() - t0, "ms)")

	DirAccess.make_dir_recursive_absolute("res://backend_port/bounty")
	var f := FileAccess.open("res://backend_port/bounty/generation_fixture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"cases": rows}, "  ", false))
	f.close()
	print("[GENERATION] cases=", rows.size(), " ms=", Time.get_ticks_msec() - t0)
	quit()
