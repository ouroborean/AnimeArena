# Throwaway (backend port proof): exercise the ONE branch of generate_from_details the main matrix
# cannot reach — `bounty_types.is_empty()` falling back to categories.keys(). Every roster character
# belongs to at least one archetype today, so the only way in is a path_name that exists as a
# character scene but is not in any category: "vessel" (the campaign avatar, absent from
# char_name_list too, so by_universe excludes nothing).
# Also covers a multi-digit reroll count, since rerolls are string-concatenated into the seed.
#   godot --headless --path . --script res://training/tests/bounty_fallback_probe.gd
extends SceneTree

func _init():
	var cases := [
		["abc", "vessel", "0", "unlock"],
		["abc", "vessel", "0", "mastery"],
		["Dimbly", "vessel", "2", "unlock"],
		["Dimbly", "cell", "10", "unlock"],   # two-digit reroll -> different seed string
		["Dimbly", "cell", "12", "mastery"],
	]
	var rows := []
	for c in cases:
		var seed_input: String = c[0] + c[1] + str(c[2])
		if c[3] == "mastery":
			seed_input += Bounty.MASTERY_SUFFIX
		var b = Bounty.get_bounty(c[0], c[1], c[2], c[3])
		rows.append({
			"group": "fallback",
			"player": c[0], "path": c[1], "rerolls": c[2], "type": c[3],
			"seed_input": seed_input, "seed_hash": hash(seed_input),
			"missions": b.missions,
		})
		b.free()

	# The off-roster paths need their universe published too, or a non-Godot generator cannot
	# resolve universe_dict[character.universe] for them.
	var extra := {}
	for n in ["vessel"]:
		var ch = Character.from_character_name(n)
		extra[n] = ch.universe
		ch.free()

	DirAccess.make_dir_recursive_absolute("res://backend_port/bounty")
	var f := FileAccess.open("res://backend_port/bounty/fallback_fixture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"cases": rows, "off_roster_universes": extra}, "  ", false))
	f.close()
	print("[FALLBACK] cases=", rows.size(), " off_roster_universes=", extra)
	quit()
