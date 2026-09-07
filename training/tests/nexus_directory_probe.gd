extends Node
# Verifies the disk-driven Nexus: membership now comes from the <path>.dat files in the bucket-data
# directory, not the static all_chars catalogue. Runs entirely inside a throwaway temp directory (via
# BucketHandler.bucket_data_dir_override) so it never touches the real, git-tracked `bucket data/`.
#
# Covered:
#   1  a catalogued character with a .dat appears, with its all_chars universe
#   2  a disk-only character (NOT in all_chars) with a .dat appears, universe from nexus_meta.json
#   3  a disk-only character with no nexus_meta entry appears with universe "" (leaderboard-only)
#   4  deleting a .dat removes the character on the next initialize_buckets
#   5  an already-playable character (char_name_list) with a .dat is auto-excluded
#   6  a removed_list.dat / permanently-excluded character stays hidden
#   7  reserved files (poll.dat, removed_list.dat) + nexus_meta.json are never treated as buckets
#   8  AP is read from the file; donation via process_bucket_update persists back to the file
#   9  has_character_bucket gates donations to live buckets only

var fails := 0
var tmp := ""

func _ready():
	print("=== Nexus directory-driven probe ===")
	tmp = "user://nexus_probe_%d" % (Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	# Resolve to an absolute OS path so FileAccess/DirAccess in the handler (which use it verbatim) work.
	var abs := ProjectSettings.globalize_path(tmp)

	# --- fixture: write .dat files + a nexus_meta.json into the temp dir --------------------------
	_write(abs + "/keith.dat", "40")          # catalogued (YUGIOH)
	_write(abs + "/brandnew.dat", "25")       # disk-only, described by nexus_meta
	_write(abs + "/mystery.dat", "7")         # disk-only, no meta -> universe ""
	_write(abs + "/naruto.dat", "999")        # already playable -> excluded
	_write(abs + "/poll.dat", "1")            # reserved
	_write(abs + "/removed_list.dat", "")     # reserved (starts empty)
	_write(abs + "/nexus_meta.json", '{"brandnew": {"universe": "ONE_PIECE", "name": "Brand New"}}')

	var bh = BucketHandler.new()
	bh.bucket_data_dir_override = abs
	bh.initialize_buckets()

	var uni := _uni_map(bh)     # path -> universe string from get_all_bucket_sets

	# 1 catalogued appears with catalogue universe
	_check("keith present", uni.has("keith"))
	_check("keith universe YUGIOH", uni.get("keith", "") == "YUGIOH")
	# 2 disk-only w/ meta appears, universe from meta
	_check("brandnew present (disk-only, not in all_chars)", uni.has("brandnew"))
	_check("brandnew universe from nexus_meta = ONE_PIECE", uni.get("brandnew", "") == "ONE_PIECE")
	_check("brandnew not in all_chars catalogue", not bh.all_chars.has("brandnew"))
	# 3 disk-only w/o meta -> universe ""
	_check("mystery present", uni.has("mystery"))
	_check("mystery universe blank (leaderboard-only)", uni.get("mystery", "X") == "")
	# 5 playable auto-excluded
	_check("naruto auto-excluded (already playable)", not uni.has("naruto"))
	_check("has_character_bucket(naruto) == false", not bh.has_character_bucket("naruto"))
	# 7 reserved files never buckets
	_check("poll not a bucket", not uni.has("poll"))
	_check("removed_list not a bucket", not uni.has("removed_list"))
	_check("nexus_meta not a bucket", not uni.has("nexus_meta"))
	# 8 AP read from file
	_check("keith ap read as 40", bh.all_buckets["keith"].ap == 40)
	# 9 donation gating + persistence
	_check("has_character_bucket(brandnew) == true", bh.has_character_bucket("brandnew"))
	bh.process_bucket_update("brandnew", 10)
	_check("brandnew ap now 35 in memory", bh.all_buckets["brandnew"].ap == 35)
	_check("brandnew.dat persisted 35 to disk", _read_int(abs + "/brandnew.dat") == 35)

	# 4 deletion removes membership on next build
	DirAccess.remove_absolute(abs + "/keith.dat")
	bh.initialize_buckets()
	var uni2 := _uni_map(bh)
	_check("keith gone after its .dat deleted", not uni2.has("keith"))
	_check("brandnew still present after rebuild", uni2.has("brandnew"))
	_check("brandnew ap survived rebuild (35 from disk)", bh.all_buckets["brandnew"].ap == 35)

	# 6 removed_list / permanent exclusion stays hidden
	_write(abs + "/removed_list.dat", "brandnew")   # admin-removed
	bh.initialize_buckets()
	var uni3 := _uni_map(bh)
	_check("brandnew hidden once in removed_list.dat", not uni3.has("brandnew"))
	_check("has_character_bucket(brandnew) false when removed", not bh.has_character_bucket("brandnew"))
	if not bh.PERMANENT_EXCLUDED.is_empty():
		var perm = bh.PERMANENT_EXCLUDED[0]
		_write(abs + "/" + perm + ".dat", "500")
		bh.initialize_buckets()
		_check("permanently-excluded '%s' hidden despite its .dat" % perm, not _uni_map(bh).has(perm))

	# --- periodic refresh: refresh_from_disk change-detection (the poll's core) -------------------
	# Reset to a clean baseline for these (drop the removed_list + muichiro fixtures from block 6).
	_write(abs + "/removed_list.dat", "")
	DirAccess.remove_absolute(abs + "/" + bh.PERMANENT_EXCLUDED[0] + ".dat")
	bh.initialize_buckets()
	_check("refresh_from_disk() == false when disk is unchanged (no broadcast)", bh.refresh_from_disk() == false)
	_write(abs + "/newcomer.dat", "12")
	_check("refresh true after a .dat is ADDED", bh.refresh_from_disk() == true)
	_check("newcomer now in roster", _uni_map(bh).has("newcomer"))
	_check("refresh false once settled again", bh.refresh_from_disk() == false)
	_write(abs + "/newcomer.dat", "80")
	_check("refresh true after an external AP EDIT", bh.refresh_from_disk() == true)
	_check("newcomer ap now 80 from disk", bh.all_buckets["newcomer"].ap == 80)
	# A donation writes through to disk + memory, so a following poll must find NOTHING new (else every
	# donation would double-broadcast: once as update_buckets, once as a redundant nexus_state).
	bh.process_bucket_update("newcomer", 5)
	_check("refresh FALSE after a write-through donation (no redundant broadcast)", bh.refresh_from_disk() == false)
	_check("newcomer ap 85 after donation", bh.all_buckets["newcomer"].ap == 85)
	DirAccess.remove_absolute(abs + "/newcomer.dat")
	_check("refresh true after a .dat is DELETED", bh.refresh_from_disk() == true)
	_check("newcomer gone from roster", not _uni_map(bh).has("newcomer"))
	# External edit to removed_list.dat must also be picked up by the poll.
	_write(abs + "/temp2.dat", "9")
	bh.refresh_from_disk()
	_check("temp2 present before external removal", _uni_map(bh).has("temp2"))
	_write(abs + "/removed_list.dat", "temp2")
	_check("refresh true after external removed_list.dat edit", bh.refresh_from_disk() == true)
	_check("temp2 hidden after external removed_list edit", not _uni_map(bh).has("temp2"))
	# Repeated rebuilds don't accumulate (roster reflects disk each time, size stays put).
	var sz = bh.all_buckets.size()
	bh.refresh_from_disk(); bh.refresh_from_disk()
	_check("roster size stable across repeated refreshes", bh.all_buckets.size() == sz)

	# --- fix guards: concept-free safety + unreadable-dir -----------------------------------------
	# A CATALOGUED concept in the live roster is the shared all_chars object and must NEVER be freed by
	# _free_bucket_nodes (only synthesized disk-only concepts are). akiza is in all_chars (YUGIOH).
	_write(abs + "/akiza.dat", "50")
	bh.refresh_from_disk()
	var akiza_concept = bh.all_chars.get("akiza")
	_check("catalogued bucket holds the shared all_chars concept", bh.all_buckets.has("akiza") and bh.all_buckets["akiza"].character_concept == akiza_concept)
	for i in range(4):
		bh.refresh_from_disk()
	_check("shared all_chars concept survives repeated rebuilds (identity guard, never freed)", is_instance_valid(akiza_concept) and bh.all_chars.get("akiza") == akiza_concept)
	# An unreadable bucket dir must keep the current roster + return false (no empty broadcast to clients).
	var saved_size = bh.all_buckets.size()
	bh.bucket_data_dir_override = abs + "/does_not_exist_dir"
	_check("refresh on an unreadable dir returns false", bh.refresh_from_disk() == false)
	_check("roster preserved (not wiped) when the dir is unreadable", bh.all_buckets.size() == saved_size)
	bh.bucket_data_dir_override = abs   # restore for cleanup

	# cleanup
	_rmdir(abs)
	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()

func _uni_map(bh) -> Dictionary:
	var out := {}
	var res = bh.get_all_bucket_sets()
	for row in res[1]:
		out[row[0]] = row[2]
	return out

func _check(label, cond) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		fails += 1
		print("  FAIL  ", label)

func _write(path, text) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)

func _read_int(path) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var f = FileAccess.open(path, FileAccess.READ)
	return int(f.get_line()) if f != null else -1

func _rmdir(abs) -> void:
	var dir = DirAccess.open(abs)
	if dir == null:
		return
	dir.list_dir_begin()
	var n = dir.get_next()
	while n != "":
		if not dir.current_is_dir():
			DirAccess.remove_absolute(abs + "/" + n)
		n = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(abs)
