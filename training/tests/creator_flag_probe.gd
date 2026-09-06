extends Node

# Probe for the Character Creator kill switch: default-off, admin exemption, and PERSISTENCE
# (an admin's decision must survive a restart, unlike the in-memory global-chat switch).
# Deliberately exercises the flag functions directly rather than over a socket, so it never has
# to create an account with a real admin username.

var pass_n := 0
var fail_n := 0

func ck(label: String, cond: bool) -> void:
	if cond:
		pass_n += 1
		print("  ok   %s" % label)
	else:
		fail_n += 1
		printerr("  FAIL %s" % label)

func _ready() -> void:
	print("=== creator flag probe ===")
	var path := "res://server_flags.json"
	var had_file := FileAccess.file_exists(path)
	var backup := FileAccess.get_file_as_string(path) if had_file else ""

	var sc = load("res://components/server_connection.gd").new()

	# --- default is OFF (fails closed) --------------------------------------
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sc._load_server_flags()
	ck("with no flags file, creator is OFF", sc.creator_enabled == false)

	# --- gate semantics while OFF -------------------------------------------
	ck("a normal player is blocked while OFF", sc._creator_blocked("SomePlayer"))
	ck("an ADMIN is exempt while OFF", not sc._creator_blocked("Cheshire"))
	ck("the second admin is exempt too", not sc._creator_blocked("IsaacTheEmperor"))
	# The exact-case rule matters here: a case-variant must NOT inherit the exemption.
	ck("a case-variant of an admin name is still blocked", sc._creator_blocked("cheshire"))

	# --- gate semantics while ON --------------------------------------------
	sc.creator_enabled = true
	ck("a normal player passes while ON", not sc._creator_blocked("SomePlayer"))

	# --- persistence round-trip ---------------------------------------------
	sc._save_server_flags()
	ck("saving writes the flags file", FileAccess.file_exists(path))
	# A fresh instance = what a server restart sees.
	var sc2 = load("res://components/server_connection.gd").new()
	sc2._load_server_flags()
	ck("ON survives a restart", sc2.creator_enabled == true)
	ck("...and the gate agrees after reload", not sc2._creator_blocked("SomePlayer"))

	sc2.creator_enabled = false
	sc2._save_server_flags()
	var sc3 = load("res://components/server_connection.gd").new()
	sc3._load_server_flags()
	ck("OFF survives a restart too", sc3.creator_enabled == false)
	ck("...and the gate blocks again", sc3._creator_blocked("SomePlayer"))

	# --- a corrupt flags file must not open the gate ------------------------
	var bad := FileAccess.open(path, FileAccess.WRITE)
	bad.store_string("{ not json at all ")
	bad.close()
	var sc4 = load("res://components/server_connection.gd").new()
	sc4._load_server_flags()
	ck("a corrupt flags file falls back to OFF", sc4.creator_enabled == false)

	sc.free(); sc2.free(); sc3.free(); sc4.free()

	# Restore whatever was there before so the probe leaves no trace.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if had_file:
		var rf := FileAccess.open(path, FileAccess.WRITE)
		rf.store_string(backup)
		rf.close()

	print("=== %d passed, %d failed ===" % [pass_n, fail_n])
	get_tree().quit(1 if fail_n > 0 else 0)
