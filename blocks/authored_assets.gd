extends RefCounted
class_name AuthoredAssets

# ============================================================================
# Player-uploaded artwork for authored characters.
#
# Uploads are the one place untrusted BINARY reaches the server, so everything
# here is defensive:
#   * transfer is CHUNKED base64 over the existing JSON gateway (a whole image
#     in one frame would blow the 64KB WebSocketPeer inbound buffer);
#   * a session may have exactly one upload in flight, with a hard byte cap, a
#     chunk cap and a wall-clock expiry, so an abandoned or malicious upload
#     cannot pin memory;
#   * the stored filename is DERIVED from (character id, slot) — a client-
#     supplied name is never used, so there is no path-traversal surface;
#   * the payload must actually be a PNG (magic bytes + IHDR dimensions), not
#     merely named like one.
#
# Moderation of image CONTENT is a human/policy problem the owner has taken on;
# this class only guarantees the file is a small, well-formed PNG in the right
# place, owned by the right author.
# ============================================================================

const DIR := "res://authored_assets/"
# SECURITY / RESOURCE bounds, not art direction. They cap an upload path that pins server
# memory while it is in flight, and they carry ~15x headroom over the shipped art.
const MAX_BYTES := 262144          # 256 KB — shipped portraits are ~12-17 KB
const MAX_CHUNKS := 64             # a chunk is one socket frame; caps frames per upload
const MAX_DIM := 1024              # px, either axis — bounds the decoded bitmap, not the file
const UPLOAD_TTL_MS := 120000      # abandoned uploads expire after 2 minutes
# One icon slot per skill a character may have (BlockSchema.LIMITS.max_abilities),
# plus the portrait. Sized to the ceiling rather than to the four visible slots:
# hidden skills are swapped INTO a visible slot mid-match, so they are seen and need
# their own art. Append-only — an existing spec's `icon` binding names a slot by
# string, so slots must never be renumbered.
# ALT-PORTRAIT upload slots — the transformed forms a PORTRAIT_CHANGE effect swaps to. Count 4:
# a transform plus a few alternate forms is the whole shipped idiom (cell5/rob/lizandpatty transforms
# are single-form; nobody ships more than a handful). This is an upload-STORAGE reality, not a balance
# cap — the list is APPEND-ONLY, so a 5th alt is a trivial one-line add, and a PORTRAIT_CHANGE index is
# bounded to this list's SIZE (block_validator), never to a hard-coded number. Kept OUT of
# ability_slots() below so an alt portrait can NEVER be handed out as a skill icon.
const ALT_PORTRAIT_SLOTS := ["alt1", "alt2", "alt3", "alt4"]

const SLOTS := ["portrait",
	"ability1", "ability2", "ability3", "ability4", "ability5", "ability6", "ability7",
	"ability8", "ability9", "ability10", "ability11", "ability12", "ability13", "ability14",
	"ability15", "ability16", "ability17", "ability18", "ability19", "ability20", "ability21",
	"ability22", "ability23", "ability24", "ability25", "ability26", "ability27", "ability28",
	"ability29", "ability30", "ability31", "ability32",
	# Appended (append-only) so begin() accepts an alt-portrait upload. These are NOT ability icons —
	# ability_slots() filters them out.
	"alt1", "alt2", "alt3", "alt4"]

# session username -> {char_id, slot, expect, parts:[], bytes, started_ms}
static var _pending: Dictionary = {}

static func _ensure_dir(char_id: String) -> void:
	var p := ProjectSettings.globalize_path(DIR + char_id)
	if not DirAccess.dir_exists_absolute(p):
		DirAccess.make_dir_recursive_absolute(p)

static func asset_path(char_id: String, slot: String) -> String:
	return DIR + char_id + "/" + slot + ".png"

static func has_asset(char_id: String, slot: String) -> bool:
	return FileAccess.file_exists(asset_path(char_id, slot))

# The slots a SKILL icon may occupy — "portrait" is the character's own art and the ALT_PORTRAIT_SLOTS
# are transformed forms, so NEITHER is ever handed out to an ability. Built as an explicit filter rather
# than SLOTS.slice(1) because SLOTS now also carries the alt slots at its tail: a bare slice(1) would
# expose "alt1".."alt4" as bindable icons (authored_registry gates icon-binding on this list), which is
# exactly the alts-as-skill-icons collision this list exists to prevent.
static func ability_slots() -> Array:
	var out: Array = []
	for s in SLOTS:
		if s == "portrait" or s in ALT_PORTRAIT_SLOTS:
			continue
		out.append(s)
	return out

# The alt-portrait upload slots (the transformed forms). The PORTRAIT_CHANGE index bound reads this
# list's SIZE, so growing ALT_PORTRAIT_SLOTS grows the authorable range with no other change.
static func alt_portrait_slots() -> Array:
	return ALT_PORTRAIT_SLOTS

# THE ONE index<->slot mapping (0-based index N -> slot "alt"+(N+1)), shared by the runner's mag, the
# editor's dropdown labels, the upload UI and the client render resolver. A mismatch here silently
# renders the wrong or default portrait, so it lives in one function. Mirrored in app.js as
# ("alt" + (N + 1)).
static func alt_slot_for_index(n: int) -> String:
	return "alt" + str(n + 1)

# finish() erases the pending record before it returns, so a caller that needs to
# know WHICH character/slot was just written has to read it first.
static func peek(username: String) -> Dictionary:
	return (_pending.get(username, {}) as Dictionary).duplicate()

# --- upload lifecycle -------------------------------------------------------
# ability_index is carried purely so the caller can bind the stored slot back to the
# right skill once the bytes land; -1 means this is the character portrait.
static func begin(username: String, char_id: String, slot: String, total_bytes: int, chunks: int, ability_index: int = -1) -> Array:
	if not slot in SLOTS:
		return ["unknown image slot '%s'" % slot]
	if total_bytes <= 0 or total_bytes > MAX_BYTES:
		return ["image must be 1 byte to %d KB (got %d bytes)" % [MAX_BYTES / 1024, total_bytes]]
	if chunks <= 0 or chunks > MAX_CHUNKS:
		return ["too many chunks"]
	_expire()
	_pending[username] = {
		"char_id": char_id, "slot": slot, "expect": chunks, "ability_index": ability_index,
		"parts": [], "bytes": total_bytes, "started_ms": Time.get_ticks_msec(),
	}
	return []

static func chunk(username: String, part: int, data: String) -> Array:
	if not _pending.has(username):
		return ["no upload in progress"]
	var up: Dictionary = _pending[username]
	if part != up["parts"].size():
		return ["chunk out of order (expected %d, got %d)" % [up["parts"].size(), part]]
	if up["parts"].size() >= int(up["expect"]):
		return ["too many chunks"]
	# Guard total transferred size even if the client lied in begin().
	var running := 0
	for p in up["parts"]:
		running += str(p).length()
	if running + data.length() > MAX_BYTES * 2:      # base64 is ~4/3 of raw
		_pending.erase(username)
		return ["upload exceeded the size limit"]
	up["parts"].append(data)
	return []

static func finish(username: String) -> Array:
	if not _pending.has(username):
		return ["no upload in progress"]
	var up: Dictionary = _pending[username]
	_pending.erase(username)
	if up["parts"].size() != int(up["expect"]):
		return ["upload incomplete (%d of %d chunks)" % [up["parts"].size(), int(up["expect"])]]

	var raw := Marshalls.base64_to_raw("".join(up["parts"]))
	if raw.size() == 0:
		return ["image data was empty or not valid base64"]
	if raw.size() > MAX_BYTES:
		return ["image is larger than %d KB" % (MAX_BYTES / 1024)]
	var shape := _png_dimensions(raw)
	if shape.is_empty():
		return ["file is not a valid PNG"]
	if shape[0] > MAX_DIM or shape[1] > MAX_DIM:
		return ["image must be %dx%d or smaller (got %dx%d)" % [MAX_DIM, MAX_DIM, shape[0], shape[1]]]

	var char_id := str(up["char_id"])
	_ensure_dir(char_id)
	var f := FileAccess.open(asset_path(char_id, str(up["slot"])), FileAccess.WRITE)
	if f == null:
		return ["could not store the image"]
	f.store_buffer(raw)
	f.close()
	return []

static func cancel(username: String) -> void:
	_pending.erase(username)

static func _expire() -> void:
	var now := Time.get_ticks_msec()
	for u in _pending.keys():
		if now - int(_pending[u]["started_ms"]) > UPLOAD_TTL_MS:
			_pending.erase(u)

static func delete_all(char_id: String) -> void:
	var p := ProjectSettings.globalize_path(DIR + char_id)
	var d := DirAccess.open(p)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(p + "/" + f)
	DirAccess.remove_absolute(p)

# --- PNG sniffing -----------------------------------------------------------
# Verify the magic signature AND read IHDR for the dimensions. Anything that
# isn't a real PNG (a renamed file, a polyglot, a truncated blob) fails here
# rather than at load time inside a live match.
static func _png_dimensions(raw: PackedByteArray) -> Array:
	if raw.size() < 24:
		return []
	const SIG := [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
	for i in range(8):
		if raw[i] != SIG[i]:
			return []
	# bytes 12..15 must be the IHDR chunk type
	if not (raw[12] == 0x49 and raw[13] == 0x48 and raw[14] == 0x44 and raw[15] == 0x52):
		return []
	var w := (raw[16] << 24) | (raw[17] << 16) | (raw[18] << 8) | raw[19]
	var h := (raw[20] << 24) | (raw[21] << 16) | (raw[22] << 8) | raw[23]
	if w <= 0 or h <= 0:
		return []
	return [w, h]
