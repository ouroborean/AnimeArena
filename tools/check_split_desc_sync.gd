# READ-ONLY sync probe: does webclient/app/ability_split.json still match the LIVE
# split_desc()? Writes NOTHING — it is the audit counterpart to extract_split_desc.gd,
# which is the thing that would rewrite the file.
#
# WHY this needs Godot at all: split_desc() is arbitrary GDScript (it can branch, call
# helpers and embed Color constants), so unlike the flat tables in tools/reference_data.py
# there is no way to derive its output by parsing source. Godot IS the oracle here.
#
#   "<godot>" --headless --path . --script res://tools/check_split_desc_sync.gd
#
# Exit code 1 if any live ability's segments differ from the JSON, 0 if clean.
extends SceneTree

const SPLIT_JSON := "res://webclient/app/ability_split.json"
const SAMPLE_LIMIT := 8


func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://abilities_data.json"))
	var on_disk = JSON.parse_string(FileAccess.get_file_as_string(SPLIT_JSON))
	if data == null or on_disk == null:
		push_error("[SPLITSYNC] missing abilities_data.json or ability_split.json")
		quit(1)
		return

	var live := {}
	var skipped := 0
	for basename in data.keys():
		var info = data[basename]
		# Same completeness gate as extract_split_desc.gd, so the comparison is
		# apples-to-apples with what a regeneration would actually emit.
		if not ("script_path" in info and "name" in info and "cooldown" in info
				and "target_type" in info and "image_path" in info and "classes" in info):
			skipped += 1
			continue
		if not ResourceLoader.exists(info["script_path"]):
			skipped += 1
			continue
		var ability = Ability.from_database(basename)
		if ability == null:
			skipped += 1
			continue
		var segs = ability.split_desc()
		if not (segs is Array) or segs.is_empty():
			continue
		var serialized := []
		for seg in segs:
			if seg is String:
				serialized.append({"text": seg})
			elif seg is Array and seg.size() >= 1:
				var entry := {"text": str(seg[0])}
				if seg.size() >= 2 and seg[1] is Color:
					entry["color"] = "#" + seg[1].to_html(false)
				serialized.append(entry)
		if not serialized.is_empty():
			live[basename] = serialized

	var changed := []
	var added := []
	for basename in live.keys():
		if not on_disk.has(basename):
			added.append(basename)
		elif JSON.stringify(on_disk[basename]) != JSON.stringify(live[basename]):
			changed.append(basename)
	var dropped := []
	for basename in on_disk.keys():
		if not live.has(basename):
			dropped.append(basename)
	changed.sort()
	added.sort()
	dropped.sort()

	print("[SPLITSYNC] live split_desc entries: ", live.size(),
			"   ability_split.json entries: ", on_disk.size(),
			"   skipped (incomplete/dangling): ", skipped)
	print("[SPLITSYNC] TEXT DRIFT   (json differs from live): ", changed.size())
	print("[SPLITSYNC] MISSING      (live but not in json):   ", added.size())
	print("[SPLITSYNC] STALE/EXTRA  (json but not live):      ", dropped.size())

	for basename in changed.slice(0, SAMPLE_LIMIT):
		print("  ~ ", basename)
		print("      json: ", JSON.stringify(on_disk[basename]))
		print("      live: ", JSON.stringify(live[basename]))
	if added.size() > 0:
		print("  + missing: ", added.slice(0, 20))
	if dropped.size() > 0:
		print("  - extra:   ", dropped.slice(0, 20))

	if changed.is_empty() and added.is_empty():
		# STALE/EXTRA alone is not drift: extract_ability_info.gd deliberately carries
		# unreachable design-doc rows forward, so they are expected to outlive the gate.
		print("[SPLITSYNC] IN SYNC — ability_split.json matches the live split_desc().")
		quit(0)
		return
	print("[SPLITSYNC] OUT OF SYNC — regenerate with:")
	print("[SPLITSYNC]   godot --headless --path . --script res://extract_split_desc.gd")
	print("[SPLITSYNC]   godot --headless --path . --script res://extract_ability_info.gd")
	print("[SPLITSYNC]   then copy webclient/app/*.json to deploy/")
	quit(1)
