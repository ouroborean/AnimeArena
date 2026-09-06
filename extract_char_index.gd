# One-off: dump { path_name: {name, default_portrait_rel} } for EVERY character the
# production server knows (bucket_handler.all_chars), so the web client can show names +
# default portraits for characters beyond its dev roster (Nexus leaderboard, bounty targets).
#   Run:  godot --headless --path . --script res://extract_char_index.gd
extends SceneTree

func _init():
	var bh = load("res://components/bucket_handler.gd").new()
	var out = {}
	for path in bh.all_chars:
		var concept = bh.all_chars[path]
		var rel = ""
		if concept.portrait_texture != null and concept.portrait_texture.resource_path != "":
			rel = concept.portrait_texture.resource_path.trim_prefix("res://assets/images/")
		out[path] = { "name": concept.character_name, "default": rel }
	var f = FileAccess.open("res://webclient/app/char_index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("[CHARINDEX] ", out.size(), " characters")
	quit()
