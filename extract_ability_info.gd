# One-off offline extractor: builds webclient/app/ability_info.json — the client's
# ability tooltip/search database — by merging:
#   abilities_data.json  -> name, classes, cooldown, cost, important, description
#   ability_split.json   -> desc (the colored segments the panel actually renders)
#
# Run AFTER extract_split_desc.gd, which regenerates ability_split.json from the
# live split_desc():
#   godot --headless --path . --script res://extract_split_desc.gd
#   godot --headless --path . --script res://extract_ability_info.gd
#
# description precedence: abilities_data.json wins when it has a non-empty value;
# otherwise the CURRENT ability_info.json value is preserved. Some entries (e.g.
# death1) carry a good description in the client file while the server DB has
# none, and a naive rebuild would blank them. `desc` (split) is what the panel
# shows; `description` is only the fallback + part of the client's search string.
extends SceneTree

func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://abilities_data.json"))
	var split = JSON.parse_string(FileAccess.get_file_as_string("res://webclient/app/ability_split.json"))
	var prev = JSON.parse_string(FileAccess.get_file_as_string("res://webclient/app/ability_info.json"))
	if data == null or split == null:
		push_error("[EXTRACT] missing abilities_data.json or ability_split.json")
		quit(1)
		return
	if prev == null:
		prev = {}

	var out := {}
	var skipped := 0
	for basename in data.keys():
		var info = data[basename]
		# Same completeness gate as extract_split_desc.gd: skip template/incomplete
		# rows so the client never sees a half-built ability.
		if not ("name" in info and "cooldown" in info and "classes" in info):
			skipped += 1
			continue
		var entry := {}
		entry["name"] = info["name"]
		var desc_text = info.get("description", "")
		if desc_text == null:
			desc_text = ""
		if str(desc_text) == "" and prev.has(basename):
			desc_text = prev[basename].get("description", "")
		entry["description"] = str(desc_text)
		entry["classes"] = info["classes"]
		entry["cooldown"] = info["cooldown"]
		if "important" in info:
			entry["important"] = info["important"]
		if split.has(basename):
			entry["desc"] = split[basename]
		elif prev.has(basename) and prev[basename].has("desc"):
			entry["desc"] = prev[basename]["desc"]
		# Cost keys are ints in the DB; the client reads them as strings — keep the
		# stringified shape the existing file uses. Costless skills (passives, free
		# skills) have no `cost` row in the DB and the client file omits the key
		# entirely; emit nothing rather than an empty dict so the export stays a
		# no-op for them.
		if "cost" in info:
			var cost := {}
			for k in info["cost"].keys():
				cost[str(k)] = info["cost"][k]
			entry["cost"] = cost
		out[basename] = entry

	# Carry forward any entry the gate rejected but that the previous file had
	# (~45 unimplemented design-doc abilities: gaia_*, hymn_*, saya_*, ... — no
	# .gd exists so they're unreachable in game). Keeping them makes the export
	# purely additive/corrective instead of also pruning unrelated rows.
	var carried := 0
	for basename in prev.keys():
		if not out.has(basename):
			out[basename] = prev[basename]
			carried += 1

	var f = FileAccess.open("res://webclient/app/ability_info.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("[EXTRACT] wrote ", out.size(), " ability_info entries (rebuilt ", out.size() - carried, ", carried ", carried, ", skipped ", skipped, ") of ", data.size())
	quit()
