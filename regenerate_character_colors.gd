# Rebuilds character_colors.json from the character/*.gd source files.
#
# Run from the project root:
#   godot --headless --path . --script res://regenerate_character_colors.gd
#
# Strategy: parse each character script for its `character_colors = [...]`
# declaration (regex). Apply EXCLUDED to drop characters that shouldn't be
# considered for drafting at all, and OVERRIDES for characters whose script
# declaration is absent or doesn't reflect their drafting-time energy
# identity (e.g. Crona uses all 4 colors in-kit but is RANDOM-only for
# drafting purposes).
#
# Encoding (Energy.Type):
#   0 = GREEN, 1 = BLUE, 2 = WHITE, 3 = RED, 4 = RANDOM
#
# Output: res://character_colors.json — keys sorted alphabetically for
# stable diffs across reruns.

extends SceneTree

const OUT_PATH := "res://character_colors.json"
const CHARACTER_DIR := "res://character/"

# Characters intentionally excluded from the JSON. The base template plus
# 7 characters the project owner has flagged as not draftable / not in
# active rotation.
const EXCLUDED := [
	"character_template",
	"kakashi",
	"lapucelle",
	"ruler",
	"snowwhite",
	"urahara",
	"uryu",
	"uryuu",
]

# Manual overrides — script declaration is absent or mechanically wrong
# for drafting purposes. These take precedence over the parsed value.
#   gojo:     no declaration in script → BLUE
#   tokoyami: no declaration in script → RED (his kit is all-RED themed)
#   crona:    in-kit uses all 4 colors but a game mechanic makes all of
#             her costs random; for drafting she contributes nothing to
#             color coverage, encoded as the empty array
const OVERRIDES := {
	"gojo": [1],
	"tokoyami": [3],
	"crona": [],
}


func _initialize():
	var dir := DirAccess.open(CHARACTER_DIR)
	if dir == null:
		push_error("Could not open " + CHARACTER_DIR)
		quit(1)
		return

	var entries: Dictionary = {}
	var skipped: Array = []
	var no_decl: Array = []

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".gd"):
			var path_name := fname.get_basename()
			if path_name in EXCLUDED:
				skipped.append(path_name)
			elif path_name in OVERRIDES:
				entries[path_name] = OVERRIDES[path_name]
			else:
				var parsed = _extract_colors(CHARACTER_DIR + fname)
				if parsed == null:
					# No declaration found AND not in OVERRIDES — record so
					# the user can decide whether to add it.
					no_decl.append(path_name)
					entries[path_name] = []
				else:
					entries[path_name] = parsed
		fname = dir.get_next()
	dir.list_dir_end()

	# Sort keys alphabetically for stable diffs.
	var sorted_keys = entries.keys()
	sorted_keys.sort()
	var ordered: Dictionary = {}
	for k in sorted_keys:
		ordered[k] = entries[k]

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write " + OUT_PATH)
		quit(1)
		return
	f.store_string(JSON.stringify(ordered, "\t"))
	f.close()

	print("[regen] Wrote %d entries to %s" % [ordered.size(), OUT_PATH])
	print("[regen] Excluded (per EXCLUDED list): %d  -> %s" % [skipped.size(), ", ".join(skipped)])
	print("[regen] Applied overrides: %d  -> %s" % [OVERRIDES.size(), ", ".join(OVERRIDES.keys())])
	if not no_decl.is_empty():
		print("[regen] WARNING: %d scripts have no `character_colors = [...]` declaration" % no_decl.size())
		print("[regen]          and aren't in OVERRIDES — defaulted to []:")
		for n in no_decl:
			print("[regen]            %s" % n)
		print("[regen]          Add an explicit declaration in their script or list them")
		print("[regen]          in OVERRIDES / EXCLUDED above.")
	quit(0)


# Parses the script text for `character_colors = [...]` and returns a sorted
# Array[int] of the values inside, or null if no declaration was found.
# Handles multi-line array literals via a permissive regex.
func _extract_colors(path: String):
	var src := FileAccess.open(path, FileAccess.READ)
	if src == null:
		return null
	var text := src.get_as_text()
	src.close()

	var re := RegEx.new()
	# Match: character_colors = [ <anything except ]> ]
	# `[^\]]*` spans newlines inside the brackets, so multi-line arrays work.
	re.compile("character_colors\\s*=\\s*\\[([^\\]]*)\\]")
	var m := re.search(text)
	if m == null:
		return null

	var inner := m.get_string(1).strip_edges()
	if inner == "":
		return []
	var out: Array = []
	for piece in inner.split(","):
		var v := piece.strip_edges()
		if v != "":
			out.append(int(v))
	out.sort()
	return out
