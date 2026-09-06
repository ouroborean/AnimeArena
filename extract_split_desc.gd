# One-off offline extractor: dumps every ability's split_desc() (the source of
# truth for descriptions; describe() is stale) into webclient/app/ability_split.json
# as {basename: [{text, color?}, ...]}. split_desc() is parameterless, so a
# database-constructed ability renders the same segments the in-battle panel does.
#   Run:  godot --headless --path . --script res://extract_split_desc.gd
extends SceneTree

func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://abilities_data.json"))
	var out := {}
	var skipped := 0
	for basename in data.keys():
		var info = data[basename]
		# from_database needs these keys; skip incomplete/template entries.
		# "classes" included: from_database indexes it unguarded, so a missing
		# key aborts the whole extract (ability_component, squirtle6).
		if not ("script_path" in info and "name" in info and "cooldown" in info and "target_type" in info and "image_path" in info and "classes" in info):
			skipped += 1
			continue
		# Key PRESENT is not enough — from_database does load(script_path).new(),
		# and a dangling path returns null, so .new() hard-aborts the extract.
		# ~42 entries (ash*, atomeve*, invincible*, ...) reference scripts that
		# no longer exist; skip them instead of dying.
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
			out[basename] = serialized
	var f = FileAccess.open("res://webclient/app/ability_split.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("[EXTRACT] wrote ", out.size(), " split_descs (skipped ", skipped, ") of ", data.size(), " abilities")
	quit()
