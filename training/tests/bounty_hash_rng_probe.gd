# Throwaway probe (backend port proof): dump Godot's String hashing and RandomNumberGenerator
# stream for a fixed set of inputs, so a non-Godot reimplementation can be diffed bit-for-bit.
# Reads nothing, writes one JSON fixture under backend_port/bounty/. Touches no game state.
#   godot --headless --path . --script res://training/tests/bounty_hash_rng_probe.gd
extends SceneTree

func _init():
	var out := {}

	# --- 1. String hashing -------------------------------------------------------------------
	# bounty.gd calls the GDScript GLOBAL hash() on a String. Dump BOTH that and String.hash()
	# for the same inputs: if they ever disagree the port must copy the one bounty.gd uses.
	var strings := [
		"",
		"a",
		"abc",
		"Cheshire",
		"Cheshireuranus0_mastery",
		"Dimblycell0",
		"Sufferingbyakuya0",
		"Player One",
		"0",
		"00",
		"naruto",
		"naruto0",
		"naruto1",
		"naruto10",
		"ÄÖÜ",              # Latin-1 supplement (2-byte UTF-8, single code points)
		"日本語",              # CJK (3-byte UTF-8)
		"\U0001f642",                      # emoji, outside the BMP (surrogate pair in UTF-16)
		"tail\U0001f642mixéd",
		"the quick brown fox jumps over the lazy dog 0123456789",
	]
	var hash_rows := []
	for s in strings:
		hash_rows.append({
			"s": s,
			"global_hash": hash(s),
			"string_hash": s.hash(),
			"utf32": Array(s.to_utf32_buffer()).size(),  # byte length sanity only
		})
	out["hashes"] = hash_rows

	# --- 2. Raw RNG stream -------------------------------------------------------------------
	# Prove what `.seed = X` + randi()/randi_range() actually emit. randi() is the raw 32-bit
	# pcg32 output; the randi_range rows pin the modulo mapping bounty.gd relies on.
	var seeds := [0, 1, 2, 42, 5381,
		hash("Dimblycell0"), hash("Cheshireuranus0_mastery"), hash("naruto0"),
		-1, 9223372036854775807, -9223372036854775808]
	var rng_rows := []
	for sd in seeds:
		var r := RandomNumberGenerator.new()
		r.seed = sd
		var raw := []
		for i in range(12):
			raw.append(r.randi())
		var r2 := RandomNumberGenerator.new()
		r2.seed = sd
		var rr := []
		# same shape of calls bounty.gd makes: small spans, then a couple of wide ones
		for i in range(8):
			rr.append(r2.randi_range(0, 5))
		for i in range(4):
			rr.append(r2.randi_range(0, 8))
		for i in range(4):
			rr.append(r2.randi_range(0, 38))
		# DEGENERATE + REVERSED ranges, interleaved with normal ones. bounty.gd hits
		# randi_range(0, 0) whenever a list has a single element (a character with one archetype,
		# or a universe with one other member) and whether that consumes a draw decides every
		# later square. The interleaving is what exposes it: the trailing normal draws shift if
		# and only if the degenerate calls advanced the stream.
		var r3 := RandomNumberGenerator.new()
		r3.seed = sd
		var deg := []
		deg.append(r3.randi_range(0, 5))
		deg.append(r3.randi_range(0, 0))     # degenerate
		deg.append(r3.randi_range(0, 5))
		deg.append(r3.randi_range(7, 7))     # degenerate, non-zero
		deg.append(r3.randi_range(0, 5))
		deg.append(r3.randi_range(5, 0))     # reversed (from > to)
		deg.append(r3.randi_range(0, 5))
		deg.append(r3.randi_range(-3, 3))    # negative from
		deg.append(r3.randi_range(0, 5))
		rng_rows.append({
			"seed_in": sd,
			"seed_readback": r.seed,
			"randi": raw,
			"randi_range": rr,
			"degenerate_mix": deg,
		})
	out["rng"] = rng_rows

	# --- 3. Engine identity ------------------------------------------------------------------
	out["engine"] = Engine.get_version_info()

	DirAccess.make_dir_recursive_absolute("res://backend_port/bounty")
	var f := FileAccess.open("res://backend_port/bounty/primitives_fixture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("[PRIMITIVES] strings=", hash_rows.size(), " seeds=", rng_rows.size(),
		" version=", Engine.get_version_info().string)
	print("  hash('abc')=", hash("abc"), "  String('abc').hash()=", "abc".hash())
	quit()
