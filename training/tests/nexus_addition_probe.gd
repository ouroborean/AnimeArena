extends Node
# Verify the 4 new Nexus concepts resolve end-to-end: keith/akiza (YUGIOH) + clare/teresa (new CLAYMORE
# universe). Checks all_chars resolution, non-null imported portraits, correct universe, not-removed, the
# CLAYMORE enum value, and that get_all_bucket_sets serializes each with the right universe-name string.
func _ready():
	print("=== Nexus addition probe ===")
	var fails := 0
	var expect := {"keith": "YUGIOH", "akiza": "YUGIOH", "clare": "CLAYMORE", "teresa": "CLAYMORE"}
	var uni_keys = CharacterConcept.Universe.keys()

	# CLAYMORE must exist and be appended LAST (ordinals are persisted).
	if uni_keys.has("CLAYMORE"):
		print("  PASS  CLAYMORE in Universe enum (ordinal ", int(CharacterConcept.Universe.CLAYMORE), ", last=", uni_keys[-1] == "CLAYMORE", ")")
	else:
		fails += 1; print("  FAIL  CLAYMORE missing from Universe enum")

	var bh = BucketHandler.new()

	for k in expect:
		if not bh.all_chars.has(k):
			fails += 1; print("  FAIL  all_chars missing '", k, "'"); continue
		var c = bh.all_chars[k]
		if c == null:
			fails += 1; print("  FAIL  concept null: ", k); continue
		# universe correct
		var uname = uni_keys[int(c.universe)]
		if uname == expect[k]:
			print("  PASS  ", k, " -> universe ", uname)
		else:
			fails += 1; print("  FAIL  ", k, " universe = ", uname, " (expected ", expect[k], ")")
		# name set (client uses char_index, but sanity-check the server display name)
		if c.character_name == "" :
			fails += 1; print("  FAIL  ", k, " has empty character_name")
		# portrait imported + non-null (this only passes AFTER --import)
		if c.portrait_texture != null:
			print("  PASS  ", k, " portrait loaded (", c.portrait_texture.get_width(), "x", c.portrait_texture.get_height(), ")")
		else:
			fails += 1; print("  FAIL  ", k, " portrait_texture is null (import missing?)")
		# must NOT be removed
		if bh._is_removed(k):
			fails += 1; print("  FAIL  ", k, " reads as removed")

	# End-to-end: build buckets and confirm the 4 serialize with the correct universe string.
	bh.initialize_buckets()
	var res = bh.get_all_bucket_sets()
	var sets = res[1]
	var seen := {}
	for row in sets:
		if row[0] in expect:
			seen[row[0]] = row[2]
	for k in expect:
		if not seen.has(k):
			fails += 1; print("  FAIL  ", k, " absent from get_all_bucket_sets output")
		elif seen[k] == expect[k]:
			print("  PASS  serialized ", k, " ap-row universe = ", seen[k])
		else:
			fails += 1; print("  FAIL  serialized ", k, " universe = ", seen[k], " (expected ", expect[k], ")")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
