extends RefCounted
class_name Campaign

# Server-side campaign authority. Loads the SAME rule tables the web client reads
# (webclient/app/campaign_*.json) so both evaluate progression identically; the STATE
# (stage/flags/node/completed) is server-held and only the server mutates it (see
# server_connection.gd's campaign_* handlers). Mirrors the client resolver in app.js.
# See .claude/plans/campaign-mode.md.

const CHAPTERS_PATH := "res://webclient/app/campaign_chapters.json"
const DIALOGUE_PATH := "res://webclient/app/campaign_dialogue.json"
const ENCOUNTERS_PATH := "res://webclient/app/campaign_encounters.json"

static var _chapters: Dictionary = {}
static var _dialogue: Dictionary = {}
static var _encounters: Dictionary = {}
static var _loaded := false

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[CAMPAIGN] missing data file: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func _load() -> void:
	if _loaded:
		return
	_chapters = _read(CHAPTERS_PATH)
	_dialogue = _read(DIALOGUE_PATH)
	_encounters = _read(ENCOUNTERS_PATH)
	_loaded = true

static func chapter(id) -> Variant:
	_load()
	for c in _chapters.get("chapters", []):
		if c.get("id") == id:
			return c
	return null

static func node(ch, node_id) -> Variant:
	if ch == null:
		return null
	for n in ch.get("nodes", []):
		if n.get("id") == node_id:
			return n
	return null

static func activation_by_id(n, act_id) -> Variant:
	if n == null:
		return null
	for a in n.get("activations", []):
		if a.get("id") == act_id:
			return a
	return null

static func dialogue_scene(scene_id) -> Variant:
	_load()
	return _dialogue.get(scene_id, null)

static func encounter(enc_id) -> Dictionary:
	_load()
	var e = _encounters.get(enc_id, {})
	return e if e is Dictionary else {}

# --- story-state predicate (mirrors app.js campaignWhenPasses) ---
static func when_passes(w, prog) -> bool:
	if w == null or (w is Dictionary and w.is_empty()):
		return true
	var flags = prog.get("flags", {})
	if "stage" in w:
		var s = prog.get("stage", null)
		if w["stage"] is Array:
			if not (s in w["stage"]):
				return false
		elif w["stage"] != s:
			return false
	if "flags" in w:
		for f in w["flags"]:
			if not flags.get(f, false):
				return false
	if "not_flags" in w:
		for f in w["not_flags"]:
			if flags.get(f, false):
				return false
	return true

static func node_open(n, prog) -> bool:
	return when_passes(n.get("open_when", {}), prog)

# First activation whose `when` passes and (if one-shot) isn't consumed.
static func resolve_activation(n, prog) -> Variant:
	if n == null:
		return null
	var done = prog.get("completed", [])
	for a in n.get("activations", []):
		if a.get("once", true) and (a.get("id") in done):
			continue
		if when_passes(a.get("when", {}), prog):
			return a
	return null

# Fresh chapter-start progress blob.
static func fresh_state(chapter_id) -> Dictionary:
	var ch = chapter(chapter_id)
	if ch == null:
		return {}
	var start_node = ch.get("start_node")
	var party = ch.get("party", [])
	return {
		"chapter": chapter_id,
		"node": start_node,
		"stage": ch.get("start_stage", null),
		"flags": {},
		"visited": [start_node],
		"completed": [],
		"party": (party as Array).slice(0, 3),
		"campaign_unlocked_abilities": [],
		"vessel_loadout": [],   # player-chosen Vessel skill keys (empty = the 4 defaults)
		"pending_wins": [],   # encounters won but not yet consumed by activation_complete (persists across reconnect)
	}

# Every dialogue scene reachable within an activation: its `talk` steps plus any scenes
# reachable transitively through choice `goto`s. Used to validate a client's choice context.
static func activation_scenes(activation) -> Dictionary:
	var reachable := {}
	if activation == null:
		return reachable
	var frontier := []
	for step in activation.get("sequence", []):
		if step is Dictionary and "talk" in step:
			frontier.append(str(step["talk"]))
	while not frontier.is_empty():
		var sid = frontier.pop_back()
		if sid in reachable:
			continue
		reachable[sid] = true
		var scene = dialogue_scene(sid)
		if scene == null:
			continue
		for line in scene.get("lines", []):
			for choice in line.get("choices", []):
				if "goto" in choice and not (str(choice["goto"]) in reachable):
					frontier.append(str(choice["goto"]))
	return reachable
